import SwiftUI

/// LYGIA modules as shown in the sidebar.
enum DemoModule: String, CaseIterable, Identifiable {
    case generative = "Generative"
    case sdf = "SDF"
    case space = "Space / Tiling"
    case color = "Color"
    case draw = "Draw"
    case distort = "Distort"
    case lighting = "Lighting"
    case ornament = "Ornaments"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .generative: "cloud.fog"
        case .sdf: "star.circle"
        case .space: "square.grid.3x3"
        case .color: "paintpalette"
        case .draw: "pencil.and.outline"
        case .distort: "camera.filters"
        case .lighting: "lightbulb"
        case .ornament: "seal"
        }
    }
}

/// Which SwiftUI shader modifier runs the demo. The Metal signature differs:
///   color:      half4  f(float2 position, half4 color,          float2 size, float time, float4 params)
///   layer:      half4  f(float2 position, SwiftUI::Layer layer, float2 size, float time, float4 params)
///   distortion: float2 f(float2 position,                       float2 size, float time, float4 params)
enum EffectKind: String {
    case color = "colorEffect"
    case layer = "layerEffect"
    case distortion = "distortionEffect"
}

/// One UI control, mapped to one component of the shader's `float4 params`.
struct DemoParam: Identifiable {
    enum Control {
        case slider(ClosedRange<Float>, step: Float? = nil)
        case picker([String])
        case toggle
    }

    let name: String
    let control: Control
    let defaultValue: Float

    var id: String { name }

    static func slider(_ name: String, _ range: ClosedRange<Float>, _ value: Float, step: Float? = nil) -> DemoParam {
        DemoParam(name: name, control: .slider(range, step: step), defaultValue: value)
    }

    static func int(_ name: String, _ range: ClosedRange<Float>, _ value: Float) -> DemoParam {
        DemoParam(name: name, control: .slider(range, step: 1), defaultValue: value)
    }

    static func picker(_ name: String, _ options: [String], _ value: Int = 0) -> DemoParam {
        DemoParam(name: name, control: .picker(options), defaultValue: Float(value))
    }

    static func toggle(_ name: String, _ on: Bool) -> DemoParam {
        DemoParam(name: name, control: .toggle, defaultValue: on ? 1 : 0)
    }
}

/// A gallery entry. `id` is both the `[[ stitchable ]]` function name and the
/// .metal file name under Shaders/<Module>/, so adding a demo is:
///   1. add `Shaders/<Module>/<id>.metal` with one stitchable function `<id>`
///   2. add one `Demo(...)` entry to `DemoCatalog.all`
struct Demo: Identifiable, Hashable {
    let id: String
    let title: String
    let module: DemoModule
    var kind: EffectKind = .color
    let summary: String
    /// Up to four parameters -> params.x, .y, .z, .w
    var params: [DemoParam] = []

    static func == (lhs: Demo, rhs: Demo) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    var defaultValues: SIMD4<Float> {
        var v = SIMD4<Float>(repeating: 0)
        for (i, p) in params.prefix(4).enumerated() { v[i] = p.defaultValue }
        return v
    }
}
