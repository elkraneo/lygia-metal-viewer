import Foundation

/// Reads a demo's .metal source (copied into the bundle at build time under
/// ShaderSources/) and extracts the LYGIA files it includes.
enum ShaderSource {
    struct Include: Identifiable, Hashable {
        /// e.g. "sdf/starSDF.msl"
        let path: String
        var id: String { path }
        /// LYGIA convention: the file is named after its main function.
        var functionName: String { (path as NSString).lastPathComponent.replacingOccurrences(of: ".msl", with: "") }
        var module: String { path.split(separator: "/").first.map(String.init) ?? "" }
    }

    static func text(for demoID: String) -> String? {
        guard let url = Bundle.main.url(forResource: demoID, withExtension: "metal", subdirectory: "ShaderSources") else {
            return nil
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    static func lygiaIncludes(in source: String) -> [Include] {
        source.split(separator: "\n").compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("#include \"lygia/"), let end = trimmed.dropFirst(16).firstIndex(of: "\"") else {
                return nil
            }
            return Include(path: String(trimmed.dropFirst(16)[..<end]))
        }
    }

    /// Lines of the demo that call a LYGIA function (excluding includes and comments).
    static func callLines(in source: String, includes: [Include]) -> [String] {
        let names = functionNames(for: includes)
        return source.split(separator: "\n", omittingEmptySubsequences: false).compactMap { raw in
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.hasPrefix("#"), !line.hasPrefix("//"), !line.contains("[[ stitchable ]]") else { return nil }
            let words = line.split(whereSeparator: { !($0.isLetter || $0.isNumber || $0 == "_") })
            let calls = words.contains { names.contains($0.lowercased()) }
            return calls ? line : nil
        }
    }

    /// Lowercased LYGIA function names provided by the includes. Names follow
    /// the file ("sdf/starSDF" -> starSDF), sometimes prefixed by the folder
    /// ("color/blend/multiply" -> blendMultiply, "color/tonemap/aces" -> tonemapACES).
    static func functionNames(for includes: [Include]) -> Set<String> {
        var names = Set<String>()
        for include in includes where include.path != "math/const.msl" {
            let name = include.functionName.lowercased()
            let folder = include.path.split(separator: "/").dropLast().last.map { $0.lowercased() } ?? ""
            names.insert(name)
            names.insert(folder + name)
        }
        return names
    }
}
