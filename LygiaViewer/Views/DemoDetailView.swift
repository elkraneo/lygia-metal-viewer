import SwiftUI

struct DemoDetailView: View {
    let demo: Demo
    @Binding var values: SIMD4<Float>
    @State private var paused = false

    var body: some View {
        GeometryReader { proxy in
            if proxy.size.width > 760 {
                HStack(spacing: 0) {
                    preview
                    Divider()
                    ScrollView { inspector.padding() }
                        .frame(width: min(420, proxy.size.width * 0.4))
                }
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        preview.frame(height: min(proxy.size.width, proxy.size.height * 0.6))
                        inspector.padding()
                    }
                }
            }
        }
        .navigationTitle(demo.title)
        .toolbar {
            ToolbarItemGroup {
                Button(paused ? "Play" : "Pause", systemImage: paused ? "play.fill" : "pause.fill") {
                    paused.toggle()
                }
                Button("Reset Parameters", systemImage: "arrow.counterclockwise") {
                    values = demo.defaultValues
                }
            }
        }
    }

    private var preview: some View {
        ShaderPreview(demo: demo, values: values, paused: paused)
            .background(.black)
    }

    @ViewBuilder
    private var inspector: some View {
        let source = ShaderSource.text(for: demo.id)
        let includes = source.map(ShaderSource.lygiaIncludes(in:)) ?? []

        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(demo.summary)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(demo.module.rawValue) · .\(demo.kind.rawValue) · \(demo.id)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            if !demo.params.isEmpty {
                InspectorSection("Parameters") {
                    ForEach(Array(demo.params.prefix(4).enumerated()), id: \.element.id) { index, param in
                        ParamControl(param: param, value: component(index))
                    }
                }
            }

            if !includes.isEmpty {
                InspectorSection("LYGIA includes") {
                    FlowLayout(spacing: 6) {
                        ForEach(includes) { include in
                            Text(include.path)
                                .font(.caption.monospaced())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.tint.opacity(0.15), in: .capsule)
                        }
                    }
                }
            }

            if let source {
                let calls = ShaderSource.callLines(in: source, includes: includes)
                if !calls.isEmpty {
                    InspectorSection("LYGIA calls") {
                        CodeText(text: calls.joined(separator: "\n"), highlight: ShaderSource.functionNames(for: includes))
                    }
                }
                InspectorSection("Source · \(demo.id).metal") {
                    CodeText(text: source, highlight: ShaderSource.functionNames(for: includes))
                }
            } else {
                Text("Source not found in bundle (ShaderSources/\(demo.id).metal).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func component(_ index: Int) -> Binding<Float> {
        Binding(get: { values[index] }, set: { values[index] = $0 })
    }
}

private struct InspectorSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content
        }
    }
}

struct ParamControl: View {
    let param: DemoParam
    @Binding var value: Float

    var body: some View {
        switch param.control {
        case let .slider(range, step):
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(param.name)
                    Spacer()
                    Text(step == 1 ? "\(Int(value.rounded()))" : value.formatted(.number.precision(.fractionLength(2))))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .font(.callout)
                if let step {
                    Slider(value: $value, in: range, step: step)
                } else {
                    Slider(value: $value, in: range)
                }
            }
        case let .picker(options):
            Picker(param.name, selection: Binding(get: { Int(value.rounded()) }, set: { value = Float($0) })) {
                ForEach(options.indices, id: \.self) { i in
                    Text(options[i]).tag(i)
                }
            }
        case .toggle:
            Toggle(param.name, isOn: Binding(get: { value > 0.5 }, set: { value = $0 ? 1 : 0 }))
        }
    }
}

/// Monospaced, selectable source with light highlighting: comments,
/// preprocessor lines and LYGIA function names.
struct CodeText: View {
    let text: String
    let highlight: Set<String>

    var body: some View {
        ScrollView(.horizontal) {
            Text(attributed)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .fixedSize()
                .padding(10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 8))
    }

    private var attributed: AttributedString {
        var result = AttributedString()
        for (i, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            if i > 0 { result += AttributedString("\n") }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("//") {
                var part = AttributedString(line)
                part.foregroundColor = .secondary
                result += part
            } else if trimmed.hasPrefix("#") {
                var part = AttributedString(line)
                part.foregroundColor = .purple
                result += part
            } else {
                result += highlightWords(in: String(line))
            }
        }
        return result
    }

    private func highlightWords(in line: String) -> AttributedString {
        var result = AttributedString()
        var word = ""
        func flushWord() {
            guard !word.isEmpty else { return }
            var part = AttributedString(word)
            if highlight.contains(word.lowercased()) {
                part.foregroundColor = .accentColor
                part.inlinePresentationIntent = .stronglyEmphasized
            }
            result += part
            word = ""
        }
        for ch in line {
            if ch.isLetter || ch.isNumber || ch == "_" {
                word.append(ch)
            } else {
                flushWord()
                result += AttributedString(String(ch))
            }
        }
        flushWord()
        return result
    }
}

/// Minimal wrapping layout for the include chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0,
                      height: rows.last.map { $0.y + $0.height } ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(width: bounds.width, subviews: subviews)
        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
        }
    }

    private struct Row { var indices: [Int] = []; var y: CGFloat = 0; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if !rows[rows.count - 1].indices.isEmpty, rows[rows.count - 1].width + spacing + size.width > width {
                let last = rows[rows.count - 1]
                rows.append(Row(y: last.y + last.height + spacing))
            }
            var row = rows[rows.count - 1]
            row.width += (row.indices.isEmpty ? 0 : spacing) + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
            rows[rows.count - 1] = row
        }
        return rows
    }
}
