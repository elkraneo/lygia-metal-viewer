#include <metal_stdlib>
using namespace metal;
#include "Common.h"

#include "lygia/sdf/juliaSDF.msl"

// juliaSDF returns i / 500 where i counts down from 500 when z escapes:
// ~1 = escaped immediately, 0 = never escaped (inside the set).
// c orbits a circle so the set morphs over time.
// params: x = zoom (r), y = speed, z = orbit radius
[[ stitchable ]] half4 juliaSet(float2 position, half4 color, float2 size, float time, float4 params) {
    float2 st = lygiaST(position, size);
    float a = params.y;
    float2 c = params.z * float2(cos(a), sin(a));
    float n = juliaSDF(st, c, params.x);
    float iterations = (1.0 - n) * 500.0;
    float v = log(iterations + 1.0) / log(501.0);   // 0 fast escape .. 1 inside
    float3 col = cosPalette(v * 1.5 + 0.1, float3(0.5), float3(0.5), float3(1.0), float3(0.0, 0.10, 0.20));
    col *= smoothstep(0.0, 0.25, v);
    return opaque(n == 0.0 ? float3(0.02, 0.02, 0.05) : col);
}
