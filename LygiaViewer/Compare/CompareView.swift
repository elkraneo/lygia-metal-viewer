#if os(macOS)
import AppKit
import SwiftUI

/// Renders one snippet with upstream LYGIA and with this fork, side by side,
/// with a per-pixel difference. Each built-in case shows one Metal fix; the
/// snippet is editable, so any function can be checked the same way.
struct CompareView: View {
    @AppStorage("compareSource") private var source = CompareCases.all[0].source
    @AppStorage("compareCase") private var caseID = CompareCases.all[0].id
    @AppStorage("lygiaRoot") private var lygiaRootOverride = ""
    @State private var renderer = CompareRenderer()
    @State private var time: Float = 2

    private var variants: [LygiaVariant] {
        [LygiaVariant(id: "upstream", title: "Upstream main", root: LygiaRoots.upstream),
         LygiaVariant(id: "fork", title: "This fork", root: LygiaRoots.fork(override: lygiaRootOverride))]
    }

    private var current: CompareCase? { CompareCases.all.first { $0.id == caseID } }

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                HStack {
                    Menu {
                        ForEach(CompareCases.all) { c in
                            Button(c.title) { caseID = c.id; source = c.source }
                        }
                    } label: {
                        Label(current.map { $0.source == source ? $0.title : "\($0.title) (edited)" } ?? "Edited snippet", systemImage: "text.document")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    Spacer()
                }
                .font(.callout)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                Divider()
                CodeEditor(text: $source)
                    .frame(minWidth: 320, idealWidth: 420, maxWidth: 560)
                Divider()
                HStack {
                    Text("time").foregroundStyle(.secondary)
                    Slider(value: $time, in: 0...10)
                    Text(String(format: "%.1f s", time)).monospacedDigit().frame(width: 44, alignment: .trailing)
                }
                .font(.caption)
                .padding(8)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let current {
                        Text(current.note)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    // Wraps to two rows when the window is narrow.
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 240, maximum: 240), spacing: 16, alignment: .top)], alignment: .leading, spacing: 16) {
                        ForEach(variants) { v in
                            pane(title: v.title, outcome: renderer.outcomes[v.id] ?? .compiling)
                        }
                        differencePane
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minWidth: 300)
        }
        .navigationTitle("Compare")
        .toolbar {
            ToolbarItemGroup {
                Button("Copy Report", systemImage: "doc.on.clipboard") { copyReport() }
                    .disabled(renderer.difference == nil)
            }
        }
        .task(id: "\(source)|\(time)|\(lygiaRootOverride)") {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            renderer.render(source, time: time, variants: variants)
        }
    }

    @ViewBuilder
    private func pane(title: String, outcome: CompareRenderer.Outcome) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            switch outcome {
            case .compiling:
                ProgressView().frame(width: 240, height: 240)
            case .rendered(let image):
                Image(decorative: image, scale: 1)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: 240, height: 240)
                    .clipShape(.rect(cornerRadius: 8))
            case .failed(let message):
                ScrollView {
                    Text(message)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(width: 240, height: 240)
                .padding(6)
                .background(.red.opacity(0.08), in: .rect(cornerRadius: 8))
            }
        }
    }

    @ViewBuilder
    private var differencePane: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Difference").font(.headline)
            if let d = renderer.difference {
                Image(decorative: d.heatmap, scale: 1)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: 240, height: 240)
                    .clipShape(.rect(cornerRadius: 8))
                Text(summary(d))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(d.max == 0 ? .green : .primary)
            } else {
                Text("Needs both renders.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 240, height: 240)
            }
        }
    }

    private func summary(_ d: CompareRenderer.Difference) -> String {
        if d.max == 0 { return "Identical" }
        return String(format: "%.0f%% of pixels differ · max %.0f/255 · mean %.2f/255", d.changed * 100, d.max * 255, d.mean * 255)
    }

    /// A Markdown block for an issue or PR: case, note, and the numbers.
    private func copyReport() {
        guard let d = renderer.difference else { return }
        var lines = ["**\(current?.title ?? "Compare")** (LYGIA Viewer, upstream main vs. fork, \(CompareRenderer.size)x\(CompareRenderer.size), time \(String(format: "%.1f", time)) s)"]
        if let current { lines.append(current.note) }
        for v in variants {
            if case .failed(let message) = renderer.outcomes[v.id] {
                lines.append("- \(v.title): doesn't compile: `\(message.split(separator: "\n").first ?? "")`")
            }
        }
        lines.append("- Difference: \(summary(d))")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lines.joined(separator: "\n"), forType: .string)
    }
}

/// Where the two LYGIA checkouts live. The fork is the one the demos are
/// built with; upstream main is exported next to it at build time.
enum LygiaRoots {
    static func fork(override: String) -> URL {
        if !override.isEmpty { return URL(fileURLWithPath: override) }
        let baked = Bundle.main.object(forInfoDictionaryKey: "LygiaSourceRoot") as? String ?? ""
        return URL(fileURLWithPath: baked).standardizedFileURL
    }

    static var upstream: URL {
        let baked = Bundle.main.object(forInfoDictionaryKey: "LygiaUpstreamRoot") as? String ?? ""
        return URL(fileURLWithPath: baked).standardizedFileURL
    }
}
#endif
