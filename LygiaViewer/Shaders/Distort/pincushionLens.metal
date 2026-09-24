#include <metal_stdlib>
using namespace metal;
#include "Common.h"

namespace { // LYGIA: internal linkage, see Common.h
#include "lygia/distort/pincushion.msl"
}

// pincushion(st, resolution, amount) expects st = fragCoord / resolution.x
// (y scaled by the aspect ratio) and returns a 0..1 uv.
// params: x = amount, y = wobble
[[ stitchable ]] float2 pincushionLens(float2 position, float2 size, float time, float4 params) {
    float amount = params.x + params.y * sin(time * 1.3);
    float2 uv = lygiaUV(position, size);
    float2 st = float2(uv.x, uv.y * size.y / size.x);
    return uvToPosition(pincushion(st, size, amount), size);
}
