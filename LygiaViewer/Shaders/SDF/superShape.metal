#include <metal_stdlib>
using namespace metal;
#include "Common.h"

#include "lygia/sdf/superShapeSDF.msl"
#include "lygia/draw/fill.msl"
#include "lygia/draw/stroke.msl"

// Gielis superformula. m = symmetry, n1..n3 = exponents.
// params: x = m, y = n1, z = n2, w = n3
[[ stitchable ]] half4 superShape(float2 position, half4 color, float2 size, float time, float4 params) {
    float2 st = lygiaST(position, size);
    float breathe = 1.0 + 0.1 * sin(time * 1.5);
    float d = superShapeSDF(st, 1.0 * breathe, 1.0, 1.0, params.y, params.z, params.w, params.x);

    float3 c = mix(float3(0.07, 0.07, 0.10), float3(0.30, 0.20, 0.55), fill(d, 0.0, 0.02));
    for (int i = 0; i < 5; i++) {
        c += stroke(d, float(i) * 0.25, 0.02) * float3(0.95, 0.75, 0.45) * (1.0 - float(i) * 0.18);
    }
    return opaque(c);
}
