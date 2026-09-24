// Uniforms shared by the immersive (CompositorServices) renderer and its shaders.
// Keep in sync with LygiaViewer/Immersive/ImmersiveUniforms.swift.

#pragma once

#include <metal_stdlib>
using namespace metal;

/// One eye.
struct ImmersiveView {
    float4x4 viewProjection;     // world -> clip (reverse-Z, from the drawable)
    float4x4 inverseProjection;  // clip -> eye space
    float4x4 cameraToWorld;      // eye -> world (origin of the immersive space)
};

struct ImmersiveFrame {
    ImmersiveView views[2];
    float time;                  // seconds since the space opened
    uint viewCount;
    float2 padding;
};

/// Which views a render pass draws, indexed by [[amplification_id]].
struct ImmersivePassViews {
    uint viewIndex[2];
};
