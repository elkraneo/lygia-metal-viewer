#include <metal_stdlib>
using namespace metal;
#include "Common.h"

#include "lygia/space/windmillTile.msl"
#include "lygia/sdf/triSDF.msl"
#include "lygia/sdf/rhombSDF.msl"
#include "lygia/sdf/rectSDF.msl"
#include "lygia/draw/stroke.msl"
#include "lygia/draw/fill.msl"
#include "lygia/math/const.msl"

// Ornament: windmillTile rotates each tile of a 2x2 block by 0/90/180/270
// degrees, turning one asymmetric motif into a pinwheel pattern.
// params: x = scale, y = turn (fraction of full rotation per block), z = line width
[[ stitchable ]] half4 windmillPinwheel(float2 position, half4 color, float2 size, float time, float4 params) {
    float2 st = lygiaST(position, size);
    float2 scaled = st * params.x;
    float turn = TAU * (params.y + 0.02 * sin(time));
    float4 t = windmillTile(sqTile(scaled), turn);
    float2 p = t.xy;

    float3 c = float3(0.94, 0.90, 0.82);
    float3 ink = float3(0.12, 0.14, 0.22);
    float3 red = float3(0.80, 0.25, 0.20);
    c = mix(c, red, fill(triSDF(p - float2(0.22, 0.10)), 0.55));
    c = mix(c, ink, stroke(rhombSDF(p + float2(0.2, 0.0)), 0.5, params.z));
    c = mix(c, ink, stroke(triSDF(p - float2(0.22, 0.10)), 0.55, params.z));
    c = mix(c, ink, stroke(rectSDF(t.xy), 1.0, params.z));
    return opaque(c);
}
