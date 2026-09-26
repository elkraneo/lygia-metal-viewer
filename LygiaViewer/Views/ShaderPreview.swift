import SwiftUI

/// Shared time origin so every preview animates in sync.
enum ShaderClock {
    static let start = Date()
}

/// Live preview of a demo: drives `time` with a TimelineView and applies the
/// demo's stitchable function with the matching SwiftUI shader modifier.
struct ShaderPreview: View {
    let demo: Demo
    var values: SIMD4<Float>
    var paused: Bool = false
    @State private var integrator = SpeedIntegrator()

    var body: some View {
        TimelineView(.animation(paused: paused)) { context in
            let time = Float(context.date.timeIntervalSince(ShaderClock.start))
            let arguments = integrator.advance(demo: demo, values: values, date: context.date, time: time)
            GeometryReader { proxy in
                ShaderSurface(demo: demo, arguments: arguments, size: proxy.size, time: time)
            }
        }
        .clipped()
    }
}

/// Accumulates a demo's speed sliders frame by frame, so moving a speed slider
/// changes the rate from then on. Multiplying by `time` instead would rescale
/// everything accumulated since launch and make the image jump.
final class SpeedIntegrator {
    private var demoID: String?
    private var accumulated = SIMD4<Float>(repeating: 0)
    private var last: Date?

    func advance(demo: Demo, values: SIMD4<Float>, date: Date, time: Float) -> SIMD4<Float> {
        if let last, demoID == demo.id {
            // Clamped, so resuming after a pause doesn't jump.
            accumulated += values * Float(min(max(date.timeIntervalSince(last), 0), 0.1))
        } else {
            // Start where constant speeds would be, so previews stay in sync.
            demoID = demo.id
            accumulated = values * time
        }
        last = date
        return values.replacing(with: accumulated, where: demo.speeds)
    }
}

/// Draws a demo with the given shader `params` (speeds already accumulated).
struct ShaderSurface: View {
    let demo: Demo
    let arguments: SIMD4<Float>
    let size: CGSize
    let time: Float

    var body: some View {
        let shader = Shader(
            function: ShaderFunction(library: .default, name: demo.id),
            arguments: [
                .float2(Float(size.width), Float(size.height)),
                .float(time),
                .float4(arguments.x, arguments.y, arguments.z, arguments.w),
            ]
        )
        switch demo.kind {
        case .color:
            Rectangle()
                .fill(.black)
                .colorEffect(shader)
        case .layer:
            SampleContent()
                .layerEffect(shader, maxSampleOffset: CGSize(width: size.width * 0.5, height: size.height * 0.5))
        case .distortion:
            SampleContent()
                .distortionEffect(shader, maxSampleOffset: size)
        }
    }
}

extension Demo {
    /// Builds the shader with neutral arguments, e.g. for ahead-of-time validation.
    func makeShader(size: CGSize = CGSize(width: 256, height: 256), time: Float = 0) -> Shader {
        let v = arguments(defaultValues, time: time)
        return Shader(
            function: ShaderFunction(library: .default, name: id),
            arguments: [
                .float2(Float(size.width), Float(size.height)),
                .float(time),
                .float4(v.x, v.y, v.z, v.w),
            ]
        )
    }

    var usageType: Shader.UsageType {
        switch kind {
        case .color: .colorEffect
        case .layer: .layerEffect
        case .distortion: .distortionEffect
        }
    }
}
