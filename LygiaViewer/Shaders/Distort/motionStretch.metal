#include <metal_stdlib>
using namespace metal;
#include "Common.h"

// Let LYGIA's texture functions sample the SwiftUI layer (see Common.h).
#define SAMPLER_TYPE LayerTexture
#define SAMPLER_FNC(TEX, UV) TEX.sampleUV(UV)
#define STRETCH_SAMPLES 24

namespace { // LYGIA: internal linkage, see Common.h
#include "lygia/distort/stretch.msl"
}

// stretch(tex, st, direction) averages STRETCH_SAMPLES samples along a
// direction: a directional / motion blur.
// params: x = length, y = angle (turns), z = rotation speed
[[ stitchable ]] half4 motionStretch(float2 position, SwiftUI::Layer layer, float2 size, float time, float4 params) {
    LayerTexture tex = { layer, size };
    float2 uv = lygiaUV(position, size);
    float a = (params.y + time * params.z) * 6.2831853;
    float2 dir = float2(cos(a), sin(a)) * params.x / float(STRETCH_SAMPLES);
    return half4(stretch(tex, uv - dir * float(STRETCH_SAMPLES) * 0.5, dir));
}
