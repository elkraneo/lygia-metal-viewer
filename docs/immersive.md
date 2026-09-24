# Immersive renderer (visionOS)

On visionOS the sidebar has an **Immersive (Metal)** button that opens a fully immersive space drawn by the app's own Metal renderer. Launch with `-immersive YES` to open it at startup:

```sh
xcrun simctl launch booted io.210x7.LygiaViewer -immersive YES
```

![Immersive scene in the visionOS simulator](immersive.png)

Surfaces are shaded with LYGIA's `pbr()` in `immersiveShade()` (`ImmersiveLighting.h`), with a directional sun and LYGIA's `fakeCube` environment. For a real environment map, pass a `texturecube<float>` as the last argument: `pbr(mat, shadingData, cubemap)`.

RealityKit materials on visionOS don't accept custom Metal shaders (they use Shader Graph), so a Compositor Services space is the way to run your own Metal there. SwiftUI shaders still work in windows and volumes.

## How it works

- `LygiaViewer/Immersive/`: `ImmersiveSpace.swift` (the `ImmersiveSpace` + `CompositorLayer`, layer configuration, open/close button), `ImmersiveRenderer.swift` (render loop), `ImmersiveUniforms.swift` (Swift copies of the shader structs).
- `LygiaViewer/Shaders/Immersive/`: `ImmersiveScene.metal` (scene, raymarcher, entry points), `ImmersiveLighting.h` (all lighting, in `immersiveShade()`), `ImmersiveTypes.h` (uniforms).
- **Render loop:** runs on its own thread through a `TaskExecutor`, never on the main thread. Each frame: `queryNextFrame`, `predictTiming`, wait for the optimal input time, query the drawables, predict the head pose with ARKit `WorldTrackingProvider.queryDeviceAnchor(atTimestamp:)` at the presentation time, set it on the drawable, encode, `encodePresent`, commit.
- **Layout:** layered when the device supports it (both eyes in one 2D-array texture), drawn in a single pass with vertex amplification. The eye's slice and viewport come from `MTLVertexAmplificationViewMapping`. Dedicated and shared layouts use the same code: views are grouped by texture, with one pass per texture.
- **Per-eye camera:** `drawable.computeProjection(convention: .rightUpBack, viewIndex:)` gives the projection. The camera is `deviceAnchor.originFromAnchorTransform * view.transform`. The fragment shader rebuilds the world ray from the inverse projection and that camera transform.
- **Depth:** Compositor Services only supports reverse-Z (1 = near, 0 = far; `depthRange` is `(far, near)`, far = infinity by default). The shader projects the hit point with the eye's view-projection and writes `clip.z / clip.w` to `[[depth(any)]]`. Misses write 0. The compositor uses this depth to reproject frames.
- **Foveation:** turned on when `capabilities.supportsFoveation` (on device; Simulator doesn't support it). The drawable's rasterization rate map goes on the render pass. With a rate map, `[[position]]` is in physical (compressed) coordinates, not screen coordinates. So the shader doesn't use it: it rebuilds rays from an NDC value interpolated from the full-screen triangle, which stays correct either way. If you need screen pixels in a fragment shader, convert with `rasterizationRateMap.mapPhysicalToScreenCoordinates` (or pass the map's parameter buffer to the shader).
- **Simulator:** it renders one view (no stereo) and reports the head at the space origin rather than about 1.6 m above the floor. When the first tracked head pose is below 0.8 m, the renderer lifts the scene so the ornaments stay at eye height.

Surfaces are shaded with LYGIA's physically based `pbr()` (`lighting/pbr.msl`), with one directional sun set through LYGIA's `LIGHT_*` options and LYGIA's `fakeCube` as the environment; all of it is in `immersiveShade()` in `ImmersiveLighting.h`. To use a real environment map, pass a `texturecube<float>` as the last argument: `pbr(mat, shadingData, cubemap)`. You can also define `RAYMARCH_MAP_FNC` as `immersiveMap` and let `lighting/raymarch` run the march too; keep the ray setup and depth output in `immersiveFragment`.
