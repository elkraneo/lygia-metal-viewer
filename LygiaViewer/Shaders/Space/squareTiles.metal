#include <metal_stdlib>
using namespace metal;
#include "Common.h"

namespace { // LYGIA: internal linkage, see Common.h
#include "lygia/space/sqTile.msl"
#include "lygia/space/mirrorTile.msl"
#include "lygia/space/brickTile.msl"
#include "lygia/space/windmillTile.msl"
#include "lygia/space/checkerTile.msl"
#include "lygia/sdf/rectSDF.msl"
#include "lygia/sdf/triSDF.msl"
#include "lygia/draw/stroke.msl"
#include "lygia/draw/fill.msl"
}

// Square tilings. Every *Tile returns float4(local uv 0..1, tile id).
// A triangle drawn in each tile shows how the local space is flipped/rotated.
// params: x = tiling (0 sqTile, 1 mirrorTile, 2 brickTile, 3 windmillTile), y = scale, z = checker overlay (0/1)
[[ stitchable ]] half4 squareTiles(float2 position, half4 color, float2 size, float time, float4 params) {
    float2 st = lygiaST(position, size) + float2(time * 0.05, 0.0);
    float2 scaled = st * params.y;
    int kind = int(params.x + 0.5);

    float4 t = kind == 0 ? sqTile(scaled)
             : kind == 1 ? mirrorTile(scaled)
             : kind == 2 ? brickTile(scaled)
             : windmillTile(scaled);

    float3 c = float3(t.xy, 0.55) * 0.55;
    c = mix(c, float3(0.2, 0.3, 0.5), params.z * checkerTile(scaled) * 0.6);
    c = mix(c, float3(0.98, 0.82, 0.40), fill(triSDF(t.xy + float2(0.0, 0.08)), 0.45));
    c = mix(c, float3(1.0), stroke(rectSDF(t.xy), 1.0, 0.05));
    return opaque(c);
}
