import SwiftUI

/// Every demo as a live thumbnail, grouped by module.
struct GalleryGrid: View {
    let values: [String: SIMD4<Float>]
    var onSelect: (Demo) -> Void

    private let columns = [GridItem(.adaptive(minimum: 200, maximum: 320), spacing: 16)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 16, pinnedViews: []) {
                ForEach(DemoModule.allCases) { module in
                    Section {
                        ForEach(DemoCatalog.demos(in: module)) { demo in
                            Button { onSelect(demo) } label: {
                                GalleryTile(demo: demo, values: values[demo.id] ?? demo.defaultValues)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Label(module.rawValue, systemImage: module.systemImage)
                            .font(.title3.bold())
                            .padding(.top, 8)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("All demos (\(DemoCatalog.all.count))")
    }
}

private struct GalleryTile: View {
    let demo: Demo
    let values: SIMD4<Float>

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ShaderPreview(demo: demo, values: values)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(.rect(cornerRadius: 10))
            Text(demo.title)
                .font(.callout.weight(.semibold))
            Text(demo.id)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
        .contentShape(.rect)
    }
}
