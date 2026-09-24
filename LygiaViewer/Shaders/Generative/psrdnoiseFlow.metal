#include <metal_stdlib>
using namespace metal;
#include "Common.h"

namespace { // LYGIA: internal linkage, see Common.h
#include "lygia/generative/psrdnoise.msl"
}

// psrdnoise (Gustavson & McEwan): tiling simplex noise with rotating
// gradients (alpha) and an analytic gradient output, used here for shading.
// params: x = scale, y = rotation speed, z = period (0 = no tiling)
[[ stitchable ]] half4 psrdnoiseFlow(float2 position, half4 color, float2 size, float time, float4 params) {
    float2 st = lygiaST(position, size) * params.x;
    float2 g;
    float n = psrdnoise(st, float2(params.z), time * params.y, g);

    // Fake lighting from the analytic gradient.
    float3 normal = normalize(float3(-g * 0.25, 1.0));
    float light = dot(normal, normalize(float3(0.4, 0.6, 0.7)));
    float3 base = mix(float3(0.10, 0.20, 0.45), float3(0.95, 0.75, 0.35), n * 0.5 + 0.5);
    return opaque(base * (0.35 + 0.75 * light));
}
