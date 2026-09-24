#include <metal_stdlib>
using namespace metal;
#include "Common.h"

namespace { // LYGIA: internal linkage, see Common.h
#include "lygia/generative/voronoi.msl"
}

// voronoi() returns float3(cell point xy, distance to it). The point is
// unique per cell, so it doubles as a cell id for coloring.
// params: x = scale, y = speed, z = show distance (0/1)
[[ stitchable ]] half4 voronoiCells(float2 position, half4 color, float2 size, float time, float4 params) {
    float2 st = lygiaST(position, size) * params.x;
    float3 v = voronoi(st, time * params.y);

    float id = dot(v.xy, float2(0.61, 0.37));
    float3 c = cosPalette(id, float3(0.5), float3(0.5), float3(1.0), float3(0.0, 0.33, 0.67));
    c = mix(c, c * (1.0 - v.z), params.z);
    c *= smoothstep(0.02, 0.06, v.z); // dot at the cell point
    return opaque(c);
}
