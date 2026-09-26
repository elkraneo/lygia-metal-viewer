// Shared prelude for every LygiaViewer demo shader.
//
// Conventions
// -----------
// Every demo is one .metal file with one [[ stitchable ]] function named like
// the file. The Swift side always passes the same arguments:
//
//   colorEffect:      half4  name(float2 position, half4 color,           float2 size, float time, float4 params)
//   layerEffect:      half4  name(float2 position, SwiftUI::Layer layer,  float2 size, float time, float4 params)
//   distortionEffect: float2 name(float2 position,                        float2 size, float time, float4 params)
//
// A speed slider (`.speed` in DemoCatalog) arrives already accumulated: use
// `params.y` where you would write `time * params.y`. The app adds speed * frame
// time each frame, so moving the slider changes the rate without a jump.
//
// Include LYGIA directly. Its functions are `static inline`, so every .metal
// file gets its own copy and the files link into one library.

#pragma once

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// LYGIA's aastep() (used by fill/stroke/draw) is a hard step unless AA_EDGE is
// defined. Metal visible functions can't use derivatives, so use a constant
// edge in LYGIA's normalized 0..1 space.
#ifndef AA_EDGE
#define AA_EDGE 0.004
#endif

namespace {

/// LYGIA-style coordinates: y up, the shorter side spans 0...1 and the view
/// center is (0.5, 0.5), so shapes stay round in any aspect ratio.
inline float2 lygiaST(float2 position, float2 size) {
    float2 p = float2(position.x, size.y - position.y);
    return (p - 0.5 * size) / min(size.x, size.y) + 0.5;
}

/// Plain 0...1 uv over the whole view, y up.
inline float2 lygiaUV(float2 position, float2 size) {
    return float2(position.x / size.x, 1.0 - position.y / size.y);
}

/// Back from lygiaUV space to SwiftUI points (for distortion/layer sampling).
inline float2 uvToPosition(float2 uv, float2 size) {
    return float2(uv.x * size.x, (1.0 - uv.y) * size.y);
}

inline half4 opaque(float3 rgb) {
    return half4(half3(clamp(rgb, 0.0, 1.0)), 1.0h);
}

inline half4 opaque(float v) {
    return opaque(float3(v));
}

/// Pixel size in lygiaST units, handy for anti-aliasing by hand.
inline float pixelST(float2 size) {
    return 1.0 / min(size.x, size.y);
}

/// Cheap cosine palette (Inigo Quilez) for coloring scalar fields.
inline float3 cosPalette(float t, float3 a, float3 b, float3 c, float3 d) {
    return a + b * cos(6.28318530718 * (c * t + d));
}

// Wraps a SwiftUI::Layer so LYGIA's texture-based functions (chromaAB, stretch,
// barrel, pincushion...) can sample it with uv coordinates. Use it like:
//
//   #define SAMPLER_TYPE LayerTexture
//   #define SAMPLER_FNC(TEX, UV) TEX.sampleUV(UV)
//   #include "lygia/distort/chromaAB.msl"
struct LayerTexture {
    SwiftUI::Layer layer;
    float2 size;

    float4 sampleUV(float2 uv) const {
        return float4(layer.sample(uvToPosition(uv, size)));
    }
};

} // namespace
