#include <metal_stdlib>
using namespace metal;
#include "Common.h"

#include "lygia/space/cart2polar.msl"
#include "lygia/space/rotate.msl"
#include "lygia/space/scale.msl"
#include "lygia/space/checkerTile.msl"
#include "lygia/math/const.msl"

// cart2polar turns (x, y) into (angle, radius); a checkerboard in that space
// becomes a polar grid. rotate/scale transform st first.
// params: x = angular cells, y = radial cells, z = twist, w = zoom
[[ stitchable ]] half4 polarWarp(float2 position, half4 color, float2 size, float time, float4 params) {
    float2 st = lygiaST(position, size);
    st = scale(st, params.w);
    st = rotate(st, time * 0.2);
    float2 p = cart2polar(st - 0.5);            // (angle -PI..PI, radius)
    float2 uv = float2(p.x / TAU + 0.5 + p.y * params.z, log(p.y + 1e-4) - time * 0.3);
    float c = checkerTile(uv * float2(params.x, params.y));
    float fade = smoothstep(0.0, 0.08, p.y);
    return opaque(mix(float3(0.08), mix(float3(0.10, 0.10, 0.14), float3(0.95, 0.90, 0.80), c), fade));
}
