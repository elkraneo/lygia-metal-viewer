import Foundation

/// Inlines `#include "..."` lines so the source can be compiled at runtime
/// with `MTLDevice.makeLibrary(source:)`, whose compiler can't read files.
///
/// - Quoted includes resolve relative to the including file first, then
///   against the search roots (the folder that contains `lygia/`).
/// - `#include <...>` (e.g. <metal_stdlib>) is left for the Metal compiler.
/// - Include guards are kept as-is. Each file is also inlined at most once
///   (like `#pragma once`), which covers LYGIA files without guards.
/// - `#line` directives keep compiler errors pointing at the original files.
struct IncludeFlattener {
    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    var searchRoots: [URL]

    /// Files inlined by the last `flatten` call, in order (paths relative to a root when possible).
    private(set) var includedFiles: [String] = []

    init(searchRoots: [URL]) {
        self.searchRoots = searchRoots
    }

    mutating func flatten(_ source: String, name: String = "playground.metal") throws -> String {
        includedFiles = []
        var seen = Set<String>()
        var stack: [String] = []
        return try flatten(source, displayName: name, directory: nil, seen: &seen, stack: &stack)
    }

    private mutating func flatten(_ source: String, displayName: String, directory: URL?,
                                  seen: inout Set<String>, stack: inout [String]) throws -> String {
        var output: [String] = ["#line 1 \"\(displayName)\""]
        let lines = source.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")

        for (index, line) in lines.enumerated() {
            guard let target = Self.quotedInclude(in: line) else {
                output.append(line)
                continue
            }
            guard let url = resolve(target, from: directory) else {
                throw Failure(message: "\(displayName):\(index + 1): cannot find include \"\(target)\" (search roots: \(searchRoots.map(\.path).joined(separator: ", ")))")
            }
            let key = url.standardizedFileURL.resolvingSymlinksInPath().path
            if stack.contains(key) {
                throw Failure(message: "\(displayName):\(index + 1): include cycle through \(target)")
            }
            if seen.contains(key) {
                output.append("// (already included) \(line)")
                continue
            }
            seen.insert(key)

            let text: String
            do {
                text = try String(contentsOf: url, encoding: .utf8)
            } catch {
                throw Failure(message: "\(displayName):\(index + 1): cannot read \(url.path): \(error.localizedDescription)")
            }
            let childName = relativeName(for: url)
            includedFiles.append(childName)

            stack.append(key)
            output.append(try flatten(text, displayName: childName, directory: url.deletingLastPathComponent(),
                                      seen: &seen, stack: &stack))
            stack.removeLast()
            output.append("#line \(index + 2) \"\(displayName)\"")
        }
        return output.joined(separator: "\n")
    }

    /// `#include "path"` -> path. Tolerates curly quotes from text editors.
    static func quotedInclude(in line: String) -> String? {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("#") else { return nil }
        trimmed = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("include") else { return nil }
        let rest = trimmed.dropFirst("include".count)
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
            .trimmingCharacters(in: .whitespaces)
        guard rest.hasPrefix("\""), let end = rest.dropFirst().firstIndex(of: "\"") else { return nil }
        return String(rest.dropFirst()[..<end])
    }

    private func resolve(_ path: String, from directory: URL?) -> URL? {
        let fm = FileManager.default
        var candidates: [URL] = []
        if let directory { candidates.append(directory.appendingPathComponent(path)) }
        candidates += searchRoots.map { $0.appendingPathComponent(path) }
        return candidates.first { fm.fileExists(atPath: $0.path) }
    }

    private func relativeName(for url: URL) -> String {
        let path = url.standardizedFileURL.path
        for root in searchRoots {
            let rootPath = root.standardizedFileURL.path + "/"
            if path.hasPrefix(rootPath) { return String(path.dropFirst(rootPath.count)) }
        }
        return path
    }
}
