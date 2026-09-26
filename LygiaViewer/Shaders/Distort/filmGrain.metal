#include <metal_stdlib>
using namespace metal;
#include "Common.h"

// Let LYGIA's texture functions sample the SwiftUI layer (see Common.h).
#define SAMPLER_TYPE LayerTexture
#define SAMPLER_FNC(TEX, UV) TEX.sampleUV(UV)

#include "lygia/distort/grain.msl"

// grain(tex, st, resolution, time, size): film grain from 3D noise, blended
// with soft light and reduced on bright areas.
// params: x = grain size, y = animate (0/1), z = darken (to show grain on highlights)
[[ stitchable ]] half4 filmGrain(float2 position, SwiftUI::Layer layer, float2 size, float time, float4 params) {
    LayerTexture tex = { layer, size };
    float2 uv = lygiaUV(position, size);
    float t = params.y > 0.5 ? floor(time * 24.0) : 0.0;
    float3 rgb = grain(tex, uv, size, t, params.x);
    return opaque(rgb * (1.0 - params.z));
}
