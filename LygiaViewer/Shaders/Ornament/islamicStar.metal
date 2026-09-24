#include <metal_stdlib>
using namespace metal;
#include "Common.h"

namespace { // LYGIA: internal linkage, see Common.h
#include "lygia/space/sqTile.msl"
#include "lygia/space/rotate.msl"
#include "lygia/sdf/rectSDF.msl"
#include "lygia/sdf/starSDF.msl"
#include "lygia/sdf/circleSDF.msl"
#include "lygia/draw/stroke.msl"
#include "lygia/draw/fill.msl"
#include "lygia/math/const.msl"
}

// Two-band interlaced line: outer stroke minus a thinner inner stroke.
static float band(float d, float at, float w) {
    return stroke(d, at, w) - stroke(d, at, w * 0.35);
}

// Ornament: 8-point star (khatam) from two overlapping squares, repeated on a
// square grid; the rotated square reaches the tile edges and links neighbors.
// sqTile -> rectSDF + rotate -> starSDF -> stroke
// params: x = scale, y = square size, z = breathing, w = line width
[[ stitchable ]] half4 islamicStar(float2 position, half4 color, float2 size, float time, float4 params) {
    float2 st = lygiaST(position, size);
    float4 t = sqTile(st * params.x);
    float2 p = t.xy;
    float s = params.y * (1.0 + params.z * 0.08 * sin(time));
    float w = params.w;

    float squareA = rectSDF(p, s);
    float squareB = rectSDF(rotate(p, PI * 0.25), s);
    float khatam = min(squareA, squareB);                   // union of both squares
    float link = rectSDF(rotate(p, PI * 0.25), 1.414);                   // diamond touching edge midpoints

    float3 ground = float3(0.05, 0.22, 0.26);
    float3 tile = float3(0.93, 0.88, 0.75);
    float3 accent = float3(0.75, 0.25, 0.20);

    float3 c = ground;
    c = mix(c, accent, fill(starSDF(p, 8, 0.12), 0.32 * s));
    c = mix(c, tile, clamp(band(khatam, 1.0, w), 0.0, 1.0));
    c = mix(c, tile, clamp(band(link, 1.0, w * 0.8), 0.0, 1.0));
    c = mix(c, tile, fill(circleSDF(p), 0.05));
    return opaque(c);
}
