#include <metal_stdlib>
using namespace metal;
#include "Common.h"

#include "lygia/generative/worley.msl"

// worley() returns 1 - distance to the closest feature point.
// params: x = scale, y = speed, z = invert (0/1), w = sharpness
[[ stitchable ]] half4 worleyCells(float2 position, half4 color, float2 size, float time, float4 params) {
    float2 st = lygiaST(position, size) * params.x;
    float w = worley(float3(st, time * params.y));
    w = mix(w, 1.0 - w, params.z);
    w = pow(clamp(w, 0.0, 1.0), params.w);
    return opaque(mix(float3(0.02, 0.03, 0.08), float3(0.55, 0.85, 1.0), w));
}
