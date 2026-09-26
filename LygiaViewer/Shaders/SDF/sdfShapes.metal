#include <metal_stdlib>
using namespace metal;
#include "Common.h"

#include "lygia/sdf/circleSDF.msl"
#include "lygia/sdf/rectSDF.msl"
#include "lygia/sdf/starSDF.msl"
#include "lygia/sdf/polySDF.msl"
#include "lygia/sdf/flowerSDF.msl"
#include "lygia/sdf/gearSDF.msl"
#include "lygia/sdf/heartSDF.msl"
#include "lygia/sdf/hexSDF.msl"
#include "lygia/sdf/triSDF.msl"
#include "lygia/sdf/vesicaSDF.msl"
#include "lygia/sdf/rhombSDF.msl"
#include "lygia/sdf/crossSDF.msl"
#include "lygia/draw/fill.msl"
#include "lygia/draw/stroke.msl"

static float shapeSDF(int shape, float2 st, int n) {
    switch (shape) {
        case 0:  return circleSDF(st);
        case 1:  return rectSDF(st, float2(1.0, 0.7));
        case 2:  return starSDF(st, n, 0.09);
        case 3:  return polySDF(st, n);
        case 4:  return flowerSDF(st, n);
        case 5:  return gearSDF(st, 10.0, n) + 0.5; // gearSDF is 0 at the edge
        case 6:  return heartSDF(st) * 0.1 + 0.5; // heartSDF is 0 at the edge
        case 7:  return hexSDF(st);
        case 8:  return triSDF(st);
        case 9:  return vesicaSDF(st, 0.4);
        case 10: return rhombSDF(st);
        default: return crossSDF(st, 1.0);
    }
}

// LYGIA's 2D "SDFs" are normalized shape fields: most are ~0.5..1.0 at the
// silhouette, so fill(sdf, size) / stroke(sdf, size, width) draw them.
// params: x = shape, y = sides / points, z = size, w = mode (0 fill, 1 stroke, 2 field)
[[ stitchable ]] half4 sdfShapes(float2 position, half4 color, float2 size, float time, float4 params) {
    float2 st = lygiaST(position, size);
    int shape = int(params.x + 0.5);
    int n = int(params.y + 0.5);
    float d = shapeSDF(shape, st, n);
    int mode = int(params.w + 0.5);

    float3 bg = float3(0.08, 0.09, 0.11);
    float3 ink = float3(0.98, 0.80, 0.35);
    if (mode == 0) {
        return opaque(mix(bg, ink, fill(d, params.z)));
    }
    if (mode == 1) {
        float s = stroke(d, params.z, 0.03) + stroke(d, params.z * 0.7, 0.015) * 0.6;
        return opaque(mix(bg, ink, clamp(s, 0.0, 1.0)));
    }
    // Field view: inside warm, outside cool, animated iso-lines.
    float3 c = d < params.z ? float3(0.95, 0.60, 0.30) : float3(0.35, 0.65, 0.95);
    c *= 0.55 + 0.45 * smoothstep(0.35, 0.65, abs(fract(d * 12.0 - time * 0.5) - 0.5) * 2.0);
    c = mix(c, float3(1.0), stroke(d, params.z, 0.012));
    return opaque(c);
}
