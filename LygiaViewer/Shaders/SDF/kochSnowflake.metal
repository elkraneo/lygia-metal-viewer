#include <metal_stdlib>
using namespace metal;
#include "Common.h"

#include "lygia/sdf/kochSDF.msl"
#include "lygia/space/rotate.msl"
#include "lygia/draw/stroke.msl"

// kochSDF(st, iterations) is a true signed distance: negative inside.
// params: x = iterations, y = rotation speed, z = band density
[[ stitchable ]] half4 kochSnowflake(float2 position, half4 color, float2 size, float time, float4 params) {
    float2 st = rotate(lygiaST(position, size), params.y);
    float d = kochSDF(st, int(params.x + 0.5));

    float3 c = d > 0.0 ? float3(0.90, 0.60, 0.30) : float3(0.40, 0.70, 0.95);
    c *= 1.0 - exp(-12.0 * abs(d));
    c *= 0.8 + 0.2 * cos(d * params.z * 6.2831);
    c = mix(c, float3(1.0), stroke(d, 0.0, 0.006));
    return opaque(c);
}
