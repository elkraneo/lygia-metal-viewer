#include <metal_stdlib>
using namespace metal;
#include "Common.h"

#include "lygia/space/triTile.msl"
#include "lygia/generative/random.msl"
#include "lygia/draw/stroke.msl"

// triTile() splits the plane into equilateral triangles.
// xy = barycentric-like local coords, zw = triangle id (sign = up/down).
// params: x = scale, y = speed, z = line width
[[ stitchable ]] half4 triTiles(float2 position, half4 color, float2 size, float time, float4 params) {
    float2 st = lygiaST(position, size);
    float4 t = triTile(st * params.x);
    float edge = min(min(t.x, t.y), 1.0 - t.x - t.y); // distance to the triangle's edges
    float r = random(t.zw);

    float pulse = 0.5 + 0.5 * sin(time * params.y + r * 6.2831);
    float3 c = mix(float3(0.10, 0.12, 0.20), float3(0.30, 0.55, 0.85), r) * (0.6 + 0.4 * pulse);
    c = mix(c, float3(0.98, 0.85, 0.50), stroke(edge, 0.0, params.z));
    c = mix(c, float3(1.0, 0.45, 0.35), stroke(edge, 0.18 * pulse + 0.05, params.z * 0.6));
    return opaque(c);
}
