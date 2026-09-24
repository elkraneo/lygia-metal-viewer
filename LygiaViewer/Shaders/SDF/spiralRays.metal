#include <metal_stdlib>
using namespace metal;
#include "Common.h"

namespace { // LYGIA: internal linkage, see Common.h
#include "lygia/sdf/spiralSDF.msl"
#include "lygia/sdf/raysSDF.msl"
#include "lygia/sdf/circleSDF.msl"
#include "lygia/space/rotate.msl"
#include "lygia/draw/stroke.msl"
#include "lygia/draw/fill.msl"
}

// spiralSDF and raysSDF XOR-ed together, like a PixelSpirit card.
// params: x = spiral turns, y = rays, z = rotation speed
[[ stitchable ]] half4 spiralRays(float2 position, half4 color, float2 size, float time, float4 params) {
    float2 st = lygiaST(position, size);
    float spiral = step(0.5, spiralSDF(rotate(st, -time * params.z), params.x));
    float rays = step(0.5, raysSDF(rotate(st, time * params.z * 0.5), int(params.y + 0.5)));
    float v = abs(spiral - rays);
    v *= fill(circleSDF(st), 0.9);
    v = mix(v, 1.0, stroke(circleSDF(st), 0.92, 0.02));
    return opaque(mix(float3(0.06, 0.05, 0.08), float3(0.96, 0.92, 0.84), v));
}
