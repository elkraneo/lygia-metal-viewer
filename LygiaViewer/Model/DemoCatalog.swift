import Foundation

/// All gallery demos. Parameter order must match `params.x/y/z/w` in the shader.
enum DemoCatalog {
    static let all: [Demo] = generative + sdf + space + color + draw + distort + lighting + ornament

    static func demo(id: String) -> Demo? { all.first { $0.id == id } }

    static func demos(in module: DemoModule) -> [Demo] { all.filter { $0.module == module } }

    // MARK: Generative

    static let generative: [Demo] = [
        Demo(id: "fbmClouds", title: "Domain-warped fBm", module: .generative,
             summary: "fbm() fed back into itself: fbm(p + warp * fbm(p)).",
             params: [.slider("Scale", 0.5...10, 3), .speed("Speed", 0...2, 0.25), .slider("Warp", 0...4, 1.5)]),
        Demo(id: "noiseTypes", title: "Noise types", module: .generative,
             summary: "Simplex, classic Perlin, gradient, periodic Perlin and psrdnoise, animated along z.",
             params: [.picker("Noise", ["snoise", "cnoise", "gnoise", "pnoise", "psrdnoise"]),
                      .slider("Scale", 1...20, 5), .speed("Speed", 0...2, 0.4)]),
        Demo(id: "voronoiCells", title: "Voronoi", module: .generative,
             summary: "voronoi(p, time) returns the closest cell point and its distance; the point doubles as a cell id.",
             params: [.slider("Scale", 1...20, 6), .speed("Speed", 0...3, 1), .toggle("Distance shading", true)]),
        Demo(id: "worleyCells", title: "Worley", module: .generative,
             summary: "worley(float3) cellular noise: 1 - distance to the closest feature point.",
             params: [.slider("Scale", 1...20, 6), .speed("Speed", 0...2, 0.5), .toggle("Invert", false), .slider("Sharpness", 0.3...6, 2)]),
        Demo(id: "voronoiseMorph", title: "Voronoise", module: .generative,
             summary: "voronoise(p, u, v) morphs between grid noise, cells and value noise.",
             params: [.slider("Scale", 1...30, 8), .slider("Jitter (u)", 0...1, 1), .slider("Smoothness (v)", 0...1, 0)]),
        Demo(id: "curlFlow", title: "Curl noise", module: .generative,
             summary: "curl(float3) gives a divergence-free vector field, shown as color with flow streaks.",
             params: [.slider("Scale", 0.5...8, 2), .speed("Speed", 0...1, 0.15), .slider("Streaks", 1...20, 8)]),
        Demo(id: "psrdnoiseFlow", title: "psrdnoise flow", module: .generative,
             summary: "Tiling simplex noise with rotating gradients and an analytic gradient used for lighting.",
             params: [.slider("Scale", 1...16, 5), .speed("Rotation", 0...4, 1), .int("Period", 0...16, 0)]),
        Demo(id: "randomGrid", title: "Random", module: .generative,
             summary: "Hash functions random / random2 / random3 per pixel or per cell.",
             params: [.picker("Mode", ["White noise", "Per cell", "random3 per cell"], 2), .int("Cells", 2...64, 12), .speed("Reseed / s", 0...12, 1)]),
    ]

    // MARK: SDF

    static let sdf: [Demo] = [
        Demo(id: "sdfShapes", title: "2D shapes", module: .sdf,
             summary: "LYGIA's 2D shape fields drawn with fill() / stroke(), or as a field with iso-lines.",
             params: [.picker("Shape", ["circle", "rect", "star", "poly", "flower", "gear", "heart", "hex", "tri", "vesica", "rhomb", "cross"], 2),
                      .int("Sides / points", 3...16, 5), .slider("Size", 0.1...1.2, 0.6), .picker("Mode", ["Fill", "Stroke", "Field"], 2)]),
        Demo(id: "kochSnowflake", title: "Koch snowflake", module: .sdf,
             summary: "kochSDF(st, iterations): a true signed distance, drawn with distance bands.",
             params: [.int("Iterations", 0...7, 4), .speed("Rotation", -1...1, 0.1), .slider("Bands", 4...80, 40)]),
        Demo(id: "superShape", title: "Supershape", module: .sdf,
             summary: "superShapeSDF: the Gielis superformula (symmetry m, exponents n1 n2 n3).",
             params: [.slider("m", 0...20, 5), .slider("n1", 0.1...10, 0.35), .slider("n2", 0.1...10, 0.5), .slider("n3", 0.1...10, 0.5)]),
        Demo(id: "juliaSet", title: "Julia set", module: .sdf,
             summary: "juliaSDF(st, c, r) with c orbiting a circle.",
             params: [.slider("Zoom (r)", 0.5...3, 1.5), .speed("Speed", 0...1, 0.15), .slider("Orbit", 0.3...1, 0.7885)]),
        Demo(id: "sdfBooleans", title: "Smooth booleans", module: .sdf,
             summary: "opUnion / opSubtraction / opIntersection with smoothness k, plus opOnion.",
             params: [.picker("Operator", ["Union", "Subtraction", "Intersection"]), .slider("Smoothness k", 0...0.3, 0.08), .slider("Onion", 0...0.1, 0)]),
        Demo(id: "spiralRays", title: "Spiral x rays", module: .sdf,
             summary: "spiralSDF and raysSDF combined with XOR, a PixelSpirit-style card.",
             params: [.slider("Turns", 0.5...6, 2), .int("Rays", 2...40, 12), .speed("Speed", 0...2, 0.3)]),
    ]

    // MARK: Space

    static let space: [Demo] = [
        Demo(id: "squareTiles", title: "Square tilings", module: .space,
             summary: "sqTile, mirrorTile, brickTile and windmillTile; each returns float4(local uv, tile id).",
             params: [.picker("Tiling", ["sqTile", "mirrorTile", "brickTile", "windmillTile"], 1), .slider("Scale", 1...16, 5), .toggle("checkerTile overlay", true)]),
        Demo(id: "hexTiles", title: "Hex tiles", module: .space,
             summary: "hexTile() with a ripple driven by the hex id.",
             params: [.slider("Scale", 2...30, 10), .speed("Speed", 0...5, 2), .slider("Line width", 0.01...0.2, 0.06)]),
        Demo(id: "triTiles", title: "Triangle tiles", module: .space,
             summary: "triTile() splits the plane into equilateral triangles.",
             params: [.slider("Scale", 2...30, 8), .speed("Speed", 0...5, 1.5), .slider("Line width", 0.01...0.2, 0.05)]),
        Demo(id: "kaleidoscopeNoise", title: "Kaleidoscope", module: .space,
             summary: "kaleidoscope(st, segments, phase) folds fbm noise into mirrored wedges.",
             params: [.int("Segments", 2...24, 8), .speed("Phase speed", -1...1, 0.2), .slider("Noise scale", 1...12, 4)]),
        Demo(id: "polarWarp", title: "Polar warp", module: .space,
             summary: "cart2polar + rotate + scale turn a checkerTile into a twisting polar tunnel.",
             params: [.int("Angular cells", 2...40, 16), .slider("Radial cells", 1...20, 6), .slider("Twist", -2...2, 0.5), .slider("Zoom", 0.25...4, 1)]),
    ]

    // MARK: Color

    static let color: [Demo] = [
        Demo(id: "blendModes", title: "Blend modes", module: .color,
             summary: "color/blend/*: base (top strip) blended with an animated layer (bottom strip).",
             params: [.picker("Mode", ["multiply", "screen", "overlay", "softLight", "hardLight", "colorDodge", "colorBurn",
                                       "difference", "exclusion", "linearLight", "hue", "color", "luminosity"], 2),
                      .slider("Opacity", 0...1, 1)]),
        Demo(id: "mixColorSpaces", title: "Color mixing", module: .color,
             summary: "Rows: mix (sRGB), mixOklab, mixSpectral (pigment-like), mixRYB.",
             params: [.picker("Colors", ["Blue / yellow", "Red / green", "Magenta / cyan", "Black / white"]), .slider("Gap", 0...0.2, 0.04)]),
        Demo(id: "colorSpaces", title: "Color spaces", module: .color,
             summary: "color/space/* conversions: Oklab plane, HSV wheel, CIE LCh wheel, blackbody Kelvin.",
             params: [.picker("Space", ["Oklab a/b", "HSV", "LCh", "Kelvin (k2rgb)"]), .slider("Lightness", 0...1, 0.75)]),
        Demo(id: "tonemaps", title: "Tonemapping", module: .color,
             summary: "Rows: linear, Reinhard, Reinhard-Jodie, ACES, filmic, Uncharted 2, Unreal on an HDR ramp.",
             params: [.slider("Max intensity", 1...32, 8), .slider("Saturation", 0...1, 0.8)]),
        Demo(id: "spectralPalettes", title: "Spectral palettes", module: .color,
             summary: "Rows: spectral, spectral_gems, _geoffrey, _soft, _zucconi, _zucconi6.",
             params: [.speed("Scroll", -0.5...0.5, 0), .slider("Repeats", 1...4, 1)]),
        Demo(id: "ditherLevels", title: "Dithering", module: .color,
             summary: "Quantize a gradient to N levels; dithering (explicit pixel coords) hides the banding.",
             params: [.picker("Dither", ["none", "bayer", "interleavedGradientNoise", "triangleNoise", "vlachos", "shift"], 1),
                      .int("Levels", 2...32, 4), .int("Pixel size", 1...8, 3)]),
        Demo(id: "hueShiftLayer", title: "Hue shift (layer)", module: .color, kind: .layer,
             summary: "layerEffect on regular SwiftUI content: hueShift() and desaturate().",
             params: [.slider("Hue (turns)", 0...1, 0), .speed("Spin", 0...1, 0.1), .slider("Desaturate", 0...1, 0)]),
    ]

    // MARK: Draw

    static let draw: [Demo] = [
        Demo(id: "drawPrimitives", title: "Primitives", module: .draw,
             summary: "draw/circle, rect, hex, tri: fill(sdf, size) or stroke(sdf, size, width).",
             params: [.slider("Size", 0.1...1.2, 0.6), .slider("Stroke width", 0.01...0.3, 0.08),
                      .picker("Mode", ["Fill", "Stroke", "Both"], 2), .speed("Spin", -2...2, 0.3)]),
    ]

    // MARK: Distort

    static let distort: [Demo] = [
        Demo(id: "barrelLens", title: "Barrel", module: .distort, kind: .distortion,
             summary: "distortionEffect with barrel(uv, amount) on SwiftUI content.",
             params: [.slider("Amount", -1...2, 0.6), .slider("Wobble", 0...1, 0.2)]),
        Demo(id: "pincushionLens", title: "Pincushion", module: .distort, kind: .distortion,
             summary: "distortionEffect with pincushion(st, resolution, amount).",
             params: [.slider("Amount", -1...1, 0.3), .slider("Wobble", 0...0.5, 0.1)]),
        Demo(id: "chromaticAberration", title: "Chromatic aberration", module: .distort, kind: .layer,
             summary: "chromaAB() sampling a SwiftUI layer through a SAMPLER_TYPE / SAMPLER_FNC override.",
             params: [.slider("Strength", 0...0.1, 0.03), .slider("Pulse", 0...1, 0.5)]),
        Demo(id: "motionStretch", title: "Stretch (motion blur)", module: .distort, kind: .layer,
             summary: "stretch(tex, st, direction) averages STRETCH_SAMPLES samples along a direction.",
             params: [.slider("Length", 0...0.3, 0.08), .slider("Angle (turns)", 0...1, 0), .speed("Rotate", 0...0.5, 0.1)]),
        Demo(id: "filmGrain", title: "Film grain", module: .distort, kind: .layer,
             summary: "grain(tex, st, resolution, time, size): noise blended with soft light.",
             params: [.slider("Grain size", 0.5...8, 2.5), .toggle("Animate", true), .slider("Darken", 0...0.8, 0.3)]),
    ]

    // MARK: Ornaments

    // MARK: Lighting

    static let lighting: [Demo] = [
        Demo(id: "pbrSpheres", title: "PBR materials", module: .lighting,
             summary: "LYGIA pbr step by step: roughness across, metallic down, lit by a LightDirectional built at runtime and fakeCube.",
             params: [.speed("Sun speed", 0...2, 0.5), .slider("Albedo hue", 0...1, 0.6), .slider("Exposure", 0.2...3, 1)]),
        Demo(id: "raymarchScene", title: "Raymarched scene", module: .lighting,
             summary: "raymarch() over a raymarchMap() scene, shaded with pbr, soft shadows and ambient occlusion.",
             params: [.speed("Orbit speed", 0...1, 0.15), .slider("Distance", 4...10, 6), .slider("Height", -0.5...4, 2), .slider("Exposure", 0.2...3, 0.55)]),
    ]

    static let ornament: [Demo] = [
        Demo(id: "hexRosette", title: "Hex rosettes", module: .ornament,
             summary: "hexTile + flowerSDF + starSDF + hexSDF, counter-rotating per ring.",
             params: [.slider("Scale", 1...12, 4), .speed("Rotation", -1...1, 0.2), .int("Petals", 3...12, 6), .slider("Line width", 0.01...0.1, 0.035)]),
        Demo(id: "islamicStar", title: "Khatam stars", module: .ornament,
             summary: "sqTile + rectSDF + rotate: the 8-point star from two squares, interlaced bands.",
             params: [.slider("Scale", 1...12, 3), .slider("Square size", 0.3...1, 0.62), .slider("Breathing", 0...1, 0.5), .slider("Line width", 0.02...0.2, 0.09)]),
        Demo(id: "mandala", title: "Mandala", module: .ornament,
             summary: "kaleidoscope + circleSDF, vesicaSDF, polySDF, gearSDF, flowerSDF and spectral color.",
             params: [.int("Segments", 3...24, 12), .speed("Rotation", -1...1, 0.1), .slider("Line width", 0.005...0.05, 0.015), .speed("Color speed", 0...0.5, 0.05)]),
        Demo(id: "truchetWeave", title: "Truchet weave", module: .ornament,
             summary: "sqTile + random: Smith truchet arcs weaving continuous paths.",
             params: [.slider("Scale", 2...30, 10), .speed("Reshuffle / s", 0...4, 0.5), .slider("Line width", 0.02...0.4, 0.16), .toggle("Checker tint", true)]),
        Demo(id: "windmillPinwheel", title: "Pinwheel", module: .ornament,
             summary: "windmillTile rotates tiles 0/90/180/270 degrees around each 2x2 block.",
             params: [.slider("Scale", 1...16, 6), .slider("Turn", 0...1, 1), .slider("Line width", 0.01...0.12, 0.04)]),
        Demo(id: "vesicaLattice", title: "Vesica lattice", module: .ornament,
             summary: "mirrorTile + vesicaSDF crossed at 90 degrees: a quatrefoil lattice.",
             params: [.slider("Scale", 1...16, 4), .slider("Vesica width", 0.1...1, 0.5), .slider("Line width", 0.01...0.12, 0.04), .speed("Shimmer", 0...4, 1)]),
    ]
}
