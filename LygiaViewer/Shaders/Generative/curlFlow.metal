#include <metal_stdlib>
using namespace metal;
#include "Common.h"

#include "lygia/generative/curl.msl"
#include "lygia/generative/snoise.msl"

// Curl noise is divergence free: a good velocity field for fluid-like motion.
// Here the field is shown as color plus streaks along the flow.
// params: x = scale, y = speed, z = streak density
[[ stitchable ]] half4 curlFlow(float2 position, half4 color, float2 size, float time, float4 params) {
    float2 st = lygiaST(position, size) * params.x;
    float3 v = curl(float3(st, time * params.y));
    float2 dir = normalize(v.xy + 1e-5);

    float3 c = 0.5 + 0.5 * normalize(v + 1e-5);
    // Streaks: stripes perpendicular to the flow direction, broken up by noise.
    float stripes = sin(dot(st, float2(-dir.y, dir.x)) * params.z * 6.2831 + snoise(st * 3.0) * 2.0);
    c *= 0.65 + 0.35 * smoothstep(0.6, 1.0, stripes);
    return opaque(c);
}
