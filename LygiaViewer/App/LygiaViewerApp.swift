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
        #if os(macOS)
        .commands {
            CommandGroup(after: .sidebar) {
                Button("Compare with Upstream") {
                    NotificationCenter.default.post(name: .showCompare, object: nil)
                }
                .keyboardShortcut("U", modifiers: [.command, .shift])
            }
        }
        #endif

        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif

        #if os(visionOS)
        LygiaImmersiveSpace(model: immersive)
        #endif
    }
}
