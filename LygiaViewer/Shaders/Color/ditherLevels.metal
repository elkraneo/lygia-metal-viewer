#include <metal_stdlib>
using namespace metal;
#include "Common.h"

#include "lygia/color/dither/bayer.msl"
#include "lygia/color/dither/interleavedGradientNoise.msl"
#include "lygia/color/dither/triangleNoise.msl"
#include "lygia/color/dither/vlachos.msl"
#include "lygia/color/dither/shift.msl"

// A smooth gradient quantized to N levels per channel. Dithering trades the
// banding for noise. Pixel coordinates are passed explicitly (no gl_FragCoord in Metal).
// params: x = dither (0 none, 1 bayer, 2 interleavedGradientNoise, 3 triangleNoise, 4 vlachos, 5 shift), y = levels, z = pixel scale
[[ stitchable ]] half4 ditherLevels(float2 position, half4 color, float2 size, float time, float4 params) {
    float2 xy = floor(position / params.z);         // chunky pixels to see the pattern
    float2 uv = lygiaUV(xy * params.z, size);
    float3 c = mix(float3(0.05, 0.02, 0.20), float3(1.0, 0.75, 0.35), uv.x);
    c = mix(c, float3(0.2, 0.8, 0.9) * uv.x, smoothstep(0.3, 1.0, uv.y));

    int levels = int(params.y + 0.5);
    int kind = int(params.x + 0.5);
    float3 d = kind == 1 ? ditherBayer(c, xy, levels)
             : kind == 2 ? ditherInterleavedGradientNoise(c, xy, levels)
             : kind == 3 ? ditherTriangleNoise(c, xy, levels)
             : kind == 4 ? ditherVlachos(c, xy, levels)
             : kind == 5 ? ditherShift(c, xy, levels)
             : c;
    float n = float(levels - 1);
    return opaque(floor(d * n + 0.5) / n);
}
