#include <metal_stdlib>
using namespace metal;
#include "Common.h"

#include "lygia/distort/barrel.msl"

// distortionEffect: returns, for each destination pixel, where to sample the
// SwiftUI view. barrel(uv, amount) pushes uvs away from (or toward) the center.
// params: x = amount (negative = pincushion-like), y = wobble
[[ stitchable ]] float2 barrelLens(float2 position, float2 size, float time, float4 params) {
    float2 uv = lygiaUV(position, size);
    float amount = params.x + params.y * sin(time * 1.5);
    return uvToPosition(barrel(uv, amount), size);
}
