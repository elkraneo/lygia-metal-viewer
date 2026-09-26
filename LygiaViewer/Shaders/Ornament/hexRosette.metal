#include <metal_stdlib>
using namespace metal;
#include "Common.h"

#include "lygia/space/hexTile.msl"
#include "lygia/space/rotate.msl"
#include "lygia/sdf/flowerSDF.msl"
#include "lygia/sdf/hexSDF.msl"
#include "lygia/sdf/circleSDF.msl"
#include "lygia/sdf/starSDF.msl"
#include "lygia/draw/stroke.msl"
#include "lygia/draw/fill.msl"
#include "lygia/math/const.msl"

// Ornament: a six-petal rosette in every hexagon, counter-rotating per ring.
// hexTile -> flowerSDF / starSDF / hexSDF -> stroke.
// params: x = scale, y = rotation speed, z = petals, w = line width
[[ stitchable ]] half4 hexRosette(float2 position, half4 color, float2 size, float time, float4 params) {
    float2 st = lygiaST(position, size);
    float4 t = hexTile(st * params.x);
    float ring = fmod(abs(t.z + t.w), 2.0) * 2.0 - 1.0;   // alternate rotation direction
    float2 p = rotate(t.xy, time * params.y * ring);
    int petals = int(params.z + 0.5);
    float w = params.w;

    float3 paper = float3(0.96, 0.93, 0.86);
    float3 ink = float3(0.10, 0.20, 0.40);
    float3 gold = float3(0.80, 0.55, 0.20);

    float3 c = paper;
    c = mix(c, ink, stroke(hexSDF(t.xy), 0.98, w));
    c = mix(c, ink, stroke(flowerSDF(p, petals), 0.35, w));
    c = mix(c, gold, fill(starSDF(rotate(p, PI / float(petals)), petals, 0.12), 0.25));
    c = mix(c, ink, stroke(circleSDF(t.xy), 0.62, w * 0.7));
    c = mix(c, ink, fill(circleSDF(t.xy), 0.06));
    return opaque(c);
}
