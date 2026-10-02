#if os(macOS)
import Lygia
import Metal
import SwiftUI

/// One LYGIA checkout the Compare view can compile against.
struct LygiaVariant: Identifiable, Hashable {
    let id: String
    let title: String
    /// Folder that contains `lygia/`.
    let root: URL
}

/// Renders one snippet with each LYGIA variant into offscreen textures and
/// measures how much the images differ. The snippet defines
///     float4 mainImage(float2 fragCoord, float2 resolution, float time)
/// as in the Playground; here time is a fixed value so the frames line up.
@Observable
final class CompareRenderer {
    enum Outcome: Equatable {
        case compiling
        case rendered(CGImage)
        case failed(String)

        static func == (lhs: Outcome, rhs: Outcome) -> Bool {
            switch (lhs, rhs) {
            case (.compiling, .compiling): true
            case let (.rendered(a), .rendered(b)): a === b
            case let (.failed(a), .failed(b)): a == b
            default: false
            }
        }
    }

    struct Difference: Equatable {
        /// Largest channel difference, 0...1.
        let max: Float
        /// Mean channel difference, 0...1.
        let mean: Float
        /// Share of pixels where any channel differs by more than 2/255.
        let changed: Float
        let heatmap: CGImage

        static func == (lhs: Difference, rhs: Difference) -> Bool {
            lhs.max == rhs.max && lhs.mean == rhs.mean && lhs.changed == rhs.changed
        }
    }

    nonisolated static let size = 384

    private(set) var outcomes: [String: Outcome] = [:]
    private(set) var difference: Difference?

    @ObservationIgnored private let device = MTLCreateSystemDefaultDevice()
    @ObservationIgnored private lazy var queue = device?.makeCommandQueue()
    @ObservationIgnored private var generation = 0

    func render(_ snippet: String, time: Float, variants: [LygiaVariant]) {
        generation += 1
        let current = generation
        difference = nil
        for v in variants { outcomes[v.id] = .compiling }
        guard let device, let queue else {
            for v in variants { outcomes[v.id] = .failed("No Metal device") }
            return
        }

        // Flatten against each root on the main thread (cheap, reads small files).
        var sources: [(LygiaVariant, Result<String, Error>)] = []
        for v in variants {
            var flattener = IncludeFlattener(searchRoots: [v.root])
            do {
                let body = try flattener.flatten(snippet, name: "compare.metal")
                sources.append((v, .success(PlaygroundRenderer.prelude + "\n" + body + "\n#line 1 \"compare-postlude\"\n" + Self.postlude)))
            } catch {
                sources.append((v, .failure(error)))
            }
        }

        Task.detached(priority: .userInitiated) { [weak self] in
            var pixels: [String: [UInt8]] = [:]
            var results: [String: Outcome] = [:]
            for (v, source) in sources {
                switch source {
                case .failure(let error):
                    results[v.id] = .failed(error.localizedDescription)
                case .success(let text):
                    do {
                        let bytes = try await Self.draw(text, time: time, device: device, queue: queue)
                        pixels[v.id] = bytes
                        results[v.id] = .rendered(Self.image(from: bytes))
                    } catch {
                        results[v.id] = .failed(PlaygroundRenderer.cleanMessage(error))
                    }
                }
            }
            let diff: Difference? = variants.count == 2 ? Self.compare(pixels[variants[0].id], pixels[variants[1].id]) : nil
            await MainActor.run { [weak self] in
                guard let self, current == self.generation else { return }
                for (id, outcome) in results { self.outcomes[id] = outcome }
                self.difference = diff
            }
        }
    }

    // MARK: - Metal

    struct RenderFailure: LocalizedError {
        let message: String
        init(_ message: String) { self.message = message }
        var errorDescription: String? { message }
    }

    static let postlude = """
    struct CompareVertexOut { float4 position [[position]]; };
    struct CompareUniforms { float2 resolution; float time; float pad; };

    vertex CompareVertexOut compare_vertex(uint vid [[vertex_id]]) {
        float2 p = float2((vid << 1) & 2, vid & 2);
        CompareVertexOut out;
        out.position = float4(p * 2.0 - 1.0, 0.0, 1.0);
        return out;
    }

    fragment float4 compare_fragment(CompareVertexOut in [[stage_in]],
                                     constant CompareUniforms &u [[buffer(0)]]) {
        float2 fragCoord = float2(in.position.x, u.resolution.y - in.position.y);
        return mainImage(fragCoord, u.resolution, u.time);
    }
    """

    private nonisolated static func draw(_ source: String, time: Float, device: MTLDevice, queue: MTLCommandQueue) async throws -> [UInt8] {
        let library = try await device.makeLibrary(source: source, options: nil)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "compare_vertex")
        descriptor.fragmentFunction = library.makeFunction(name: "compare_fragment")
        descriptor.colorAttachments[0].pixelFormat = .rgba8Unorm
        let pipeline = try await device.makeRenderPipelineState(descriptor: descriptor)

        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: size, height: size, mipmapped: false)
        textureDescriptor.usage = [.renderTarget]
        textureDescriptor.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            throw RenderFailure( "Couldn't create the render target")
        }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        guard let commands = queue.makeCommandBuffer(), let encoder = commands.makeRenderCommandEncoder(descriptor: pass) else {
            throw RenderFailure( "Couldn't encode the render pass")
        }
        var uniforms = (SIMD2<Float>(Float(size), Float(size)), time, Float(0))
        encoder.setRenderPipelineState(pipeline)
        withUnsafeBytes(of: &uniforms) { encoder.setFragmentBytes($0.baseAddress!, length: $0.count, index: 0) }
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        commands.commit()
        await commands.completed()
        if let error = commands.error { throw error }

        var bytes = [UInt8](repeating: 0, count: size * size * 4)
        texture.getBytes(&bytes, bytesPerRow: size * 4, from: MTLRegionMake2D(0, 0, size, size), mipmapLevel: 0)
        return bytes
    }

    // MARK: - Images

    private nonisolated static func image(from bytes: [UInt8]) -> CGImage {
        var copy = bytes
        let context = CGContext(data: &copy, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        return context.makeImage()!
    }

    /// Per-pixel difference as a heatmap: black where equal, through yellow to
    /// white where a channel differs fully.
    private nonisolated static func compare(_ a: [UInt8]?, _ b: [UInt8]?) -> Difference? {
        guard let a, let b, a.count == b.count else { return nil }
        var heat = [UInt8](repeating: 255, count: a.count)
        var maxDiff = 0, sum = 0, changed = 0
        for p in stride(from: 0, to: a.count, by: 4) {
            var d = 0
            for c in 0..<3 { d = Swift.max(d, abs(Int(a[p + c]) - Int(b[p + c]))) }
            maxDiff = Swift.max(maxDiff, d)
            sum += d
            if d > 2 { changed += 1 }
            // Ramp: black -> yellow (d 0...128) -> white (128...255).
            let t = Double(d) / 255.0
            heat[p] = UInt8(min(255, t * 2 * 255))
            heat[p + 1] = UInt8(min(255, t * 2 * 255))
            heat[p + 2] = UInt8(max(0, (t - 0.5) * 2 * 255))
        }
        let pixels = a.count / 4
        return Difference(max: Float(maxDiff) / 255, mean: Float(sum) / Float(pixels * 255),
                          changed: Float(changed) / Float(pixels), heatmap: image(from: heat))
    }
}
#endif
