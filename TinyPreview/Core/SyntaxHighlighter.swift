import AppKit
import Foundation

public enum SyntaxHighlighter {
    public static func highlight(
        _ text: String,
        language: SourceLanguage,
        darkMode: Bool
    ) -> NSAttributedString {
        let theme = Theme(darkMode: darkMode)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2
        paragraph.tabStops = stride(from: 1, through: 20, by: 1).map {
            NSTextTab(textAlignment: .left, location: CGFloat($0 * 28), options: [:])
        }
        paragraph.defaultTabInterval = 28
        let result = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 12.5, weight: .regular),
                .foregroundColor: theme.foreground,
                .paragraphStyle: paragraph
            ]
        )
        let fullRange = NSRange(text.startIndex..., in: text)
        var protected = IndexSet()

        apply(pattern: commentPattern(for: language), color: theme.comment, to: result, in: fullRange, protected: &protected, protectsRange: true)
        apply(pattern: stringPattern(for: language), color: theme.string, to: result, in: fullRange, protected: &protected, protectsRange: true)
        apply(pattern: numberPattern, color: theme.number, to: result, in: fullRange, protected: &protected, protectsRange: false)

        let keywords = keywordList(for: language)
        if !keywords.isEmpty {
            let escaped = keywords.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|")
            apply(pattern: "\\b(?:\(escaped))\\b", color: theme.keyword, to: result, in: fullRange, protected: &protected, protectsRange: false)
        }
        let types = typeList(for: language)
        if !types.isEmpty {
            let escaped = types.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|")
            apply(pattern: "\\b(?:\(escaped))\\b", color: theme.type, to: result, in: fullRange, protected: &protected, protectsRange: false)
        }
        if language == .html || language == .xml {
            apply(pattern: #"(?<=</?)[A-Za-z_][A-Za-z0-9_.:-]*"#, color: theme.keyword, to: result, in: fullRange, protected: &protected, protectsRange: false)
        }
        if language == .markdown {
            apply(pattern: #"(?m)^(?:#{1,6}|>|[-*+]\s|\d+\.\s)"#, color: theme.keyword, to: result, in: fullRange, protected: &protected, protectsRange: false)
        }
        return result
    }

    public static func plainText(_ text: String, darkMode: Bool) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2
        paragraph.defaultTabInterval = 28
        return NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 12.5, weight: .regular),
                .foregroundColor: darkMode ? NSColor(calibratedWhite: 0.88, alpha: 1) : NSColor(calibratedWhite: 0.14, alpha: 1),
                .paragraphStyle: paragraph
            ]
        )
    }

    private static func apply(
        pattern: String,
        color: NSColor,
        to result: NSMutableAttributedString,
        in fullRange: NSRange,
        protected: inout IndexSet,
        protectsRange: Bool
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return }
        for match in regex.matches(in: result.string, range: fullRange) where match.range.length > 0 {
            let indexes = IndexSet(integersIn: match.range.location ..< match.range.location + match.range.length)
            guard protected.intersection(indexes).isEmpty else { continue }
            result.addAttribute(.foregroundColor, value: color, range: match.range)
            if protectsRange { protected.formUnion(indexes) }
        }
    }

    private static let numberPattern = #"(?<![A-Za-z_])(?:0x[0-9A-Fa-f]+|0b[01]+|\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)(?![A-Za-z_])"#

    private static func commentPattern(for language: SourceLanguage) -> String {
        switch language {
        case .python, .ruby, .shell, .yaml, .toml:
            #"(?m)#.*$"#
        case .html, .xml, .markdown:
            #"<!--[\s\S]*?-->"#
        case .sql:
            #"(?m)--.*$|/\*[\s\S]*?\*/"#
        case .css:
            #"/\*[\s\S]*?\*/"#
        default:
            #"(?m)//.*$|/\*[\s\S]*?\*/"#
        }
    }

    private static func stringPattern(for language: SourceLanguage) -> String {
        switch language {
        case .html, .xml:
            #"\"[^\"]*\"|'[^']*'"#
        case .shell:
            #"\"(?:\\.|[^\"\\])*\"|'[^']*'"#
        default:
            #"\"(?:\\.|[^\"\\])*\"|'(?:\\.|[^'\\])*'|`(?:\\.|[^`\\])*`"#
        }
    }

    private static func keywordList(for language: SourceLanguage) -> [String] {
        switch language {
        case .swift:
            ["actor", "as", "associatedtype", "async", "await", "break", "case", "catch", "class", "continue", "default", "defer", "deinit", "do", "else", "enum", "extension", "fallthrough", "false", "fileprivate", "for", "func", "guard", "if", "import", "in", "init", "inout", "internal", "is", "let", "nil", "nonisolated", "open", "operator", "private", "protocol", "public", "repeat", "rethrows", "return", "self", "some", "static", "struct", "subscript", "super", "switch", "throw", "throws", "true", "try", "typealias", "var", "where", "while"]
        case .objectiveC, .c, .cpp:
            ["alignas", "auto", "break", "case", "catch", "char", "class", "const", "constexpr", "continue", "default", "delete", "do", "double", "else", "enum", "explicit", "extern", "false", "float", "for", "friend", "if", "inline", "int", "long", "namespace", "new", "nullptr", "private", "protected", "public", "register", "return", "short", "signed", "sizeof", "static", "struct", "switch", "template", "this", "throw", "true", "try", "typedef", "typename", "union", "unsigned", "using", "virtual", "void", "volatile", "while"]
        case .rust:
            ["as", "async", "await", "break", "const", "continue", "crate", "dyn", "else", "enum", "extern", "false", "fn", "for", "if", "impl", "in", "let", "loop", "match", "mod", "move", "mut", "pub", "ref", "return", "self", "Self", "static", "struct", "super", "trait", "true", "type", "unsafe", "use", "where", "while"]
        case .go:
            ["break", "case", "chan", "const", "continue", "default", "defer", "else", "fallthrough", "for", "func", "go", "goto", "if", "import", "interface", "map", "package", "range", "return", "select", "struct", "switch", "type", "var"]
        case .python:
            ["and", "as", "assert", "async", "await", "break", "class", "continue", "def", "del", "elif", "else", "except", "False", "finally", "for", "from", "global", "if", "import", "in", "is", "lambda", "None", "nonlocal", "not", "or", "pass", "raise", "return", "True", "try", "while", "with", "yield"]
        case .ruby:
            ["alias", "and", "begin", "break", "case", "class", "def", "defined", "do", "else", "elsif", "end", "ensure", "false", "for", "if", "in", "module", "next", "nil", "not", "or", "redo", "rescue", "retry", "return", "self", "super", "then", "true", "undef", "unless", "until", "when", "while", "yield"]
        case .java, .kotlin:
            ["abstract", "as", "break", "case", "catch", "class", "companion", "const", "continue", "data", "default", "do", "else", "enum", "extends", "false", "final", "finally", "for", "fun", "if", "implements", "import", "in", "interface", "internal", "is", "native", "new", "null", "object", "open", "override", "package", "private", "protected", "public", "return", "sealed", "static", "super", "switch", "synchronized", "this", "throw", "throws", "true", "try", "typealias", "val", "var", "when", "while"]
        case .javascript, .typescript:
            ["async", "await", "break", "case", "catch", "class", "const", "continue", "debugger", "default", "delete", "do", "else", "enum", "export", "extends", "false", "finally", "for", "from", "function", "if", "implements", "import", "in", "instanceof", "interface", "let", "new", "null", "of", "private", "protected", "public", "return", "static", "super", "switch", "this", "throw", "true", "try", "type", "typeof", "undefined", "var", "void", "while", "with", "yield"]
        case .css:
            ["@charset", "@container", "@font-face", "@import", "@keyframes", "@layer", "@media", "@page", "@supports", "important"]
        case .shell:
            ["case", "do", "done", "elif", "else", "esac", "fi", "for", "function", "if", "in", "select", "then", "time", "until", "while"]
        case .json:
            ["false", "null", "true"]
        case .yaml:
            ["false", "null", "true", "yes", "no"]
        case .toml:
            ["false", "true"]
        case .sql:
            ["ALTER", "AND", "AS", "ASC", "BEGIN", "BETWEEN", "BY", "CASE", "CREATE", "DELETE", "DESC", "DISTINCT", "DROP", "ELSE", "END", "EXISTS", "FROM", "GROUP", "HAVING", "IN", "INDEX", "INSERT", "INTO", "IS", "JOIN", "LIKE", "LIMIT", "NOT", "NULL", "ON", "OR", "ORDER", "OUTER", "PRIMARY", "REFERENCES", "SELECT", "SET", "TABLE", "THEN", "UNION", "UNIQUE", "UPDATE", "VALUES", "VIEW", "WHEN", "WHERE", "WITH"]
        case .html, .xml, .markdown:
            []
        }
    }

    private static func typeList(for language: SourceLanguage) -> [String] {
        switch language {
        case .swift:
            ["Any", "Array", "Bool", "Character", "Data", "Dictionary", "Double", "Error", "Float", "Int", "Never", "Optional", "Result", "Set", "String", "UInt", "URL", "Void"]
        case .rust:
            ["bool", "char", "f32", "f64", "i8", "i16", "i32", "i64", "i128", "isize", "str", "u8", "u16", "u32", "u64", "u128", "usize"]
        case .go:
            ["bool", "byte", "complex64", "complex128", "error", "float32", "float64", "int", "int8", "int16", "int32", "int64", "rune", "string", "uint", "uint8", "uint16", "uint32", "uint64", "uintptr"]
        case .typescript:
            ["any", "bigint", "boolean", "never", "number", "object", "string", "symbol", "unknown", "void"]
        default:
            []
        }
    }

    private struct Theme {
        let foreground: NSColor
        let comment: NSColor
        let string: NSColor
        let number: NSColor
        let keyword: NSColor
        let type: NSColor

        init(darkMode: Bool) {
            if darkMode {
                foreground = NSColor(calibratedRed: 0.86, green: 0.87, blue: 0.90, alpha: 1)
                comment = NSColor(calibratedRed: 0.48, green: 0.58, blue: 0.50, alpha: 1)
                string = NSColor(calibratedRed: 0.93, green: 0.66, blue: 0.48, alpha: 1)
                number = NSColor(calibratedRed: 0.47, green: 0.72, blue: 0.95, alpha: 1)
                keyword = NSColor(calibratedRed: 0.80, green: 0.59, blue: 0.92, alpha: 1)
                type = NSColor(calibratedRed: 0.43, green: 0.79, blue: 0.77, alpha: 1)
            } else {
                foreground = NSColor(calibratedWhite: 0.14, alpha: 1)
                comment = NSColor(calibratedRed: 0.32, green: 0.48, blue: 0.34, alpha: 1)
                string = NSColor(calibratedRed: 0.67, green: 0.30, blue: 0.12, alpha: 1)
                number = NSColor(calibratedRed: 0.12, green: 0.38, blue: 0.72, alpha: 1)
                keyword = NSColor(calibratedRed: 0.52, green: 0.20, blue: 0.68, alpha: 1)
                type = NSColor(calibratedRed: 0.06, green: 0.48, blue: 0.47, alpha: 1)
            }
        }
    }
}

public enum MarkdownRenderer {
    public static func render(_ source: String, darkMode: Bool) throws -> NSAttributedString {
        let parsed = try AttributedString(
            markdown: source,
            options: .init(interpretedSyntax: .full)
        )
        let theme = Theme(darkMode: darkMode)
        let result = NSMutableAttributedString()
        var activeBlockID: Int?
        var activeListContext: ListContext?
        var appendedBlock = false

        for run in parsed.runs {
            let components = run.presentationIntent?.components ?? []
            let block = blockStyle(from: components)
            let blockID = components.first?.identity ?? 0
            let listContext = block.listContext

            if activeBlockID != blockID {
                if appendedBlock {
                    let staysInList = activeListContext != nil && activeListContext == listContext
                    appendLineBreaks(staysInList ? 1 : 2, to: result, theme: theme)
                }
                if let prefix = block.prefix {
                    result.append(NSAttributedString(
                        string: prefix,
                        attributes: attributes(for: nil, block: block, theme: theme)
                    ))
                }
                activeBlockID = blockID
                activeListContext = listContext
                appendedBlock = true
            }

            let text = String(parsed[run.range].characters)
            result.append(NSAttributedString(
                string: text,
                attributes: attributes(
                    for: run.inlinePresentationIntent,
                    link: run.link,
                    block: block,
                    theme: theme
                )
            ))
        }

        if appendedBlock {
            appendLineBreaks(1, to: result, theme: theme)
        }
        return result
    }

    private static func blockStyle(
        from components: [PresentationIntent.IntentType]
    ) -> BlockStyle {
        guard let primary = components.first else { return .paragraph }
        switch primary.kind {
        case .header(let level):
            return .heading(level)
        case .codeBlock:
            return .codeBlock
        case .thematicBreak:
            return .thematicBreak
        default:
            break
        }

        var ordered: Bool?
        var ordinal = 1
        var containerID: Int?
        var depth = 0
        var quoted = false
        for component in components {
            switch component.kind {
            case .orderedList:
                ordered = ordered ?? true
                containerID = containerID ?? component.identity
                depth += 1
            case .unorderedList:
                ordered = ordered ?? false
                containerID = containerID ?? component.identity
                depth += 1
            case .listItem(let value):
                ordinal = value
            case .blockQuote:
                quoted = true
            default:
                break
            }
        }
        if let ordered, let containerID {
            return .listItem(
                ordered: ordered,
                ordinal: ordinal,
                depth: max(1, depth),
                containerID: containerID
            )
        }
        if quoted {
            return .quote
        }
        return .paragraph
    }

    private static func attributes(
        for inline: InlinePresentationIntent?,
        link: URL? = nil,
        block: BlockStyle,
        theme: Theme
    ) -> [NSAttributedString.Key: Any] {
        var font = block.font
        if inline?.contains(.code) == true {
            font = NSFont.monospacedSystemFont(ofSize: block.codeFontSize, weight: .regular)
        } else {
            if inline?.contains(.stronglyEmphasized) == true {
                font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
            }
            if inline?.contains(.emphasized) == true {
                font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
            }
        }

        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: link == nil ? theme.foreground : theme.link,
            .paragraphStyle: block.paragraphStyle
        ]
        if inline?.contains(.code) == true {
            attributes[.backgroundColor] = theme.codeBackground
        }
        if inline?.contains(.strikethrough) == true {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }
        if let link {
            attributes[.link] = link
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        return attributes
    }

    private static func appendLineBreaks(
        _ count: Int,
        to result: NSMutableAttributedString,
        theme: Theme
    ) {
        let existing = result.string.reversed().prefix { $0 == "\n" }.count
        guard existing < count else { return }
        result.append(NSAttributedString(
            string: String(repeating: "\n", count: count - existing),
            attributes: attributes(for: nil, block: .paragraph, theme: theme)
        ))
    }

    private struct ListContext: Equatable {
        let containerID: Int
        let depth: Int
    }

    private enum BlockStyle {
        case heading(Int)
        case paragraph
        case listItem(ordered: Bool, ordinal: Int, depth: Int, containerID: Int)
        case quote
        case codeBlock
        case thematicBreak

        var prefix: String? {
            switch self {
            case .listItem(let ordered, let ordinal, let depth, _):
                let indentation = String(repeating: "    ", count: max(0, depth - 1))
                return indentation + (ordered ? "\(ordinal). " : "• ")
            case .quote:
                return "▎ "
            case .thematicBreak:
                return "────────────────────────"
            default:
                return nil
            }
        }

        var listContext: ListContext? {
            guard case .listItem(_, _, let depth, let containerID) = self else { return nil }
            return ListContext(containerID: containerID, depth: depth)
        }

        var font: NSFont {
            switch self {
            case .heading(let level):
                let sizes: [CGFloat] = [28, 24, 20, 18, 16, 15]
                return NSFont.systemFont(ofSize: sizes[min(max(level, 1), 6) - 1], weight: .semibold)
            case .codeBlock:
                return NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            default:
                return NSFont.systemFont(ofSize: 14, weight: .regular)
            }
        }

        var codeFontSize: CGFloat {
            if case .heading(let level) = self {
                let sizes: [CGFloat] = [25, 21, 18, 16, 14, 13]
                return sizes[min(max(level, 1), 6) - 1]
            }
            return 13
        }

        var paragraphStyle: NSParagraphStyle {
            let style = NSMutableParagraphStyle()
            style.lineSpacing = 3
            switch self {
            case .listItem(_, _, let depth, _):
                style.firstLineHeadIndent = CGFloat(max(0, depth - 1) * 28)
                style.headIndent = CGFloat(depth * 28)
            case .quote:
                style.firstLineHeadIndent = 8
                style.headIndent = 22
            case .codeBlock:
                style.firstLineHeadIndent = 12
                style.headIndent = 12
            default:
                break
            }
            return style
        }
    }

    private struct Theme {
        let foreground: NSColor
        let link: NSColor
        let codeBackground: NSColor

        init(darkMode: Bool) {
            if darkMode {
                foreground = NSColor(calibratedWhite: 0.88, alpha: 1)
                link = NSColor(calibratedRed: 0.38, green: 0.68, blue: 0.98, alpha: 1)
                codeBackground = NSColor(calibratedWhite: 1, alpha: 0.10)
            } else {
                foreground = NSColor(calibratedWhite: 0.14, alpha: 1)
                link = NSColor(calibratedRed: 0.08, green: 0.36, blue: 0.78, alpha: 1)
                codeBackground = NSColor(calibratedWhite: 0, alpha: 0.07)
            }
        }
    }
}
