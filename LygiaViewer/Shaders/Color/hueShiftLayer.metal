#include <metal_stdlib>
using namespace metal;
#include "Common.h"

namespace { // LYGIA: internal linkage, see Common.h
#include "lygia/color/hueShift.msl"
#include "lygia/color/desaturate.msl"
#include "lygia/math/const.msl"
}

// layerEffect: recolors the SwiftUI view underneath (sample content).
// hueShift(color, radians) rotates the hue in HSL.
// params: x = hue angle (turns), y = spin speed (turns/s), z = desaturate amount
[[ stitchable ]] half4 hueShiftLayer(float2 position, SwiftUI::Layer layer, float2 size, float time, float4 params) {
    float4 c = float4(layer.sample(position));
    float3 rgb = c.a > 0.0 ? c.rgb / c.a : c.rgb;   // un-premultiply
    float angle = fract(params.x + time * params.y) * TAU;
    rgb = hueShift(rgb, angle);
    rgb = desaturate(rgb, params.z);
    return half4(half3(rgb * c.a), half(c.a));
}
