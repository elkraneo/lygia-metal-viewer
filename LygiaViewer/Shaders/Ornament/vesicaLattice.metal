#include <metal_stdlib>
using namespace metal;
#include "Common.h"

#include "lygia/space/mirrorTile.msl"
#include "lygia/space/rotate.msl"
#include "lygia/sdf/vesicaSDF.msl"
#include "lygia/sdf/circleSDF.msl"
#include "lygia/sdf/rhombSDF.msl"
#include "lygia/draw/stroke.msl"
#include "lygia/draw/fill.msl"
#include "lygia/math/const.msl"

// Ornament: vesica piscis (two overlapping circles) crossed at 90 degrees,
// mirrored across tiles so arcs join into a continuous quatrefoil lattice.
// mirrorTile -> vesicaSDF + rotate -> stroke
// params: x = scale, y = vesica width, z = line width, w = shimmer speed
[[ stitchable ]] half4 vesicaLattice(float2 position, half4 color, float2 size, float time, float4 params) {
    float2 st = lygiaST(position, size);
    float4 t = mirrorTile(st * params.x);
    float2 p = t.xy;
    float w = params.z;

    float v1 = vesicaSDF(p, params.y);
    float v2 = vesicaSDF(rotate(p, PI * 0.5), params.y);
    float shimmer = 0.5 + 0.5 * sin(params.w + (t.z + t.w) * 0.8);

    float3 c = float3(0.08, 0.10, 0.16);
    c = mix(c, float3(0.20, 0.35, 0.55) * (0.6 + 0.4 * shimmer), fill(max(v1, v2), 1.0, 0.01));
    c = mix(c, float3(0.95, 0.80, 0.45), stroke(v1, 1.0, w));
    c = mix(c, float3(0.95, 0.80, 0.45), stroke(v2, 1.0, w));
    c = mix(c, float3(0.95, 0.80, 0.45), stroke(circleSDF(p), 1.0 + 0.414, w * 0.7));
    c = mix(c, float3(0.85, 0.35, 0.30), fill(rhombSDF(p), 0.12 + 0.05 * shimmer));
    return opaque(c);
}
