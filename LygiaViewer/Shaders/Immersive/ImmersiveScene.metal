// Fully immersive raymarched scene for visionOS (CompositorServices).
//
// One full-screen triangle per eye (vertex amplification picks the eye), then
// per pixel: rebuild the world-space ray from that eye's inverse projection and
// camera transform, raymarch an SDF scene made of LYGIA sdf/ + space/ pieces,
// shade it with immersiveShade() (ImmersiveLighting.h) and write reverse-Z
// depth so the compositor can reproject the frame.
//
// World space is the immersive space's origin: on the floor, y up, -z forward.

#include <metal_stdlib>
using namespace metal;

#include "ImmersiveTypes.h"
#include "ImmersiveLighting.h"

#include "lygia/math/const.msl"
#include "lygia/space/rotate.msl"
#include "lygia/sdf/octahedronSDF.msl"
#include "lygia/sdf/icosahedronSDF.msl"
#include "lygia/sdf/dodecahedronSDF.msl"
#include "lygia/sdf/torusSDF.msl"
#include "lygia/sdf/boxFrameSDF.msl"
#include "lygia/sdf/linkSDF.msl"
#include "lygia/sdf/sphereSDF.msl"
#include "lygia/sdf/planeSDF.msl"
#include "lygia/sdf/opUnion.msl"
#include "lygia/sdf/opRepeat.msl"
#include "lygia/generative/snoise.msl"
#include "lygia/generative/fbm.msl"
#include "lygia/generative/voronoi.msl"
#include "lygia/color/palette/spectral.msl"
#include "lygia/color/tonemap/aces.msl"

// MARK: - Scene

constant int   kOrnamentCount  = 7;
constant float kOrnamentRadius = 2.4;    // meters from the origin
constant float kOrnamentHeight = 1.45;   // roughly eye height
constant float kLatticeHeight  = 4.6;
constant float kMaxDistance    = 40.0;

// Material ids (the .y of every map result).
constant float kFloorId   = 0.0;
constant float kLatticeId = 10.0;
// 1 ... kOrnamentCount are the ornaments.

/// Seven slowly spinning solids on a ring around the viewer.
/// Polar repetition evaluates only the ornament in the current sector.
inline float2 immersiveOrnaments(float3 p, float time) {
    const float sector = TAU / float(kOrnamentCount);
    float k = round(atan2(p.z, p.x) / sector);
    int index = (int(k) + kOrnamentCount) % kOrnamentCount;

    float c = cos(k * sector), s = sin(k * sector);
    float2 local = float2(c * p.x + s * p.z, -s * p.x + c * p.z);
    float bob = 0.08 * sin(time * 0.7 + float(index) * 1.7);
    float3 q = float3(local.x - kOrnamentRadius, p.y - kOrnamentHeight - bob, local.y);

    float3 axis = normalize(float3(sin(float(index)), 1.0, cos(float(index) * 2.3)));
    q = rotate(q, time * (0.25 + 0.05 * float(index)), axis);

    float d;
    switch (index) {
        case 0:  d = octahedronSDF(q, 0.34); break;
        case 1:  d = icosahedronSDF(q, 0.3); break;
        case 2:  d = dodecahedronSDF(q, 0.3); break;
        case 3:  d = torusSDF(q, float2(0.28, 0.08)); break;
        case 4:  d = boxFrameSDF(q, float3(0.27), 0.03); break;
        case 5:  d = linkSDF(q, 0.14, 0.17, 0.055); break;
        default: d = sphereSDF(q, 0.27) + 0.035 * snoise(q * 5.0 + time * 0.3); break;
    }
    return float2(d, float(index + 1));
}

/// A ceiling of octahedral frames repeating in xz.
inline float lattice(float3 p) {
    float slab = abs(p.y - kLatticeHeight) - 0.45;
    if (slab > 0.3) return slab;           // far from the ceiling: cheap bound
    float3 q = p;
    q.xz = opRepeat(p.xz, 1.8);
    q.y -= kLatticeHeight;
    q = rotate(q, PI * 0.25, float3(0.0, 1.0, 0.0));
    float frame = boxFrameSDF(q, float3(0.5, 0.18, 0.5), 0.022);
    float node = octahedronSDF(q - float3(0.0, -0.3, 0.0), 0.09);
    return opUnion(frame, node);
}

/// x = distance, y = material id.
inline float2 immersiveMap(float3 p, float time) {
    float2 res = float2(planeSDF(p), kFloorId);
    float2 ornaments = immersiveOrnaments(p, time);
    if (ornaments.x < res.x) res = ornaments;
    float ceiling = lattice(p);
    if (ceiling < res.x) res = float2(ceiling, kLatticeId);
    return res;
}

inline float3 immersiveNormal(float3 p, float time) {
    // Tetrahedral central differences: 4 map calls.
    const float2 k = float2(1.0, -1.0);
    const float h = 0.0008;
    return normalize(k.xyy * immersiveMap(p + k.xyy * h, time).x +
                     k.yyx * immersiveMap(p + k.yyx * h, time).x +
                     k.yxy * immersiveMap(p + k.yxy * h, time).x +
                     k.xxx * immersiveMap(p + k.xxx * h, time).x);
}

inline float immersiveOcclusion(float3 p, float3 n, float time) {
    float occlusion = 0.0;
    float weight = 1.0;
    for (int i = 1; i <= 5; i++) {
        float h = 0.03 + 0.08 * float(i);
        occlusion += (h - immersiveMap(p + n * h, time).x) * weight;
        weight *= 0.7;
    }
    return saturate(1.0 - 2.0 * occlusion);
}

/// Surface description for the lighting function, per material id.
inline ImmersiveSurface immersiveSurface(float3 p, float3 n, float id, float time) {
    ImmersiveSurface s;
    s.position = p;
    s.normal = n;
    s.emissive = float3(0.0);
    s.metallic = 0.0;
    s.occlusion = immersiveOcclusion(p, n, time);

    if (id == kFloorId) {
        // Voronoi cells: one noise-tinted stone per cell, with concentric
        // rings around each cell's seed point.
        float3 cell = voronoi(p.xz * 1.2, time * 0.15);
        float tint = 0.5 + 0.5 * snoise(float3(cell.xy * 7.0, 1.7));
        float rings = smoothstep(0.35, 0.5, abs(fract(cell.z * 5.0) - 0.5) * 2.0);
        float3 stone = mix(float3(0.06, 0.06, 0.08), float3(0.2, 0.16, 0.13), tint);
        s.albedo = stone * mix(1.0, 0.65, rings);
        s.roughness = mix(0.35, 0.8, rings);
        // Soft glow under each ornament.
        float ring = abs(length(p.xz) - kOrnamentRadius);
        s.emissive = spectral(fract(atan2(p.z, p.x) / TAU + time * 0.02)) * 0.25 * exp(-ring * ring * 30.0);
    } else if (id == kLatticeId) {
        s.albedo = float3(0.85, 0.7, 0.45);
        s.metallic = 1.0;
        s.roughness = 0.3;
    } else {
        float t = (id - 1.0) / float(kOrnamentCount);
        float marble = fbm(p * 3.0 + float3(0.0, time * 0.1, 0.0));
        s.albedo = mix(spectral(fract(t + 0.1 * marble + time * 0.01)), float3(0.9), 0.15);
        s.metallic = (int(id) % 2 == 0) ? 0.8 : 0.0;
        s.roughness = 0.25 + 0.25 * saturate(marble + 0.5);
    }
    return s;
}

inline float3 immersiveSky(float3 rd, float time) {
    float up = rd.y;
    float3 color = mix(float3(0.02, 0.02, 0.04), float3(0.08, 0.12, 0.3), smoothstep(-0.1, 0.6, up));
    // Aurora band: fbm streaks colored with LYGIA's spectral palette.
    float band = fbm(float3(rd.xz / max(up + 0.2, 0.05) * 1.5, time * 0.05));
    float mask = smoothstep(0.05, 0.4, up) * smoothstep(0.0, 0.6, band + 0.2);
    color += spectral(fract(0.55 + 0.3 * band)) * mask * 0.35;
    // Sun disc.
    color += kImmersiveSunColor * 0.6 * pow(saturate(dot(rd, normalize(kImmersiveSunDirection))), 400.0);
    return color;
}

// MARK: - Entry points

struct ImmersiveVertexOut {
    float4 position [[position]];
    float2 ndc;                     // interpolated NDC, valid with or without foveation
    uint viewIndex [[flat]];
};

struct ImmersiveFragmentOut {
    float4 color [[color(0)]];
    float depth [[depth(any)]];
};

/// Full-screen triangle; Metal's view mappings route each amplified copy to the
/// eye's render target slice and viewport.
vertex ImmersiveVertexOut immersiveVertex(uint vid [[vertex_id]],
                                          ushort amp [[amplification_id]],
                                          constant ImmersivePassViews &pass [[buffer(1)]]) {
    float2 uv = float2((vid << 1) & 2, vid & 2);
    ImmersiveVertexOut out;
    out.ndc = uv * 2.0 - 1.0;
    out.position = float4(out.ndc, 1.0, 1.0);
    out.viewIndex = pass.viewIndex[amp];
    return out;
}

fragment ImmersiveFragmentOut immersiveFragment(ImmersiveVertexOut in [[stage_in]],
                                                constant ImmersiveFrame &frame [[buffer(0)]]) {
    ImmersiveView view = frame.views[in.viewIndex];
    float time = frame.time;

    // Ray through this pixel: a point on the near plane (z = 1 in reverse-Z)
    // in eye space, then into world space.
    float4 eye = view.inverseProjection * float4(in.ndc, 1.0, 1.0);
    float3 rdEye = normalize(eye.xyz / eye.w);
    float3 ro = view.cameraToWorld[3].xyz;
    float3 rd = normalize((view.cameraToWorld * float4(rdEye, 0.0)).xyz);

    float t = 0.05;
    float2 hit = float2(kMaxDistance, -1.0);
    for (int i = 0; i < 128 && t < kMaxDistance; i++) {
        float2 h = immersiveMap(ro + rd * t, time);
        if (h.x < 0.0004 * t) { hit = float2(t, h.y); break; }
        t += h.x;
    }

    float3 sky = immersiveSky(rd, time);
    ImmersiveFragmentOut out;
    if (hit.y < 0.0) {
        out.color = float4(tonemapACES(sky), 1.0);
        out.depth = 0.0;                      // reverse-Z: 0 is the far plane
        return out;
    }

    float3 p = ro + rd * hit.x;
    float3 n = immersiveNormal(p, time);
    ImmersiveSurface surface = immersiveSurface(p, n, hit.y, time);
    float3 color = immersiveShade(surface, -rd);

    // Distance fog into the horizon color.
    float fog = 1.0 - exp(-0.0025 * hit.x * hit.x);
    color = mix(color, immersiveSky(float3(rd.x, 0.02, rd.z), time), fog);

    out.color = float4(tonemapACES(color), 1.0);
    float4 clip = view.viewProjection * float4(p, 1.0);
    out.depth = saturate(clip.z / clip.w);
    return out;
}
