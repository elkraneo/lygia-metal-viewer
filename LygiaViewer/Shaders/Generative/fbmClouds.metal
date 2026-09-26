#include <metal_stdlib>
using namespace metal;
#include "Common.h"

#include "lygia/generative/fbm.msl"

// Domain-warped fractal Brownian motion (Inigo Quilez style):
// fbm(p + warp * fbm(p)).
// params: x = scale, y = speed, z = warp amount
[[ stitchable ]] half4 fbmClouds(float2 position, half4 color, float2 size, float time, float4 params) {
    float2 st = lygiaST(position, size) * params.x;
    float t = params.y;

    float2 q = float2(fbm(float3(st, t)),
                      fbm(float3(st + float2(5.2, 1.3), t)));
    float n = fbm(float3(st + params.z * q, t * 0.5)) * 0.5 + 0.5;

    float3 c = mix(float3(0.04, 0.07, 0.18), float3(0.98, 0.86, 0.68), smoothstep(0.25, 0.85, n));
    c = mix(c, float3(0.10, 0.52, 0.60), clamp(length(q), 0.0, 1.0) * 0.45);
    return opaque(c);
}
