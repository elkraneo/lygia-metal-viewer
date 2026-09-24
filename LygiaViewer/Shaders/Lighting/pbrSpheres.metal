#include <metal_stdlib>
using namespace metal;
#include "Common.h"

#include "lygia/lighting/material/new.msl"
#include "lygia/lighting/shadingData/new.msl"
#include "lygia/lighting/light/directional.msl"
#include "lygia/lighting/light/resolve.msl"
#include "lygia/lighting/light/iblEvaluate.msl"
#include "lygia/color/tonemap/aces.msl"
#include "lygia/color/space/linear2gamma.msl"

// LYGIA pbr, step by step, with a light built at runtime: Metal has no global
// uniforms, so instead of LIGHT_DIRECTION the sun is a LightDirectional passed
// to lightResolve(). Roughness goes from 0.05 to 1 across, metallic from 0 to 1
// down. The environment is LYGIA's fakeCube (no texture).
// params: x = sun speed, y = albedo hue, z = exposure
[[ stitchable ]] half4 pbrSpheres(float2 position, half4 color, float2 size, float time, float4 params) {
    const float2 grid = float2(4.0, 3.0);
    float2 cell = lygiaUV(position, size) * grid;
    float2 id = floor(cell);
    float2 p = (fract(cell) - 0.5) * 2.0;
    float aspect = (size.x / grid.x) / (size.y / grid.y);
    p.x *= aspect;
    float radius = 0.8 * min(aspect, 1.0);   // fit the cell's shorter side

    float r2 = dot(p, p);
    if (r2 > radius * radius) {
        float3 bg = mix(float3(0.02, 0.02, 0.03), float3(0.08, 0.09, 0.12), lygiaUV(position, size).y);
        return opaque(linear2gamma(bg));
    }
    float3 n = normalize(float3(p, sqrt(radius * radius - r2)));

    Material mat = materialNew();
    mat.position = n;
    mat.normal = n;
    mat.albedo = float4(cosPalette(params.y, float3(0.5), float3(0.45), float3(1.0), float3(0.0, 0.33, 0.67)), 1.0);
    mat.roughness = mix(0.05, 1.0, id.x / (grid.x - 1.0));
    mat.metallic = 1.0 - id.y / (grid.y - 1.0);

    ShadingData shadingData = shadingDataNew();
    shadingData.V = float3(0.0, 0.0, 1.0);
    shadingDataNew(mat, shadingData);
    lightIBLEvaluate(mat, shadingData);

    float a = time * params.x;
    LightDirectional sun;
    sun.direction = normalize(float3(cos(a), 0.7, 0.6 + 0.4 * sin(a)));
    sun.color = float3(1.0, 0.95, 0.88);
    sun.intensity = 2.0;
    lightResolve(sun, mat, shadingData);

    float3 c = shadingData.indirectDiffuse + shadingData.directDiffuse
             + shadingData.indirectSpecular + shadingData.directSpecular;
    return opaque(linear2gamma(tonemapACES(c * params.z)));
}
