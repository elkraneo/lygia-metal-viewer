#if os(visionOS)
import ARKit
import CompositorServices
import Metal
import os
import simd

/// Runs Compositor Services render-loop jobs on one dedicated, high-priority
/// thread, never on the main thread (see "Drawing fully immersive content using Metal").
nonisolated final class RendererTaskExecutor: TaskExecutor {
    static let shared = RendererTaskExecutor()
    private let queue = DispatchQueue(label: "io.210x7.LygiaViewer.render", qos: .userInteractive)

    func enqueue(_ job: UnownedJob) {
        queue.async {
            job.runSynchronously(on: self.asUnownedTaskExecutor())
        }
    }

    func asUnownedTaskExecutor() -> UnownedTaskExecutor {
        UnownedTaskExecutor(ordinary: self)
    }
}

/// Draws the raymarched LYGIA scene (Shaders/Immersive/ImmersiveScene.metal)
/// into a `LayerRenderer`, one full-screen triangle per eye.
///
/// - Layout: layered when available (one 2D-array texture, one slice per eye),
///   drawn in a single pass with vertex amplification. Dedicated and shared
///   layouts go through the same code: views are grouped by texture, one pass
///   per texture, and view mappings pick each eye's slice and viewport.
/// - Depth: reverse-Z (1 = near, 0 = far), written per pixel from the hit point.
/// - Foveation: on when the device supports it. The shader reconstructs rays
///   from an interpolated NDC varying instead of `[[position]]`, so
///   rasterization rate maps need no special handling.
nonisolated final class ImmersiveRenderer: @unchecked Sendable {
    static let logger = Logger(subsystem: "io.210x7.LygiaViewer", category: "Immersive")

    private let layerRenderer: LayerRenderer
    private let device: any MTLDevice
    private let commandQueue: any MTLCommandQueue
    private let pipeline: any MTLRenderPipelineState
    private let depthState: any MTLDepthStencilState
    private let arSession = ARKitSession()
    private let worldTracking = WorldTrackingProvider()
    private let onEnd: @Sendable () -> Void
    private var startTime: Double?
    /// Lifts the scene when the tracking origin sits at eye level (Simulator)
    /// instead of on the floor (device). See `sceneOffset(forHead:)`.
    private var sceneFromOrigin: simd_float4x4?

    /// Used when ARKit has no device anchor yet (standing eye height).
    private static let fallbackHead = simd_float4x4(translation: SIMD3<Float>(0, 1.5, 0))

    /// Called from the `CompositorLayer` closure. Moves the layer to the render thread.
    static func start(_ layerRenderer: LayerRenderer, onEnd: @escaping @Sendable () -> Void) {
        // The main actor hands the layer over and never touches it again.
        let layer = UncheckedSendable(value: layerRenderer)
        Task(executorPreference: RendererTaskExecutor.shared) {
            do {
                let renderer = try ImmersiveRenderer(layerRenderer: layer.value, onEnd: onEnd)
                await renderer.run()
            } catch {
                logger.error("Could not set up the immersive renderer: \(error.localizedDescription)")
                onEnd()
            }
        }
    }

    private init(layerRenderer: LayerRenderer, onEnd: @escaping @Sendable () -> Void) throws {
        self.layerRenderer = layerRenderer
        self.onEnd = onEnd
        device = layerRenderer.device
        guard let queue = device.makeCommandQueue() else { throw RendererError("No command queue") }
        commandQueue = queue

        let configuration = layerRenderer.configuration
        let viewCount = layerRenderer.properties.viewCount
        let viewsPerPass = configuration.layout == .dedicated ? 1 : viewCount
        guard device.supportsVertexAmplificationCount(viewsPerPass) else {
            throw RendererError("Vertex amplification x\(viewsPerPass) is not supported")
        }

        guard let library = device.makeDefaultLibrary() else { throw RendererError("No default Metal library") }
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "LYGIA immersive"
        descriptor.vertexFunction = library.makeFunction(name: "immersiveVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "immersiveFragment")
        descriptor.colorAttachments[0].pixelFormat = configuration.colorFormat
        descriptor.depthAttachmentPixelFormat = configuration.depthFormat
        descriptor.maxVertexAmplificationCount = viewsPerPass
        descriptor.inputPrimitiveTopology = .triangle
        pipeline = try device.makeRenderPipelineState(descriptor: descriptor)

        // Every pixel is written by the one full-screen triangle, so no depth test;
        // the depth texture only feeds the compositor's reprojection.
        let depth = MTLDepthStencilDescriptor()
        depth.depthCompareFunction = .always
        depth.isDepthWriteEnabled = true
        guard let depthState = device.makeDepthStencilState(descriptor: depth) else {
            throw RendererError("No depth state")
        }
        self.depthState = depthState

        Self.logger.notice("""
            Immersive renderer: layout \(String(describing: configuration.layout)), \
            foveation \(configuration.isFoveationEnabled), views \(viewCount), \
            color \(configuration.colorFormat.rawValue), depth \(configuration.depthFormat.rawValue), \
            depth range \(configuration.defaultDepthRange)
            """)
    }

    /// The scene is laid out with y = 0 on the floor. On device the immersive
    /// space origin is on the floor, so the head is ~1.6 m up and no offset is
    /// needed. Simulator reports the head at the origin; lift the scene then so
    /// the ornaments stay at eye height.
    private static func sceneOffset(forHead head: simd_float4x4) -> simd_float4x4 {
        let height = head.columns.3.y
        guard height < 0.8 else { return matrix_identity_float4x4 }
        return simd_float4x4(translation: SIMD3<Float>(0, 1.5 - height, 0))
    }

    // MARK: Render loop

    @concurrent func run() async {
        await startWorldTracking()

        var rendering = true
        while rendering {
            switch layerRenderer.state {
            case .paused:
                layerRenderer.waitUntilRunning()
            case .running:
                autoreleasepool { renderFrame() }
            case .invalidated:
                rendering = false
            @unknown default:
                rendering = false
            }
        }
        arSession.stop()
        Self.logger.info("Immersive renderer stopped")
        onEnd()
    }

    private func startWorldTracking() async {
        guard WorldTrackingProvider.isSupported else {
            Self.logger.notice("World tracking isn't supported here; using a fixed head pose")
            return
        }
        do {
            try await arSession.run([worldTracking])
        } catch {
            Self.logger.error("ARKit session failed: \(error.localizedDescription)")
        }
    }

    private func renderFrame() {
        guard let frame = layerRenderer.queryNextFrame(),
              let timing = frame.predictTiming() else { return }

        // Nothing to simulate on the CPU: the scene is animated in the shader.
        frame.startUpdate()
        frame.endUpdate()

        LayerRenderer.Clock().wait(until: timing.optimalInputTime)

        frame.startSubmission()
        let drawables: [LayerRenderer.Drawable]
        if #available(visionOS 26.0, *) {
            drawables = frame.queryDrawables()
        } else {
            drawables = frame.queryDrawable().map { [$0] } ?? []
        }
        guard !drawables.isEmpty else { return }
        for drawable in drawables {
            draw(drawable)
        }
        frame.endSubmission()
    }

    private func draw(_ drawable: LayerRenderer.Drawable) {
        let presentation = drawable.frameTiming.presentationTime.seconds
        if startTime == nil { startTime = presentation }

        // Head pose predicted for when the frame reaches the display. Handing it
        // back to the drawable lets the compositor correct for late motion.
        let anchor = worldTracking.queryDeviceAnchor(atTimestamp: presentation)
        drawable.deviceAnchor = anchor
        let originFromDevice = anchor?.originFromAnchorTransform ?? Self.fallbackHead
        if sceneFromOrigin == nil, anchor?.isTracked ?? false {
            sceneFromOrigin = Self.sceneOffset(forHead: originFromDevice)
        }

        let views = drawable.views
        var uniforms = ImmersiveFrameUniforms()
        uniforms.time = Float(presentation - (startTime ?? presentation))
        uniforms.viewCount = UInt32(min(views.count, 2))
        for (index, view) in views.prefix(2).enumerated() {
            // Reverse-Z projection built from this eye's tangents and the drawable's depth range.
            let projection = drawable.computeProjection(convention: .rightUpBack, viewIndex: index)
            let cameraToWorld = (sceneFromOrigin ?? matrix_identity_float4x4) * originFromDevice * view.transform
            uniforms[view: index] = ImmersiveViewUniforms(
                viewProjection: projection * cameraToWorld.inverse,
                inverseProjection: projection.inverse,
                cameraToWorld: cameraToWorld
            )
        }

        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        commandBuffer.label = "LYGIA immersive frame"

        // One pass per texture: layered/shared -> one pass with both eyes, dedicated -> two.
        let passes = Dictionary(grouping: views.indices.prefix(2), by: { views[$0].textureMap.textureIndex })
        for (textureIndex, viewIndices) in passes.sorted(by: { $0.key < $1.key }) {
            encodePass(textureIndex: textureIndex, viewIndices: viewIndices, drawable: drawable,
                       uniforms: &uniforms, commandBuffer: commandBuffer)
        }

        drawable.encodePresent(commandBuffer: commandBuffer)
        commandBuffer.commit()
    }

    private func encodePass(textureIndex: Int, viewIndices: [Int], drawable: LayerRenderer.Drawable,
                            uniforms: inout ImmersiveFrameUniforms, commandBuffer: any MTLCommandBuffer) {
        let color = drawable.colorTextures[textureIndex]
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = color
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        pass.colorAttachments[0].storeAction = .store
        pass.depthAttachment.texture = drawable.depthTextures[textureIndex]
        pass.depthAttachment.loadAction = .clear
        pass.depthAttachment.clearDepth = 0.0               // reverse-Z far plane
        pass.depthAttachment.storeAction = .store
        if color.textureType == .type2DArray {
            pass.renderTargetArrayLength = color.arrayLength
        }
        // Foveation: the rate map warps rasterization; [[position]] becomes physical
        // coordinates, but the NDC varying the shader uses stays correct.
        let rateMaps = drawable.rasterizationRateMaps
        if rateMaps.indices.contains(textureIndex) {
            pass.rasterizationRateMap = rateMaps[textureIndex]
        }

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else { return }
        encoder.label = "Eyes \(viewIndices)"
        encoder.setRenderPipelineState(pipeline)
        encoder.setDepthStencilState(depthState)
        encoder.setCullMode(.none)

        let views = drawable.views
        encoder.setViewports(viewIndices.map { views[$0].textureMap.viewport })
        var mappings = viewIndices.enumerated().map { slot, viewIndex in
            MTLVertexAmplificationViewMapping(
                viewportArrayIndexOffset: UInt32(slot),
                renderTargetArrayIndexOffset: UInt32(views[viewIndex].textureMap.sliceIndex)
            )
        }
        encoder.setVertexAmplificationCount(viewIndices.count, viewMappings: &mappings)

        var passViews = ImmersivePassViews()
        passViews.viewIndex = (UInt32(viewIndices[0]), UInt32(viewIndices.count > 1 ? viewIndices[1] : viewIndices[0]))
        encoder.setVertexBytes(&passViews, length: MemoryLayout<ImmersivePassViews>.stride, index: 1)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<ImmersiveFrameUniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
    }
}

nonisolated private struct UncheckedSendable<Value>: @unchecked Sendable {
    let value: Value
}

nonisolated private struct RendererError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}

nonisolated private extension LayerRenderer.Clock.Instant {
    /// Seconds on the same timeline ARKit uses for `queryDeviceAnchor(atTimestamp:)`.
    var seconds: TimeInterval {
        let components = LayerRenderer.Clock.Instant.epoch.duration(to: self).components
        return Double(components.seconds) + Double(components.attoseconds) * 1e-18
    }
}

nonisolated private extension simd_float4x4 {
    init(translation t: SIMD3<Float>) {
        self = matrix_identity_float4x4
        columns.3 = SIMD4<Float>(t, 1)
    }
}
#endif
