import SwiftUI

@main
struct LygiaViewerApp: App {
    #if os(visionOS)
    @State private var immersive = ImmersiveModel()
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
                #if os(visionOS)
                .environment(immersive)
                #endif
        }
        #if os(macOS) || os(visionOS)
        .defaultSize(width: 1280, height: 840)
        #endif

        #if os(visionOS)
        LygiaImmersiveSpace(model: immersive)
        #endif
    }
}
