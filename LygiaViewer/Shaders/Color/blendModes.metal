#include <metal_stdlib>
using namespace metal;
#include "Common.h"

namespace { // LYGIA: internal linkage, see Common.h
#include "lygia/color/blend/multiply.msl"
#include "lygia/color/blend/screen.msl"
#include "lygia/color/blend/overlay.msl"
#include "lygia/color/blend/softLight.msl"
#include "lygia/color/blend/hardLight.msl"
#include "lygia/color/blend/colorDodge.msl"
#include "lygia/color/blend/colorBurn.msl"
#include "lygia/color/blend/difference.msl"
#include "lygia/color/blend/exclusion.msl"
#include "lygia/color/blend/linearLight.msl"
#include "lygia/color/blend/hue.msl"
#include "lygia/color/blend/color.msl"
#include "lygia/color/blend/luminosity.msl"
#include "lygia/color/space/hsv2rgb.msl"
#include "lygia/sdf/circleSDF.msl"
}

static float3 blendMode(int mode, float3 base, float3 blend, float opacity) {
    switch (mode) {
        case 0:  return blendMultiply(base, blend, opacity);
        case 1:  return blendScreen(base, blend, opacity);
        case 2:  return blendOverlay(base, blend, opacity);
        case 3:  return blendSoftLight(base, blend, opacity);
        case 4:  return blendHardLight(base, blend, opacity);
        case 5:  return blendColorDodge(base, blend, opacity);
        case 6:  return blendColorBurn(base, blend, opacity);
        case 7:  return blendDifference(base, blend, opacity);
        case 8:  return blendExclusion(base, blend, opacity);
        case 9:  return blendLinearLight(base, blend, opacity);
        case 10: return blendHue(base, blend, opacity);
        case 11: return blendColor(base, blend, opacity);
        default: return blendLuminosity(base, blend, opacity);
    }
}

// Base = hue sweep with a vertical value ramp. Blend = soft animated rings.
// The top strip shows the base, the bottom strip the blend layer alone.
// params: x = mode, y = opacity
[[ stitchable ]] half4 blendModes(float2 position, half4 color, float2 size, float time, float4 params) {
    float2 uv = lygiaUV(position, size);
    float2 st = lygiaST(position, size);
    float3 base = hsv2rgb(float3(uv.x, 0.75, mix(0.25, 1.0, uv.y)));
    float rings = 0.5 + 0.5 * cos(circleSDF(st) * 18.0 - time * 2.0);
    float3 blend = mix(float3(0.10, 0.20, 0.60), float3(1.0, 0.85, 0.55), rings);

    if (uv.y > 0.92) return opaque(base);
    if (uv.y < 0.08) return opaque(blend);
    return opaque(blendMode(int(params.x + 0.5), base, blend, params.y));
}
