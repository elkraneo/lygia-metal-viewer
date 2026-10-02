import SwiftUI

/// Syntax coloring for Metal Shading Language, shared by the read-only source
/// views and the editors. A small tokenizer, not a parser: comments, strings,
/// preprocessor lines, numbers, keywords, types, and LYGIA function names.
enum MetalSyntax {
    enum Kind {
        case comment, string, preprocessor, number, keyword, type, attribute, lygia
    }

    struct Token {
        let range: Range<String.Index>
        let kind: Kind
    }

    static let keywords: Set<String> = [
        "return", "if", "else", "for", "while", "do", "break", "continue", "switch", "case", "default",
        "const", "constant", "constexpr", "static", "inline", "struct", "namespace", "using", "typedef",
        "template", "typename", "kernel", "vertex", "fragment", "device", "thread", "threadgroup",
        "true", "false", "sampler", "texture2d", "texturecube", "access", "address", "filter",
    ]

    static let types: Set<String> = {
        var set: Set<String> = ["void", "bool", "int", "uint", "float", "half", "short", "ushort", "char", "uchar"]
        for base in ["float", "half", "int", "uint", "bool"] {
            for n in 2...4 { set.insert("\(base)\(n)") }
        }
        for n in 2...4 { for m in 2...4 { set.insert("float\(n)x\(m)"); set.insert("half\(n)x\(m)") } }
        // GLSL spellings LYGIA accepts through its defines.
        for name in ["vec2", "vec3", "vec4", "mat2", "mat3", "mat4", "ivec2", "ivec3", "ivec4"] { set.insert(name) }
        return set
    }()

    /// `lygia` matches function names provided by the included LYGIA files (lowercased).
    static func tokenize(_ text: String, lygia: Set<String> = []) -> [Token] {
        var tokens: [Token] = []
        var i = text.startIndex
        let end = text.endIndex

        func peek(_ offset: Int = 1) -> Character? {
            guard let j = text.index(i, offsetBy: offset, limitedBy: end), j < end else { return nil }
            return text[j]
        }

        while i < end {
            let c = text[i]
            if c == "/" && peek() == "/" {
                let lineEnd = text[i...].firstIndex(of: "\n") ?? end
                tokens.append(Token(range: i..<lineEnd, kind: .comment))
                i = lineEnd
            } else if c == "/" && peek() == "*" {
                let close = text[i...].range(of: "*/")?.upperBound ?? end
                tokens.append(Token(range: i..<close, kind: .comment))
                i = close
            } else if c == "#" {
                // Preprocessor directive: the whole line, except a trailing comment.
                let lineEnd = text[i...].firstIndex(of: "\n") ?? end
                let commentStart = text[i..<lineEnd].range(of: "//")?.lowerBound ?? lineEnd
                tokens.append(Token(range: i..<commentStart, kind: .preprocessor))
                i = commentStart
            } else if c == "\"" {
                var j = text.index(after: i)
                while j < end, text[j] != "\"", text[j] != "\n" { j = text.index(after: j) }
                if j < end, text[j] == "\"" { j = text.index(after: j) }
                tokens.append(Token(range: i..<j, kind: .string))
                i = j
            } else if c == "[" && peek() == "[" {
                let close = text[i...].range(of: "]]")?.upperBound ?? end
                tokens.append(Token(range: i..<close, kind: .attribute))
                i = close
            } else if c.isNumber || (c == "." && (peek()?.isNumber ?? false)) {
                var j = text.index(after: i)
                while j < end, text[j].isNumber || text[j] == "." || text[j] == "e" || text[j] == "f" || text[j] == "h" || text[j] == "u" || text[j] == "x" || text[j].isHexDigit {
                    j = text.index(after: j)
                }
                tokens.append(Token(range: i..<j, kind: .number))
                i = j
            } else if c.isLetter || c == "_" {
                var j = text.index(after: i)
                while j < end, text[j].isLetter || text[j].isNumber || text[j] == "_" { j = text.index(after: j) }
                let word = String(text[i..<j])
                if keywords.contains(word) {
                    tokens.append(Token(range: i..<j, kind: .keyword))
                } else if types.contains(word) {
                    tokens.append(Token(range: i..<j, kind: .type))
                } else if lygia.contains(word.lowercased()) {
                    tokens.append(Token(range: i..<j, kind: .lygia))
                }
                i = j
            } else {
                i = text.index(after: i)
            }
        }
        return tokens
    }

    static func color(for kind: Kind) -> Color {
        switch kind {
        case .comment: .secondary
        case .string: .red
        case .preprocessor: .purple
        case .number: .orange
        case .keyword: .pink
        case .type: .cyan
        case .attribute: .mint
        case .lygia: .accentColor
        }
    }

    static func attributed(_ text: String, lygia: Set<String> = []) -> AttributedString {
        var result = AttributedString(text)
        for token in tokenize(text, lygia: lygia) {
            guard let range = Range(token.range, in: result) else { continue }
            result[range].foregroundColor = color(for: token.kind)
            if token.kind == .lygia { result[range].inlinePresentationIntent = .stronglyEmphasized }
        }
        return result
    }
}

#if os(macOS)
import AppKit

extension MetalSyntax {
    static func nsColor(for kind: Kind) -> NSColor {
        switch kind {
        case .comment: .secondaryLabelColor
        case .string: .systemRed
        case .preprocessor: .systemPurple
        case .number: .systemOrange
        case .keyword: .systemPink
        case .type: .systemCyan
        case .attribute: .systemMint
        case .lygia: .controlAccentColor
        }
    }

    /// Recolors `storage` in place; the text itself is untouched.
    static func highlight(_ storage: NSTextStorage, lygia: Set<String> = []) {
        let text = storage.string
        let whole = NSRange(location: 0, length: storage.length)
        storage.beginEditing()
        storage.removeAttribute(.foregroundColor, range: whole)
        storage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: whole)
        for token in tokenize(text, lygia: lygia) {
            storage.addAttribute(.foregroundColor, value: nsColor(for: token.kind), range: NSRange(token.range, in: text))
        }
        storage.endEditing()
    }
}
#endif
