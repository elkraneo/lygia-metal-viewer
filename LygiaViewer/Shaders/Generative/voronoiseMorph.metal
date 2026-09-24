#include <metal_stdlib>
using namespace metal;
#include "Common.h"

namespace { // LYGIA: internal linkage, see Common.h
#include "lygia/generative/voronoise.msl"
}

// voronoise(p, u, v): u = cell jitter (0 grid, 1 voronoi), v = smoothness (0 cells, 1 noise).
// params: x = scale, y = u (jitter), z = v (smoothness)
[[ stitchable ]] half4 voronoiseMorph(float2 position, half4 color, float2 size, float time, float4 params) {
    float2 st = lygiaST(position, size) * params.x + float2(time * 0.2, 0.0);
    float n = voronoise(st, params.y, params.z);
    return opaque(cosPalette(n * 0.8 + 0.1, float3(0.5), float3(0.5), float3(1.0, 1.0, 0.5), float3(0.8, 0.9, 0.3)));
}
