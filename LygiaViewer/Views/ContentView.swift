import SwiftUI

enum SidebarItem: Hashable {
    case gallery
    case playground
    case demo(String)

    /// `-demo <id>` launch argument (or "gallery" / "playground").
    static var initial: SidebarItem {
        switch UserDefaults.standard.string(forKey: "demo") {
        case nil, "gallery": .gallery
        case "playground": .playground
        case let id?: DemoCatalog.demo(id: id) != nil ? .demo(id) : .gallery
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
        }
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
