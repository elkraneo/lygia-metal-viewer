#if os(visionOS)
import CompositorServices
import SwiftUI

/// Fully immersive space drawn by our own Metal renderer (Compositor Services).
struct LygiaImmersiveSpace: Scene {
    static let id = "LygiaImmersive"
    let model: ImmersiveModel

    var body: some Scene {
        // No immersion style modifiers: a CompositorLayer space is always full.
        ImmersiveSpace(id: Self.id) {
            CompositorLayer(configuration: ImmersiveLayerConfiguration()) { layerRenderer in
                let model = model
                ImmersiveRenderer.start(layerRenderer) {
                    Task { @MainActor in model.rendererDidEnd() }
                }
            }
        }
    }
}

/// Layered layout (both eyes in one 2D-array texture, drawn with vertex
/// amplification) with foveation when the device supports them.
struct ImmersiveLayerConfiguration: CompositorLayerConfiguration {
    func makeConfiguration(capabilities: LayerRenderer.Capabilities,
                           configuration: inout LayerRenderer.Configuration) {
        let foveation = capabilities.supportsFoveation
        let layouts = capabilities.supportedLayouts(options: foveation ? [.foveationEnabled] : [])
        configuration.layout = layouts.contains(.layered) ? .layered : .dedicated
        configuration.isFoveationEnabled = foveation
        // Half-float color keeps the shader's linear output (P3) without banding.
        if capabilities.supportedColorFormats.contains(.rgba16Float) {
            configuration.colorFormat = .rgba16Float
        }
        configuration.depthFormat = .depth32Float
    }
}

@Observable
final class ImmersiveModel {
    enum Phase { case closed, opening, open, closing }
    private(set) var phase = Phase.closed
    @ObservationIgnored private var handledLaunchArgument = false

    func open(_ openImmersiveSpace: OpenImmersiveSpaceAction) async {
        guard phase == .closed else { return }
        phase = .opening
        switch await openImmersiveSpace(id: LygiaImmersiveSpace.id) {
        case .opened: phase = .open
        default: phase = .closed
        }
    }

    func close(_ dismissImmersiveSpace: DismissImmersiveSpaceAction) async {
        guard phase == .open else { return }
        phase = .closing
        await dismissImmersiveSpace()
        phase = .closed
    }

    /// The layer was invalidated, e.g. the person pressed the Digital Crown.
    func rendererDidEnd() {
        if phase != .opening { phase = .closed }
    }

    /// `-immersive YES` opens the space at launch (handy in Simulator).
    func openIfRequested(_ openImmersiveSpace: OpenImmersiveSpaceAction) async {
        guard !handledLaunchArgument else { return }
        handledLaunchArgument = true
        if UserDefaults.standard.bool(forKey: "immersive") {
            await open(openImmersiveSpace)
        }
    }
}

/// Sidebar button that enters or leaves the immersive space.
struct ImmersiveToggle: View {
    @Environment(ImmersiveModel.self) private var model
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    var body: some View {
        Button {
            Task {
                if model.phase == .open {
                    await model.close(dismissImmersiveSpace)
                } else {
                    await model.open(openImmersiveSpace)
                }
            }
        } label: {
            Label(model.phase == .open ? "Exit Immersive" : "Immersive (Metal)", systemImage: "visionpro")
        }
        .disabled(model.phase == .opening || model.phase == .closing)
        .task { await model.openIfRequested(openImmersiveSpace) }
    }
}
#endif
