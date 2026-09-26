#include <metal_stdlib>
using namespace metal;
#include "Common.h"

#include "lygia/space/sqTile.msl"
#include "lygia/space/checkerTile.msl"
#include "lygia/generative/random.msl"
#include "lygia/draw/stroke.msl"

// Ornament: Smith truchet tiles. Each tile randomly picks one of two
// orientations of two quarter-circle arcs; together they weave endless paths.
// sqTile + random -> circle arcs -> stroke
// params: x = scale, y = reshuffle speed, z = line width, w = checker tint (0/1)
[[ stitchable ]] half4 truchetWeave(float2 position, half4 color, float2 size, float time, float4 params) {
    float2 st = lygiaST(position, size);
    float4 t = sqTile(st * params.x);
    float flip = step(0.5, random(t.zw + floor(params.y)));
    float2 p = flip > 0.5 ? float2(1.0 - t.x, t.y) : t.xy;

    // Distance to the two corner arcs (radius 0.5 around opposite corners).
    float a = abs(length(p) - 0.5);
    float b = abs(length(p - 1.0) - 0.5);
    float d = min(a, b);

    float3 bg = mix(float3(0.10, 0.10, 0.14), float3(0.16, 0.12, 0.20), params.w * checkerTile(st * params.x));
    float3 c = bg;
    c = mix(c, float3(0.98, 0.78, 0.40), stroke(d, 0.0, params.z));
    c = mix(c, float3(0.30, 0.10, 0.12), stroke(d, 0.0, params.z * 0.3));
    return opaque(c);
}
