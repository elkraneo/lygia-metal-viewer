#include <metal_stdlib>
using namespace metal;
#include "Common.h"

namespace { // LYGIA: internal linkage, see Common.h
#include "lygia/sdf/circleSDF.msl"
#include "lygia/sdf/rectSDF.msl"
#include "lygia/sdf/opUnion.msl"
#include "lygia/sdf/opSubtraction.msl"
#include "lygia/sdf/opIntersection.msl"
#include "lygia/sdf/opOnion.msl"
#include "lygia/draw/stroke.msl"
}

// Smooth boolean operators on two shapes. The fields are shifted so 0 is the
// silhouette (circleSDF is 2 * length, rectSDF is a box norm).
// params: x = op (0 union, 1 subtract, 2 intersect), y = smoothness k, z = onion thickness (0 = off)
[[ stitchable ]] half4 sdfBooleans(float2 position, half4 color, float2 size, float time, float4 params) {
    float2 st = lygiaST(position, size);
    float2 offset = 0.18 * float2(cos(time * 0.8), sin(time * 1.1));
    float a = circleSDF(st + offset) - 0.55;
    float b = (rectSDF(st - offset, float2(0.55)) - 1.0) * 0.55;

    int op = int(params.x + 0.5);
    float k = max(params.y, 1e-4);
    float d = op == 0 ? opUnion(a, b, k) : (op == 1 ? opSubtraction(a, b, k) : opIntersection(a, b, k));
    if (params.z > 0.0) d = opOnion(d, params.z);

    float3 c = d > 0.0 ? float3(0.90, 0.60, 0.30) : float3(0.40, 0.70, 0.95);
    c *= 1.0 - exp(-8.0 * abs(d));
    c *= 0.8 + 0.2 * cos(d * 120.0);
    c = mix(c, float3(1.0), stroke(d, 0.0, 0.008));
    return opaque(c);
}
