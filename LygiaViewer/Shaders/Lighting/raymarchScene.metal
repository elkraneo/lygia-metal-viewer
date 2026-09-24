#include <metal_stdlib>
using namespace metal;
#include "Common.h"

// LYGIA's raymarcher with pbr shading and soft shadows. Light options are
// literals: Metal has no global uniforms.
#define LIGHT_DIRECTION         float3(0.6, 0.8, -0.4)
#define LIGHT_COLOR             float3(1.0, 0.95, 0.9)
#define LIGHT_INTENSITY         1.4
#define RAYMARCH_SHADING_FNC    pbr
#define RAYMARCH_SAMPLES        96
#define RAYMARCH_MAX_DIST       30.0
#define RAYMARCH_BACKGROUND     float3(0.02, 0.025, 0.035)

#include "lygia/lighting/material/new.msl"
#include "lygia/sdf/sphereSDF.msl"
#include "lygia/sdf/boxSDF.msl"
#include "lygia/sdf/torusSDF.msl"
#include "lygia/sdf/planeSDF.msl"
#include "lygia/color/tonemap/aces.msl"
#include "lygia/color/space/linear2gamma.msl"

static inline Material closest(Material a, Material b) { return a.sdf < b.sdf ? a : b; }

// The scene: raymarch() calls this for every step.
static inline Material raymarchMap(float3 p) {
    Material m = materialNew(float3(0.45, 0.45, 0.44), 0.8, 0.0, planeSDF(p + float3(0.0, 1.0, 0.0)));
    m = closest(m, materialNew(float3(0.9, 0.08, 0.06), 0.25, 0.0, sphereSDF(p - float3(-1.3, 0.0, 0.0), 1.0)));
    m = closest(m, materialNew(float3(1.0, 0.78, 0.34), 0.15, 1.0, sphereSDF(p - float3(1.3, 0.0, 0.0), 1.0)));
    m = closest(m, materialNew(float3(0.1, 0.3, 0.9), 0.5, 0.0, boxSDF(p - float3(0.2, -0.45, 2.3), float3(1.1))));
    m = closest(m, materialNew(float3(0.95), 0.05, 1.0, torusSDF(p - float3(0.0, -0.75, -1.6), float2(0.6, 0.25))));
    return m;
}

#include "lygia/lighting/raymarch.msl"   // before pbr, so lights use raymarchSoftShadow
#include "lygia/lighting/pbr.msl"

// params: x = orbit speed, y = camera distance, z = camera height, w = exposure
[[ stitchable ]] half4 raymarchScene(float2 position, half4 color, float2 size, float time, float4 params) {
    float a = time * params.x + 0.6;
    float3 camera = float3(sin(a) * params.y, params.z, cos(a) * params.y);
    // space/lookAt flips the image 180 degrees (as in GLSL), so flip st back
    float2 st = 1.0 - lygiaST(position, size);
    float4 c = raymarch(camera, float3(0.0, -0.2, 0.0), st);
    return opaque(linear2gamma(tonemapACES(c.rgb * params.w)));
}
