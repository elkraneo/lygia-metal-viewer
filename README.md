# LYGIA Metal Viewer

A SwiftUI app for browsing the Metal (MSL) port of the [LYGIA shader library](https://github.com/patriciogonzalezvivo/lygia) on macOS, iOS and visionOS.

![Kaleidoscope demo](docs/kaleidoscope.png)

- **38 live demos** across generative noise, SDFs, tiling, color, draw, distort and geometric ornaments. Each demo has parameter controls and shows the LYGIA files it includes, the calls it makes and its full source.
- **Playground (macOS):** write Metal with `#include "lygia/..."` and see it render as you type. The app inlines the includes itself, because Metal's runtime compiler can't read files.
- Demos are SwiftUI `[[ stitchable ]]` shaders (`.colorEffect`, `.layerEffect`, `.distortionEffect`), so they run the same on all three platforms.

| All demos | Playground |
|---|---|
| ![All demos](docs/gallery.png) | ![Playground](docs/playground.png) |

## Build

Requires Xcode 26 or later (tested with Xcode 27) and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
git clone --recursive https://github.com/elkraneo/lygia-metal-viewer.git
cd lygia-metal-viewer
xcodegen generate
open LygiaViewer.xcodeproj
```

The target builds for macOS, iOS and visionOS. Builds are signed ad-hoc; set `DEVELOPMENT_TEAM` in `project.yml` to run on a device.

`scripts/check-shaders.sh` compiles and links every demo shader without building the app.

For screen recordings, `-tour` steps through demos by itself and sweeps each one's first slider:

```sh
open LygiaViewer.app --args -tour kaleidoscopeNoise,islamicStar,mandala,gallery -tourInterval 3.5
```

## LYGIA version

`External/lygia` is a submodule on the `metal/port-missing` branch of [elkraneo/lygia](https://github.com/elkraneo/lygia). That branch contains the Metal fixes and ports proposed upstream in [#318](https://github.com/patriciogonzalezvivo/lygia/pull/318) and [#319](https://github.com/patriciogonzalezvivo/lygia/pull/319). Several demos (star, flower and gear SDFs, kaleidoscope, triTile, ...) don't compile against upstream `main` until those land.

To build against another checkout, create `Config/Local.xcconfig` (git-ignored):

```
LYGIA_SOURCE_ROOT = /path/to/folder/containing/lygia
```

## Adding a demo

1. Add `LygiaViewer/Shaders/<Module>/<id>.metal` with one `[[ stitchable ]]` function named `<id>`, using the signature documented in `Shaders/Common.h`.
2. Add a `Demo(...)` entry in `LygiaViewer/Model/DemoCatalog.swift`.

Wrap LYGIA includes in `LYGIA_BEGIN` / `LYGIA_END`. LYGIA's Metal functions aren't `inline` yet, so two `.metal` files that include the same LYGIA file would otherwise fail to link with duplicate symbols.

## Notes

- On visionOS, SwiftUI shaders work in windows and volumes. RealityKit materials on visionOS don't accept custom Metal shaders (they use Shader Graph).
- The macOS app isn't sandboxed, so the Playground can read LYGIA from disk.

## License

The viewer's code is MIT licensed (see [LICENSE](LICENSE)). LYGIA has its own license: it's free for non-commercial use under the [Prosperity License](https://prosperitylicense.com/versions/3.0.0), and commercial use needs the [Patron License](https://lygia.xyz/license).
