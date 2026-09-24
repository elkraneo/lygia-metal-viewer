// Lighting for the immersive scene: LYGIA's physically based shading
// (lighting/pbr.msl) with one directional sun and LYGIA's fakeCube as the
// environment.
//
// Everything light-related lives in immersiveShade(), so it's the one place to
// change lighting. To use a real environment map, pass a texturecube<float> as
// the last argument of pbr(): pbr(mat, shadingData, cubemap).

#pragma once

#include <metal_stdlib>
using namespace metal;

// The sun, also drawn as a disc in the sky.
constant float3 kImmersiveSunDirection = float3(0.45, 0.8, 0.35);   // toward the light
constant float3 kImmersiveSunColor     = float3(1.0, 0.92, 0.8) * 2.2;

// LYGIA's light options must be defined before its lighting headers. Metal has
// no global uniforms, so these are constants; for a moving light, build a
// LightDirectional yourself and call lightResolve() instead.
#define LIGHT_DIRECTION kImmersiveSunDirection
#define LIGHT_COLOR     kImmersiveSunColor
#define LIGHT_INTENSITY 1.0

#include "lygia/lighting/material/new.msl"
#include "lygia/lighting/pbr.msl"

struct ImmersiveSurface {
    float3 position;   // world space, meters
    float3 normal;     // world space, unit length
    float3 albedo;     // linear
    float roughness;   // 0 = mirror-ish, 1 = matte
    float metallic;    // 0...1
    float occlusion;   // 1 = unoccluded
    float3 emissive;   // linear, added after lighting
};

/// `toEye` points from the surface to the eye.
static inline float3 immersiveShade(ImmersiveSurface s, float3 toEye) {
    Material mat = materialNew();
    mat.position = s.position;
    mat.normal = s.normal;
    mat.albedo = float4(s.albedo, 1.0);
    mat.roughness = s.roughness;
    mat.metallic = s.metallic;
    mat.ambientOcclusion = s.occlusion;
    mat.emissive = s.emissive;

    ShadingData shadingData = shadingDataNew();
    shadingData.V = toEye;
    return pbr(mat, shadingData).rgb;
}
