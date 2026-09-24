import SwiftUI

/// `-validateShaders YES` compiles every demo's stitchable function up front
/// with `Shader.compile(as:)` and logs the result, so missing functions or
/// signature mismatches show up without clicking through the gallery.
/// Add `-validateExit YES` to quit afterwards (exit code 1 on failures).
enum ShaderValidation {
    static func runIfRequested() async {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "validateShaders") else { return }

        var failures = 0
        for demo in DemoCatalog.all {
            do {
                try await demo.makeShader().compile(as: demo.usageType)
                print("[validate] OK   \(demo.id) (\(demo.kind.rawValue))")
            } catch {
                failures += 1
                print("[validate] FAIL \(demo.id): \(error)")
            }
        }
        print("[validate] \(DemoCatalog.all.count - failures)/\(DemoCatalog.all.count) shaders compiled")
        if defaults.bool(forKey: "validateExit"), defaults.string(forKey: "snapshotDir") == nil {
            exit(failures == 0 ? 0 : 1)
        }
    }
}

import ImageIO
import UniformTypeIdentifiers

/// `-snapshotDir /path` renders every demo (default parameters, time = 2 s)
/// offscreen with ImageRenderer and writes <id>.png plus a contact sheet
/// `_gallery.png`. Useful for checking the shaders without screen capture.
/// Add `-validateExit YES` to quit afterwards.
enum ShaderSnapshots {
    static func runIfRequested() async {
        let defaults = UserDefaults.standard
        guard let path = defaults.string(forKey: "snapshotDir") else { return }
        let dir = URL(fileURLWithPath: path)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let time = Float(defaults.object(forKey: "snapshotTime") as? Double ?? 2.0)

        for demo in DemoCatalog.all {
            let view = ShaderSurface(demo: demo, values: demo.defaultValues, size: CGSize(width: 256, height: 256), time: time)
                .frame(width: 256, height: 256)
            write(view, to: dir.appendingPathComponent("\(demo.id).png"))
        }

        let gallery = DemoCatalog.all.map { Tile(demo: $0, values: $0.defaultValues, label: "\($0.module.rawValue) · \($0.id)") }
        write(ContactSheet(tiles: gallery, time: time), to: dir.appendingPathComponent("_gallery.png"), scale: 1)
        write(ContactSheet(tiles: pickerVariants(), time: time), to: dir.appendingPathComponent("_variants.png"), scale: 1)
        print("[snapshot] wrote \(DemoCatalog.all.count) demos + _gallery.png + _variants.png to \(dir.path)")
        if defaults.bool(forKey: "validateExit") { exit(0) }
    }

    private static func write(_ view: some View, to url: URL, scale: CGFloat = 2) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        guard let image = renderer.cgImage,
              let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            print("[snapshot] FAIL \(url.lastPathComponent)")
            return
        }
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
    }

    private struct Tile: Identifiable {
        let demo: Demo
        let values: SIMD4<Float>
        let label: String
        var id: String { label }
    }

    /// Every option of each demo's first picker parameter.
    private static func pickerVariants() -> [Tile] {
        DemoCatalog.all.flatMap { demo -> [Tile] in
            guard let index = demo.params.firstIndex(where: { if case .picker = $0.control { true } else { false } }),
                  case let .picker(options) = demo.params[index].control else { return [] }
            return options.indices.map { option in
                var values = demo.defaultValues
                values[index] = Float(option)
                return Tile(demo: demo, values: values, label: "\(demo.id): \(options[option])")
            }
        }
    }

    private struct ContactSheet: View {
        let tiles: [Tile]
        let time: Float
        let tile: CGFloat = 200
        let columns = 7

        var body: some View {
            let demos = tiles
            let rows = stride(from: 0, to: demos.count, by: columns).map { Array(demos[$0..<min($0 + columns, demos.count)]) }
            VStack(alignment: .leading, spacing: 12) {
                ForEach(rows.indices, id: \.self) { r in
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(rows[r]) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                ShaderSurface(demo: item.demo, values: item.values, size: CGSize(width: tile, height: tile), time: time)
                                    .frame(width: tile, height: tile)
                                    .clipShape(.rect(cornerRadius: 8))
                                Text(item.label)
                                    .lineLimit(1)
                                    .frame(width: tile, alignment: .leading)
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(Color(white: 0.12))
        }
    }
}

#if os(macOS)
import AppKit

/// `-windowSnapshot /path/file.png [-windowSnapshotDelay 4]` saves the app's
/// window contents (drawn by the app itself, so no Screen Recording
/// permission is needed). Add `-validateExit YES` to quit afterwards.
enum WindowSnapshot {
    static func runIfRequested() async {
        let defaults = UserDefaults.standard
        guard let path = defaults.string(forKey: "windowSnapshot") else { return }
        let delay = defaults.object(forKey: "windowSnapshotDelay") as? Double ?? 4
        try? await Task.sleep(for: .seconds(delay))
        guard let window = NSApp.windows.first(where: { $0.isVisible && $0.contentView != nil }),
              let view = window.contentView?.superview ?? window.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            print("[windowSnapshot] no window")
            return
        }
        view.cacheDisplay(in: view.bounds, to: rep)
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: URL(fileURLWithPath: path))
            print("[windowSnapshot] wrote \(path)")
        }
        if defaults.bool(forKey: "validateExit") { exit(0) }
    }
}
#endif
