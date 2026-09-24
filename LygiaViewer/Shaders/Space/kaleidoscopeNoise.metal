#include <metal_stdlib>
using namespace metal;
#include "Common.h"

namespace { // LYGIA: internal linkage, see Common.h
#include "lygia/space/kaleidoscope.msl"
#include "lygia/generative/fbm.msl"
}

// kaleidoscope(st, segments, phase) folds polar space into mirrored wedges.
// params: x = segments, y = phase speed, z = noise scale
[[ stitchable ]] half4 kaleidoscopeNoise(float2 position, half4 color, float2 size, float time, float4 params) {
    float2 st = lygiaST(position, size);
    float2 k = kaleidoscope(st, params.x, time * params.y);
    float n = fbm(float3(k * params.z, time * 0.15)) * 0.5 + 0.5;
    float3 c = cosPalette(n + length(st - 0.5), float3(0.5), float3(0.5), float3(1.0), float3(0.0, 0.15, 0.30));
    return opaque(c * smoothstep(0.2, 0.8, n + 0.2));
}
