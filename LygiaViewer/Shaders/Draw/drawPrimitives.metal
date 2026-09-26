#include <metal_stdlib>
using namespace metal;
#include "Common.h"

#include "lygia/draw/circle.msl"
#include "lygia/draw/rect.msl"
#include "lygia/draw/hex.msl"
#include "lygia/draw/tri.msl"
#include "lygia/space/sqTile.msl"
#include "lygia/space/rotate.msl"

// draw/* wraps an SDF with fill() or stroke():
//   circle(st, size) fills, circle(st, size, width) strokes. Same for rect, hex, tri.
// params: x = size, y = stroke width, z = mode (0 fill, 1 stroke, 2 both), w = spin speed
[[ stitchable ]] half4 drawPrimitives(float2 position, half4 color, float2 size, float time, float4 params) {
    float2 st = lygiaST(position, size);
    float4 t = sqTile(st * 2.0);
    float2 p = rotate(t.xy, time * params.w);
    int cell = int(t.z) + int(t.w) * 2; // 0..3 inside the visible square
    int mode = int(params.z + 0.5);
    float s = params.x, w = params.y;

    float f = 0.0, k = 0.0;
    if (cell == 2)      { f = circle(p, s); k = circle(p, s, w); }
    else if (cell == 3) { f = rect(p, s);   k = rect(p, s, w); }
    else if (cell == 0) { f = hex(p, s);    k = hex(p, s, w); }
    else if (cell == 1) { f = tri(p, s);    k = tri(p, s, w); }

    float3 bg = float3(0.08, 0.09, 0.11) + 0.03 * float(cell % 2);
    float3 c = bg;
    if (mode != 1) c = mix(c, float3(0.25, 0.55, 0.95), f);
    if (mode != 0) c = mix(c, float3(0.98, 0.85, 0.45), k);
    return opaque(c);
}
