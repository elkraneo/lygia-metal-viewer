#if os(macOS)
import MetalKit
import SwiftUI

/// Compiles playground snippets at runtime and draws them full screen in an MTKView.
///
/// The user's snippet defines
///     float4 mainImage(float2 fragCoord, float2 resolution, float time)
/// (fragCoord in pixels, origin bottom-left). The renderer adds the Metal
/// prelude, flattens LYGIA includes and appends the vertex/fragment entry points.
@Observable
final class PlaygroundRenderer: NSObject {
    enum Status: Equatable {
        case idle
        case compiling
        case ok(files: Int, milliseconds: Int)
        case failed(String)
    }

    private(set) var status: Status = .idle
    private(set) var flattenedSource = ""
    var paused = false

    @ObservationIgnored let device: MTLDevice? = MTLCreateSystemDefaultDevice()
    @ObservationIgnored private lazy var queue = device?.makeCommandQueue()
    @ObservationIgnored private var pipeline: MTLRenderPipelineState?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private let start = CACurrentMediaTime()
    @ObservationIgnored private var pauseBegan: Double?
    @ObservationIgnored private var pausedDuration: Double = 0
    @ObservationIgnored var pixelFormat: MTLPixelFormat = .bgra8Unorm

    static let prelude = """
    #include <metal_stdlib>
    using namespace metal;
    """

    static let postlude = """
    struct PlaygroundVertexOut { float4 position [[position]]; };
    struct PlaygroundUniforms { float2 resolution; float time; float pad; };

    vertex PlaygroundVertexOut playground_vertex(uint vid [[vertex_id]]) {
        float2 p = float2((vid << 1) & 2, vid & 2);          // full-screen triangle
        PlaygroundVertexOut out;
        out.position = float4(p * 2.0 - 1.0, 0.0, 1.0);
        return out;
    }

    fragment float4 playground_fragment(PlaygroundVertexOut in [[stage_in]],
                                        constant PlaygroundUniforms &u [[buffer(0)]]) {
        float2 fragCoord = float2(in.position.x, u.resolution.y - in.position.y);
        return mainImage(fragCoord, u.resolution, u.time);
    }
    """

    /// Flatten + compile. Runs the Metal compiler off the main thread; stale
    /// results (from older keystrokes) are dropped.
    func compile(_ snippet: String, lygiaRoot: URL) {
        guard let device else {
            status = .failed("No Metal device")
            return
        }
        generation += 1
        let current = generation
        status = .compiling

        var flattener = IncludeFlattener(searchRoots: [lygiaRoot])
        let body: String
        do {
            body = try flattener.flatten(snippet)
        } catch {
            status = .failed(error.localizedDescription)
            return
        }
        let files = flattener.includedFiles.count
        let source = Self.prelude + "\n" + body + "\n#line 1 \"playground-postlude\"\n" + Self.postlude
        flattenedSource = source
        let format = pixelFormat
        let began = CACurrentMediaTime()

        Task.detached(priority: .userInitiated) { [weak self] in
            let result: Result<MTLRenderPipelineState, Error>
            do {
                let library = try await device.makeLibrary(source: source, options: nil)
                let descriptor = MTLRenderPipelineDescriptor()
                descriptor.vertexFunction = library.makeFunction(name: "playground_vertex")
                descriptor.fragmentFunction = library.makeFunction(name: "playground_fragment")
                descriptor.colorAttachments[0].pixelFormat = format
                result = .success(try await device.makeRenderPipelineState(descriptor: descriptor))
            } catch {
                result = .failure(error)
            }
            let elapsed = Int((CACurrentMediaTime() - began) * 1000)
            await MainActor.run { [weak self] in
                guard let self, current == self.generation else { return }
                switch result {
                case .success(let state):
                    self.pipeline = state
                    self.status = .ok(files: files, milliseconds: elapsed)
                case .failure(let error):
                    self.status = .failed(Self.cleanMessage(error))
                }
            }
        }
    }

    private nonisolated static func cleanMessage(_ error: Error) -> String {
        let text = (error as NSError).localizedDescription
        // Keep diagnostics, drop the "Compilation failed:" wrapper noise.
        return text.replacingOccurrences(of: "Compilation failed: \n\n", with: "")
    }

    func togglePause() {
        let now = CACurrentMediaTime()
        if let began = pauseBegan {
            pausedDuration += now - began
            pauseBegan = nil
            paused = false
        } else {
            pauseBegan = now
            paused = true
        }
    }

    private var currentTime: Double { (pauseBegan ?? CACurrentMediaTime()) - start - pausedDuration }

    fileprivate func draw(in view: MTKView) {
        guard let pipeline, let queue,
              let pass = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let commands = queue.makeCommandBuffer(),
              let encoder = commands.makeRenderCommandEncoder(descriptor: pass) else { return }

        var uniforms = (SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height)),
                        Float(currentTime), Float(0))
        encoder.setRenderPipelineState(pipeline)
        withUnsafeBytes(of: &uniforms) { raw in
            encoder.setFragmentBytes(raw.baseAddress!, length: raw.count, index: 0)
        }
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        commands.present(drawable)
        commands.commit()
    }
}

/// SwiftUI wrapper around the MTKView.
struct PlaygroundMetalView: NSViewRepresentable {
    let renderer: PlaygroundRenderer

    func makeCoordinator() -> Coordinator { Coordinator(renderer: renderer) }

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: renderer.device)
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        view.preferredFramesPerSecond = 60
        view.delegate = context.coordinator
        renderer.pixelFormat = view.colorPixelFormat
        return view
    }

    func updateNSView(_ view: MTKView, context: Context) {}

    final class Coordinator: NSObject, MTKViewDelegate {
        let renderer: PlaygroundRenderer
        init(renderer: PlaygroundRenderer) { self.renderer = renderer }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            renderer.draw(in: view)
        }
    }
}
#endif
