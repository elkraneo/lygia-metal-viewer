#if os(macOS)
import AppKit
import SwiftUI

/// Type MSL with LYGIA includes, see it render live.
/// Includes are flattened in Swift (IncludeFlattener) and compiled with
/// MTLDevice.makeLibrary(source:). Needs a non-sandboxed macOS build.
struct PlaygroundView: View {
    @AppStorage("playgroundSource") private var source = PlaygroundExamples.all[0].source
    @AppStorage("lygiaRoot") private var lygiaRootOverride = ""
    @State private var renderer = PlaygroundRenderer()
    @State private var showFlattened = false

    private var lygiaRoot: URL {
        if !lygiaRootOverride.isEmpty { return URL(fileURLWithPath: lygiaRootOverride) }
        let baked = Bundle.main.object(forInfoDictionaryKey: "LygiaSourceRoot") as? String ?? ""
        return URL(fileURLWithPath: baked).standardizedFileURL
    }

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                CodeEditor(text: $source)
                    .frame(minWidth: 380)
                Divider()
                statusBar
            }
            PlaygroundMetalView(renderer: renderer)
                .frame(minWidth: 320, minHeight: 320)
        }
        .navigationTitle("Playground")
        .toolbar {
            ToolbarItemGroup {
                Menu("Examples") {
                    ForEach(PlaygroundExamples.all) { example in
                        Button(example.name) { source = example.source }
                    }
                }
                Button(renderer.paused ? "Play" : "Pause", systemImage: renderer.paused ? "play.fill" : "pause.fill") {
                    renderer.togglePause()
                }
                Button("Flattened Source", systemImage: "doc.text.magnifyingglass") { showFlattened = true }
                Button("LYGIA Folder…", systemImage: "folder") { chooseRoot() }
            }
        }
        .task(id: source) {
            // Debounce typing, then compile.
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            renderer.compile(source, lygiaRoot: lygiaRoot)
        }
        .onChange(of: lygiaRootOverride) { renderer.compile(source, lygiaRoot: lygiaRoot) }
        .sheet(isPresented: $showFlattened) {
            VStack(alignment: .leading) {
                HStack {
                    Text("Flattened source (\(renderer.flattenedSource.split(separator: "\n").count) lines)").font(.headline)
                    Spacer()
                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(renderer.flattenedSource, forType: .string)
                    }
                    Button("Done") { showFlattened = false }.keyboardShortcut(.defaultAction)
                }
                ScrollView([.horizontal, .vertical]) {
                    Text(renderer.flattenedSource)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .fixedSize()
                        .padding(8)
                }
            }
            .padding()
            .frame(minWidth: 700, minHeight: 500)
        }
    }

    @ViewBuilder
    private var statusBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            switch renderer.status {
            case .idle, .compiling:
                Label("Compiling…", systemImage: "hourglass")
            case let .ok(files, ms):
                Label("OK: \(files) LYGIA files inlined, compiled in \(ms) ms", systemImage: "checkmark.circle")
                    .foregroundStyle(.green)
            case let .failed(message):
                ScrollView {
                    Text(message)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 160)
            }
            Text("LYGIA: \(lygiaRoot.path)/lygia")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.caption)
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func chooseRoot() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.message = "Choose the folder that contains lygia/"
        if panel.runModal() == .OK, let url = panel.url {
            // Accept either the parent of lygia/ or lygia/ itself.
            lygiaRootOverride = url.lastPathComponent == "lygia" ? url.deletingLastPathComponent().path : url.path
        }
    }
}

/// Plain NSTextView: SwiftUI's TextEditor applies smart quotes, which break `#include "..."`.
struct CodeEditor: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        let textView = scroll.documentView as! NSTextView
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isRichText = false
        textView.allowsUndo = true
        textView.textContainerInset = NSSize(width: 6, height: 8)
        textView.string = text
        textView.delegate = context.coordinator
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let textView = scroll.documentView as? NSTextView, textView.string != text else { return }
        textView.string = text
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        init(text: Binding<String>) { self.text = text }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
        }
    }
}

struct PlaygroundExample: Identifiable {
    let name: String
    let source: String
    var id: String { name }
}

enum PlaygroundExamples {
    static let all: [PlaygroundExample] = [
        PlaygroundExample(name: "Kaleidoscope star", source: """
        // Write MSL using LYGIA. Define:
        //   float4 mainImage(float2 fragCoord, float2 resolution, float time)
        // fragCoord is in pixels, origin bottom-left. <metal_stdlib> is already included.
        #include "lygia/space/ratio.msl"
        #include "lygia/space/kaleidoscope.msl"
        #include "lygia/space/rotate.msl"
        #include "lygia/sdf/starSDF.msl"
        #include "lygia/sdf/circleSDF.msl"
        #include "lygia/draw/stroke.msl"
        #include "lygia/color/palette/spectral.msl"

        float4 mainImage(float2 fragCoord, float2 resolution, float time) {
            float2 st = ratio(fragCoord / resolution, resolution);
            float2 k = kaleidoscope(st, 10.0, time * 0.2);
            float d = starSDF(rotate(k, time * 0.3), 5, 0.1);
            float3 color = spectral(fract(d * 0.8 - time * 0.1)) * stroke(d, 0.5, 0.2, 0.01);
            color += stroke(circleSDF(st), 0.9, 0.02, 0.005);
            return float4(color, 1.0);
        }
        """),
        PlaygroundExample(name: "Hex fbm", source: """
        #include "lygia/space/ratio.msl"
        #include "lygia/space/hexTile.msl"
        #include "lygia/sdf/hexSDF.msl"
        #include "lygia/generative/fbm.msl"
        #include "lygia/draw/stroke.msl"

        float4 mainImage(float2 fragCoord, float2 resolution, float time) {
            float2 st = ratio(fragCoord / resolution, resolution);
            float4 h = hexTile(st * 8.0);
            float n = fbm(float3(h.zw * 0.15, time * 0.2)) * 0.5 + 0.5;
            float3 color = mix(float3(0.05, 0.1, 0.2), float3(1.0, 0.8, 0.4), n);
            color *= 1.0 - stroke(hexSDF(h.xy), 0.9, 0.08, 0.02);
            return float4(color, 1.0);
        }
        """),
        PlaygroundExample(name: "Voronoi stained glass", source: """
        #include "lygia/space/ratio.msl"
        #include "lygia/generative/voronoi.msl"
        #include "lygia/color/space/hsv2rgb.msl"

        float4 mainImage(float2 fragCoord, float2 resolution, float time) {
            float2 st = ratio(fragCoord / resolution, resolution);
            float3 v = voronoi(st * 7.0, time);
            float3 color = hsv2rgb(float3(fract(v.x * 0.5 + v.y * 0.3), 0.7, 0.95));
            color *= smoothstep(0.0, 0.25, v.z) * (1.2 - v.z);
            return float4(color, 1.0);
        }
        """),
    ]
}
#endif
