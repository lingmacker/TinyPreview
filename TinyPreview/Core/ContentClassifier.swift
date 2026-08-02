import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum ClassifiedContent: Equatable, Sendable {
    case folder
    case archive
    case image(isSVG: Bool)
    case source(SourceLanguage)
    case text
    case unsupported
}

public struct Classification: Equatable, Sendable {
    public let content: ClassifiedContent
    public let fileSize: Int64?
    public let systemType: String?
}

public enum ContentClassifier {
    private static let sniffBytes = 262_144

    public static func classify(_ url: URL) throws -> Classification {
        let values = try url.resourceValues(forKeys: [
            .isDirectoryKey,
            .isPackageKey,
            .isSymbolicLinkKey,
            .fileSizeKey,
            .contentTypeKey
        ])
        let fileSize = values.fileSize.map(Int64.init)
        let systemType = values.contentType?.identifier

        if values.isDirectory == true {
            if values.isPackage == true {
                return Classification(content: .unsupported, fileSize: nil, systemType: systemType)
            }
            return Classification(content: .folder, fileSize: nil, systemType: systemType)
        }

        let prefix = try readPrefix(of: url, maximumBytes: sniffBytes)
        if isArchive(prefix, url: url) {
            return Classification(content: .archive, fileSize: fileSize, systemType: systemType)
        }
        if isSVG(prefix) {
            return Classification(content: .image(isSVG: true), fileSize: fileSize, systemType: systemType)
        }
        if isSystemImage(prefix, systemType: values.contentType) {
            return Classification(content: .image(isSVG: false), fileSize: fileSize, systemType: systemType)
        }
        if let language = SourceLanguageDetector.detect(url: url, prefix: prefix) {
            return Classification(content: .source(language), fileSize: fileSize, systemType: systemType)
        }
        return Classification(content: .text, fileSize: fileSize, systemType: systemType)
    }

    public static func readPrefix(of url: URL, maximumBytes: Int) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        return try handle.read(upToCount: maximumBytes) ?? Data()
    }

    private static func isArchive(_ data: Data, url: URL) -> Bool {
        let bytes = [UInt8](data.prefix(512))
        func starts(_ signature: [UInt8]) -> Bool {
            bytes.count >= signature.count && Array(bytes.prefix(signature.count)) == signature
        }
        if starts([0x50, 0x4B, 0x03, 0x04]) ||
            starts([0x50, 0x4B, 0x05, 0x06]) ||
            starts([0x50, 0x4B, 0x07, 0x08]) ||
            starts([0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C]) ||
            starts([0x52, 0x61, 0x72, 0x21, 0x1A, 0x07]) ||
            starts([0x1F, 0x8B]) ||
            starts([0x42, 0x5A, 0x68]) ||
            starts([0xFD, 0x37, 0x7A, 0x58, 0x5A, 0x00]) {
            return true
        }
        if bytes.count >= 262, String(bytes: bytes[257..<262], encoding: .ascii) == "ustar" {
            return true
        }
        let name = url.lastPathComponent.lowercased()
        return [".tar", ".tgz", ".tar.gz", ".tbz2", ".tar.bz2", ".txz", ".tar.xz", ".7z", ".rar", ".zip"].contains { name.hasSuffix($0) }
    }

    private static func isSVG(_ data: Data) -> Bool {
        guard !data.isEmpty else { return false }
        let decoded: String?
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            decoded = String(data: data.dropFirst(3), encoding: .utf8)
        } else if data.starts(with: [0xFF, 0xFE]) {
            decoded = String(data: data, encoding: .utf16LittleEndian)
        } else if data.starts(with: [0xFE, 0xFF]) {
            decoded = String(data: data, encoding: .utf16BigEndian)
        } else {
            decoded = String(data: data, encoding: .utf8)
        }
        guard let decoded else { return false }
        let head = decoded.prefix(16_384).lowercased()
        return head.range(of: #"<svg(?:\s|>)"#, options: .regularExpression) != nil
    }

    private static func isSystemImage(_ data: Data, systemType: UTType?) -> Bool {
        if systemType == .pdf { return false }
        if let source = CGImageSourceCreateWithData(data as CFData, nil),
           let identifier = CGImageSourceGetType(source) as String?,
           identifier != UTType.pdf.identifier,
           UTType(identifier)?.conforms(to: .image) == true {
            return true
        }
        return systemType?.conforms(to: .image) == true && systemType != .svg
    }
}

public enum SourceLanguageDetector {
    private static let extensions: [String: SourceLanguage] = [
        "swift": .swift,
        "m": .objectiveC, "mm": .objectiveC,
        "c": .c, "h": .c,
        "cc": .cpp, "cpp": .cpp, "cxx": .cpp, "hpp": .cpp, "hh": .cpp,
        "rs": .rust,
        "go": .go,
        "py": .python, "pyw": .python,
        "rb": .ruby,
        "java": .java,
        "kt": .kotlin, "kts": .kotlin,
        "js": .javascript, "mjs": .javascript, "cjs": .javascript, "jsx": .javascript,
        "ts": .typescript, "tsx": .typescript,
        "html": .html, "htm": .html,
        "css": .css,
        "sh": .shell, "bash": .shell, "zsh": .shell, "fish": .shell,
        "json": .json, "jsonc": .json,
        "yaml": .yaml, "yml": .yaml,
        "toml": .toml,
        "xml": .xml, "plist": .xml, "xhtml": .xml,
        "sql": .sql,
        "md": .markdown, "markdown": .markdown, "mdown": .markdown
    ]

    private static let knownNames: [String: SourceLanguage] = [
        "Podfile": .ruby,
        "Gemfile": .ruby,
        "Rakefile": .ruby,
        "Package.swift": .swift,
        "Package.resolved": .json,
        "package.json": .json,
        "tsconfig.json": .json,
        "Cargo.toml": .toml
    ]

    public static func detect(url: URL, prefix: Data) -> SourceLanguage? {
        let name = url.lastPathComponent
        if let language = knownNames[name] { return language }
        let ext = url.pathExtension.lowercased()
        if let language = extensions[ext] { return language }

        guard let firstLine = String(data: prefix.prefix(512), encoding: .utf8)?
            .split(whereSeparator: \ .isNewline)
            .first
            .map(String.init), firstLine.hasPrefix("#!") else { return nil }
        let shebang = firstLine.lowercased()
        if shebang.contains("python") { return .python }
        if shebang.contains("ruby") { return .ruby }
        if shebang.contains("node") || shebang.contains("deno") { return .javascript }
        if shebang.contains("bash") || shebang.contains("zsh") || shebang.contains("/sh") || shebang.contains("fish") { return .shell }
        return nil
    }
}

public enum UnicodeTextDecoder {
    public static func decode(_ data: Data) -> (String, UnicodeTextEncoding)? {
        let decoded: (String, UnicodeTextEncoding)?
        if data.starts(with: [0x00, 0x00, 0xFE, 0xFF]) {
            decoded = String(data: data, encoding: .utf32BigEndian).map { ($0, .utf32BigEndian) }
        } else if data.starts(with: [0xFF, 0xFE, 0x00, 0x00]) {
            decoded = String(data: data, encoding: .utf32LittleEndian).map { ($0, .utf32LittleEndian) }
        } else if data.starts(with: [0xFE, 0xFF]) {
            decoded = String(data: data, encoding: .utf16BigEndian).map { ($0, .utf16BigEndian) }
        } else if data.starts(with: [0xFF, 0xFE]) {
            decoded = String(data: data, encoding: .utf16LittleEndian).map { ($0, .utf16LittleEndian) }
        } else {
            let payload = data.starts(with: [0xEF, 0xBB, 0xBF]) ? data.dropFirst(3) : data[...]
            decoded = String(data: payload, encoding: .utf8).map { ($0, .utf8) }
        }
        guard let pair = decoded else { return nil }
        var text = pair.0
        let encoding = pair.1
        if text.first == "\u{FEFF}" { text.removeFirst() }
        guard isPlainText(text) else { return nil }
        return (text, encoding)
    }

    private static func isPlainText(_ text: String) -> Bool {
        var controls = 0
        var total = 0
        for scalar in text.unicodeScalars {
            total += 1
            let value = scalar.value
            if value == 0 { return false }
            let isControl = (value < 0x20 && ![0x09, 0x0A, 0x0C, 0x0D].contains(value)) || (0x7F...0x9F).contains(value)
            if isControl { controls += 1 }
        }
        guard total > 0 else { return true }
        return Double(controls) / Double(total) <= 0.01
    }
}
