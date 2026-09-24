#include <metal_stdlib>
using namespace metal;
#include "Common.h"

namespace { // LYGIA: internal linkage, see Common.h
#include "lygia/color/tonemap/linear.msl"
#include "lygia/color/tonemap/reinhard.msl"
#include "lygia/color/tonemap/reinhardJodie.msl"
#include "lygia/color/tonemap/aces.msl"
#include "lygia/color/tonemap/filmic.msl"
#include "lygia/color/tonemap/uncharted2.msl"
#include "lygia/color/tonemap/unreal.msl"
#include "lygia/color/space/hsv2rgb.msl"
}

// HDR ramp (x: 0..exposure stops of light, per-row hue) pushed through
// seven tonemappers, top to bottom: linear (clipped), Reinhard,
// Reinhard-Jodie, ACES, filmic, Uncharted 2, Unreal.
// params: x = max intensity, y = saturation
[[ stitchable ]] half4 tonemaps(float2 position, half4 color, float2 size, float time, float4 params) {
    float2 uv = lygiaUV(position, size);
    float row = (1.0 - uv.y) * 7.0;
    int band = min(int(row), 6);
    float hue = fract(fract(row) * 0.9 + time * 0.03);
    float3 hdr = hsv2rgb(float3(hue, params.y, 1.0)) * uv.x * params.x;

    float3 c = band == 0 ? tonemapLinear(hdr)
             : band == 1 ? tonemapReinhard(hdr)
             : band == 2 ? tonemapReinhardJodie(hdr)
             : band == 3 ? tonemapACES(hdr)
             : band == 4 ? tonemapFilmic(hdr)
             : band == 5 ? tonemapUncharted2(hdr)
             : tonemapUnreal(hdr);
    float gap = step(0.04, fract(row));
    return opaque(c * gap);
}
