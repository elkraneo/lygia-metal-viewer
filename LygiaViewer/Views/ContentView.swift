import SwiftUI

enum SidebarItem: Hashable {
    case gallery
    case playground
    case demo(String)

    /// `-demo <id>` launch argument (or "gallery" / "playground").
    static var initial: SidebarItem {
        UserDefaults.standard.string(forKey: "demo").flatMap(SidebarItem.init(id:)) ?? .gallery
    }

    /// A demo id, or "gallery" / "playground".
    init?(id: String) {
        switch id {
        case "gallery": self = .gallery
        case "playground": self = .playground
        default:
            guard DemoCatalog.demo(id: id) != nil else { return nil }
            self = .demo(id)
        }
    }
}

struct ContentView: View {
    @State private var selection: SidebarItem? = SidebarItem.initial
    @State private var values: [String: SIMD4<Float>] = [:]

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section {
                    NavigationLink(value: SidebarItem.gallery) {
                        Label("All demos", systemImage: "square.grid.2x2")
                    }
                    #if os(macOS)
                    NavigationLink(value: SidebarItem.playground) {
                        Label("Playground", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                    #endif
                    #if os(visionOS)
                    ImmersiveToggle()
                    #endif
                }
                ForEach(DemoModule.allCases) { module in
                    Section(module.rawValue) {
                        ForEach(DemoCatalog.demos(in: module)) { demo in
                            NavigationLink(value: SidebarItem.demo(demo.id)) {
                                Label(demo.title, systemImage: module.systemImage)
                            }
                        }
                    }
                }
            }
            .navigationTitle("LYGIA")
            #if os(macOS)
            .navigationSplitViewColumnWidth(min: 200, ideal: 230)
            #endif
        } detail: {
            detail
        }
        .task {
            await ShaderValidation.runIfRequested()
            await ShaderSnapshots.runIfRequested()
            #if os(macOS)
            await WindowSnapshot.runIfRequested()
            #endif
            await runTourIfRequested()
        }
    }

    /// `-tour gallery,hexRosette,...` steps through the given items forever, e.g. for
    /// screen recordings, sweeping each demo's first continuous slider so the
    /// parameters visibly change. `-tourInterval <seconds>` sets the time per item (default 4),
    /// `-tourDelay <seconds>` waits before starting.
    private func runTourIfRequested() async {
        guard let list = UserDefaults.standard.string(forKey: "tour") else { return }
        let items = list.split(separator: ",").compactMap { SidebarItem(id: String($0)) }
        guard !items.isEmpty else { return }
        let interval = UserDefaults.standard.double(forKey: "tourInterval")
        let seconds = interval > 0 ? interval : 4
        #if os(macOS)
        // Recordings need a predictable frame: 1280x840, centered on the main display.
        if let window = NSApp.windows.first(where: \.isVisible), let screen = NSScreen.screens.first {
            let size = CGSize(width: 1280, height: 840)
            let origin = CGPoint(x: screen.visibleFrame.midX - size.width / 2, y: screen.visibleFrame.midY - size.height / 2)
            window.setFrame(CGRect(origin: origin, size: size), display: true)
        }
        #endif
        try? await Task.sleep(for: .seconds(UserDefaults.standard.double(forKey: "tourDelay")))
        while !Task.isCancelled {
            for item in items {
                selection = item
                #if os(macOS)
                NSCursor.setHiddenUntilMouseMoves(true)
                #endif
                await sweep(item, for: seconds)
            }
        }
    }

    /// Moves the demo's first continuous slider from its default toward the far
    /// end of its range and back, then restores the defaults.
    private func sweep(_ item: SidebarItem, for seconds: Double) async {
        guard case .demo(let id) = item, let demo = DemoCatalog.demo(id: id),
              let index = demo.params.firstIndex(where: {
                  if case .slider(_, step: nil) = $0.control { true } else { false }
              }),
              case .slider(let range, _) = demo.params[index].control
        else {
            try? await Task.sleep(for: .seconds(seconds))
            return
        }
        let start = Date.now
        let from = demo.params[index].defaultValue
        let to = from - range.lowerBound > range.upperBound - from ? range.lowerBound : range.upperBound
        while !Task.isCancelled, Date.now.timeIntervalSince(start) < seconds {
            let t = Float(Date.now.timeIntervalSince(start) / seconds)
            var v = demo.defaultValues
            v[index] = from + (to - from) * 0.6 * sin(.pi * t)
            values[demo.id] = v
            try? await Task.sleep(for: .milliseconds(33))
        }
        values[demo.id] = nil
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .demo(let id)?:
            if let demo = DemoCatalog.demo(id: id) {
                DemoDetailView(demo: demo, values: binding(for: demo))
                    .id(demo.id)
            }
        case .playground?:
            #if os(macOS)
            PlaygroundView()
            #else
            Text("The Playground is macOS-only for now.")
            #endif
        default:
            GalleryGrid(values: values) { selection = .demo($0.id) }
        }
    }

    private func binding(for demo: Demo) -> Binding<SIMD4<Float>> {
        Binding(
            get: { values[demo.id] ?? demo.defaultValues },
            set: { values[demo.id] = $0 }
        )
    }
}

#Preview {
    ContentView()
}
