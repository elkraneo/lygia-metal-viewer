import SwiftUI

@main
struct LygiaViewerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if os(macOS) || os(visionOS)
        .defaultSize(width: 1280, height: 840)
        #endif
    }
}
