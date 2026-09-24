#include <metal_stdlib>
using namespace metal;
#include "Common.h"

// Let LYGIA's texture functions sample the SwiftUI layer (see Common.h).
#define SAMPLER_TYPE LayerTexture
#define SAMPLER_FNC(TEX, UV) TEX.sampleUV(UV)

namespace { // LYGIA: internal linkage, see Common.h
#include "lygia/distort/chromaAB.msl"
}

// chromaAB(tex, st, direction, distortion): samples R, G and B at
// st + direction * distortion.rgb. Direction points away from the center.
// params: x = strength, y = pulse
[[ stitchable ]] half4 chromaticAberration(float2 position, SwiftUI::Layer layer, float2 size, float time, float4 params) {
    LayerTexture tex = { layer, size };
    float2 uv = lygiaUV(position, size);
    float amount = params.x * (1.0 + params.y * sin(time * 2.0));
    float2 dir = (uv - 0.5);
    float3 rgb = chromaAB(tex, uv, dir, float3(amount, 0.0, -amount));
    return half4(half3(rgb), 1.0h);
}
