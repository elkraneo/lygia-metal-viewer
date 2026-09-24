#include <metal_stdlib>
using namespace metal;
#include "Common.h"

namespace { // LYGIA: internal linkage, see Common.h
#include "lygia/space/hexTile.msl"
#include "lygia/sdf/hexSDF.msl"
#include "lygia/generative/random.msl"
#include "lygia/draw/stroke.msl"
#include "lygia/draw/fill.msl"
}

// hexTile() returns float4(local uv with the hex centered at 0.5, hex id).
// params: x = scale, y = ripple speed, z = line width
[[ stitchable ]] half4 hexTiles(float2 position, half4 color, float2 size, float time, float4 params) {
    float2 st = lygiaST(position, size);
    float4 t = hexTile(st * params.x);
    float r = random(t.zw);
    float wave = sin(length(t.zw) * 0.6 - time * params.y) * 0.5 + 0.5;

    float d = hexSDF(t.xy);
    float3 c = cosPalette(r * 0.4 + wave * 0.3, float3(0.5), float3(0.45), float3(1.0), float3(0.55, 0.65, 0.80));
    c *= fill(d, 0.35 + 0.5 * wave);
    c = mix(c, float3(0.95), stroke(d, 0.95, params.z));
    return opaque(c);
}
