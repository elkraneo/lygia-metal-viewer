#include <metal_stdlib>
using namespace metal;
#include "Common.h"

#include "lygia/space/kaleidoscope.msl"
#include "lygia/sdf/circleSDF.msl"
#include "lygia/sdf/polySDF.msl"
#include "lygia/sdf/gearSDF.msl"
#include "lygia/sdf/flowerSDF.msl"
#include "lygia/sdf/vesicaSDF.msl"
#include "lygia/draw/stroke.msl"
#include "lygia/draw/fill.msl"
#include "lygia/color/palette/spectral.msl"

// Ornament: kaleidoscope() folds the plane into N mirrored wedges, so shapes
// placed once (off-center) repeat around the circle.
// params: x = segments, y = rotation speed, z = line width, w = color shift speed
[[ stitchable ]] half4 mandala(float2 position, half4 color, float2 size, float time, float4 params) {
    float2 st = lygiaST(position, size);
    int n = int(params.x + 0.5);
    float2 k = kaleidoscope(st, float(n), params.y);   // folded coordinates, center 0.5
    float w = params.z;
    float r = circleSDF(st);                                   // 0 center, 1 at radius 0.5

    float3 c = float3(0.04, 0.03, 0.07);
    float3 hue = spectral(fract(r * 0.8 + params.w));

    c = mix(c, hue * 0.35, fill(gearSDF(st, 12.0, n), 0.0, 0.01));
    c = mix(c, hue, stroke(flowerSDF(st, n), 0.3, w));
    c = mix(c, float3(0.95, 0.85, 0.60), stroke(circleSDF(k - float2(0.26, 0.0)), 0.18, w));
    c = mix(c, hue, stroke(vesicaSDF(k - float2(0.12, 0.0), 0.2), 0.25, w));
    c = mix(c, float3(0.95, 0.85, 0.60), fill(polySDF(k - float2(0.38, 0.0), 3), 0.06));
    c = mix(c, float3(0.95, 0.85, 0.60), stroke(r, 0.95, w));
    c = mix(c, hue, stroke(polySDF(st, n), 0.7, w));
    c *= fill(r, 1.0, 0.01) * 0.85 + 0.15;
    return opaque(c);
}
