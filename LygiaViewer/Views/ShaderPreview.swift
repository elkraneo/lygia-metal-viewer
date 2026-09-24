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

    var body: some View {
        TimelineView(.animation(paused: paused)) { context in
            let time = Float(context.date.timeIntervalSince(ShaderClock.start))
            GeometryReader { proxy in
                ShaderSurface(demo: demo, values: values, size: proxy.size, time: time)
            }
        }
        .clipped()
    }
}

struct ShaderSurface: View {
    let demo: Demo
    let values: SIMD4<Float>
    let size: CGSize
    let time: Float

    var body: some View {
        let shader = Shader(
            function: ShaderFunction(library: .default, name: demo.id),
            arguments: [
                .float2(Float(size.width), Float(size.height)),
                .float(time),
                .float4(values.x, values.y, values.z, values.w),
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
        let v = defaultValues
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
