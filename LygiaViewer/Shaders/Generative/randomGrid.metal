#include <metal_stdlib>
using namespace metal;
#include "Common.h"

#include "lygia/generative/random.msl"

// LYGIA's hash-based random: random (float), random2, random3.
// params: x = mode (0 white noise, 1 random per cell, 2 random3 per cell), y = cells, z = reseed speed
[[ stitchable ]] half4 randomGrid(float2 position, half4 color, float2 size, float time, float4 params) {
    float2 st = lygiaST(position, size);
    float seed = floor(params.z);
    int mode = int(params.x + 0.5);

    if (mode == 0) {
        return opaque(random(float3(position, seed)));
    }
    float2 cell = floor(st * params.y);
    if (mode == 1) {
        return opaque(random(cell + seed * 17.0));
    }
    float3 c = random3(cell + seed * 17.0);
    float2 f = fract(st * params.y) - 0.5;
    float r = random2(cell).x * 0.35 + 0.1;
    return opaque(c * (0.35 + 0.65 * step(length(f), r)));
}
