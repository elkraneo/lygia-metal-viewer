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
    @State private var clock = PreviewClock()

    var body: some View {
        TimelineView(.animation(paused: paused)) { context in
            let frame = clock.advance(demo: demo, values: values, date: context.date, paused: paused)
            GeometryReader { proxy in
                ShaderSurface(demo: demo, arguments: frame.arguments, size: proxy.size, time: frame.time)
            }
        }
        .clipped()
    }
}

/// A preview's own time, which stops while paused, and its speed sliders
/// accumulated frame by frame, so moving a speed slider changes the rate from
/// then on. Multiplying by `time` instead would rescale everything accumulated
/// since launch and make the image jump.
final class PreviewClock {
    private var demoID: String?
    private var time: Float = 0
    private var accumulated = SIMD4<Float>(repeating: 0)
    private var last: Date?

    func advance(demo: Demo, values: SIMD4<Float>, date: Date, paused: Bool) -> (time: Float, arguments: SIMD4<Float>) {
        if let last, demoID == demo.id {
            // Clamped, so a frame after a stall or a pause doesn't jump.
            let dt = paused ? 0 : Float(min(max(date.timeIntervalSince(last), 0), 0.1))
            time += dt
            accumulated += values * dt
        } else {
            // Start at the shared time with constant speeds, so previews stay in sync.
            demoID = demo.id
            time = Float(date.timeIntervalSince(ShaderClock.start))
            accumulated = values * time
        }
        last = date
        return (time, values.replacing(with: accumulated, where: demo.speeds))
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
