#include <metal_stdlib>
using namespace metal;
#include "Common.h"

namespace { // LYGIA: internal linkage, see Common.h
#include "lygia/color/palette/spectral.msl"
}

// The spectral palette family (visible spectrum approximations), top to bottom:
// spectral(x), spectral_gems, spectral_geoffrey, spectral_soft, spectral_zucconi, spectral_zucconi6.
// params: x = scroll speed, y = repeats
[[ stitchable ]] half4 spectralPalettes(float2 position, half4 color, float2 size, float time, float4 params) {
    float2 uv = lygiaUV(position, size);
    float x = fract(uv.x * params.y + time * params.x);
    float row = (1.0 - uv.y) * 6.0;
    int band = min(int(row), 5);
    float3 c = band == 0 ? spectral(x)
             : band == 1 ? spectral_gems(x)
             : band == 2 ? spectral_geoffrey(x)
             : band == 3 ? spectral_soft(x)
             : band == 4 ? spectral_zucconi(x)
             : spectral_zucconi6(x);
    return opaque(c * step(0.05, fract(row)));
}
