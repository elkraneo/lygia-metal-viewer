#include <metal_stdlib>
using namespace metal;
#include "Common.h"

namespace { // LYGIA: internal linkage, see Common.h
#include "lygia/color/space/oklab2rgb.msl"
#include "lygia/color/space/rgb2srgb.msl"
#include "lygia/color/space/hsv2rgb.msl"
#include "lygia/color/space/lch2rgb.msl"
#include "lygia/color/space/k2rgb.msl"
#include "lygia/space/cart2polar.msl"
#include "lygia/math/const.msl"
}

// Conversions from color/space/*:
//   0 Oklab a/b plane at lightness L (oklab2rgb + rgb2srgb)
//   1 HSV wheel (hsv2rgb), value = L
//   2 CIE LCh wheel (lch2rgb + rgb2srgb), L 0..100, chroma 0..80, gray = out of gamut
//   3 Blackbody k2rgb, 1000 K -> 12000 K across x
// params: x = space, y = lightness / value
[[ stitchable ]] half4 colorSpaces(float2 position, half4 color, float2 size, float time, float4 params) {
    float2 st = lygiaST(position, size);
    int mode = int(params.x + 0.5);
    float L = params.y;

    if (mode == 3) {
        float2 uv = lygiaUV(position, size);
        return opaque(k2rgb(mix(1000.0, 12000.0, uv.x)));
    }

    float2 p = cart2polar(st - 0.5);      // (angle, radius)
    float r = p.y * 2.0;
    if (r > 1.0) return opaque(0.08);
    float hue = p.x / TAU + 0.5;

    float3 c;
    if (mode == 0) {
        float2 ab = (st - 0.5) * 0.35;    // a, b in -0.175..0.175 at the rim
        float3 lin = oklab2rgb(float3(L, ab));
        bool outOfGamut = any(lin < 0.0) || any(lin > 1.0);
        c = outOfGamut ? float3(0.12) : rgb2srgb(lin);
    } else if (mode == 1) {
        c = hsv2rgb(float3(hue, r, L));
    } else {
        float3 lin = lch2rgb(float3(L * 100.0, r * 80.0, hue * 360.0));
        c = any(lin < 0.0) || any(lin > 1.0) ? float3(0.12) : rgb2srgb(lin);
    }
    return opaque(c);
}
