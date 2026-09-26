#include <metal_stdlib>
using namespace metal;
#include "Common.h"

#include "lygia/generative/snoise.msl"
#include "lygia/generative/cnoise.msl"
#include "lygia/generative/gnoise.msl"
#include "lygia/generative/pnoise.msl"
#include "lygia/generative/psrdnoise.msl"

// Compare LYGIA's 3D noise functions, animated along z.
// params: x = noise (0 snoise, 1 cnoise, 2 gnoise, 3 pnoise, 4 psrdnoise), y = scale, z = speed
[[ stitchable ]] half4 noiseTypes(float2 position, half4 color, float2 size, float time, float4 params) {
    float3 p = float3(lygiaST(position, size) * params.y, time * params.z);
    int kind = int(params.x + 0.5);

    float n;
    if (kind == 0)      n = snoise(p) * 0.5 + 0.5;
    else if (kind == 1) n = cnoise(p) * 0.5 + 0.5;
    else if (kind == 2) n = gnoise(p);
    else if (kind == 3) n = pnoise(p, float3(4.0)) * 0.5 + 0.5; // tiles every 4 units
    else                n = psrdnoise(p) * 0.5 + 0.5;

    return opaque(n);
}
