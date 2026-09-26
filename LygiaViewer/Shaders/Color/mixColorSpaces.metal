#include <metal_stdlib>
using namespace metal;
#include "Common.h"

#include "lygia/color/mixOklab.msl"
#include "lygia/color/mixSpectral.msl"
#include "lygia/color/mixRYB.msl"

static float3 pairColor(int pair, bool second) {
    switch (pair) {
        case 0:  return second ? float3(1.00, 0.90, 0.10) : float3(0.05, 0.15, 0.85); // blue -> yellow
        case 1:  return second ? float3(0.10, 0.80, 0.20) : float3(0.90, 0.10, 0.10); // red -> green
        case 2:  return second ? float3(0.00, 0.85, 0.90) : float3(0.90, 0.10, 0.70); // magenta -> cyan
        default: return second ? float3(1.00, 1.00, 1.00) : float3(0.02, 0.02, 0.05); // black -> white
    }
}

// Same two colors interpolated four ways, top to bottom:
// mix (sRGB), mixOklab, mixSpectral (Kubelka-Munk pigments), mixRYB.
// params: x = color pair, y = strip gap
[[ stitchable ]] half4 mixColorSpaces(float2 position, half4 color, float2 size, float time, float4 params) {
    float2 uv = lygiaUV(position, size);
    int pair = int(params.x + 0.5);
    float3 a = pairColor(pair, false);
    float3 b = pairColor(pair, true);
    float t = uv.x;

    float row = (1.0 - uv.y) * 4.0;
    int band = min(int(row), 3);
    float3 c = band == 0 ? mix(a, b, t)
             : band == 1 ? mixOklab(a, b, t)
             : band == 2 ? mixSpectral(a, b, t)
             : mixRYB(a, b, t);
    float gap = step(params.y, fract(row)) * step(fract(row), 1.0 - params.y);
    return opaque(c * gap);
}
