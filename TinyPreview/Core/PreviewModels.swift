import Foundation

public enum PreviewCategory: String, CaseIterable, Sendable {
    case text
    case sourceCode
    case image
    case archive

    public var displayName: String {
        switch self {
        case .text: "纯文本"
        case .sourceCode: "源代码"
        case .image: "图片"
        case .archive: "压缩包"
        }
    }
}

public struct PreviewLimits: Equatable, Sendable {
    public var textBytes: Int64
    public var sourceCodeBytes: Int64
    public var imageBytes: Int64
    public var archiveBytes: Int64

    public static let defaults = PreviewLimits(
        textBytes: 5 * 1_048_576,
        sourceCodeBytes: 2 * 1_048_576,
        imageBytes: 100 * 1_048_576,
        archiveBytes: 200 * 1_048_576
    )

    public static let ranges: [PreviewCategory: ClosedRange<Int64>] = [
        .text: 1 * 1_048_576 ... 50 * 1_048_576,
        .sourceCode: 1 * 1_048_576 ... 20 * 1_048_576,
        .image: 1 * 1_048_576 ... 500 * 1_048_576,
        .archive: 1 * 1_048_576 ... 2_048 * 1_048_576
    ]

    public func value(for category: PreviewCategory) -> Int64 {
        switch category {
        case .text: textBytes
        case .sourceCode: sourceCodeBytes
        case .image: imageBytes
        case .archive: archiveBytes
        }
    }

    public mutating func set(_ value: Int64, for category: PreviewCategory) {
        let range = Self.ranges[category]!
        let clamped = min(max(value, range.lowerBound), range.upperBound)
        switch category {
        case .text: textBytes = clamped
        case .sourceCode: sourceCodeBytes = clamped
        case .image: imageBytes = clamped
        case .archive: archiveBytes = clamped
        }
    }
}

public struct SafetyBudget: Equatable, Sendable {
    public let maximumEntries: Int
    public let maximumDuration: TimeInterval
    public let maximumWorkingBytes: Int64

    public static let standard = SafetyBudget(
        maximumEntries: 5_000,
        maximumDuration: 2,
        maximumWorkingBytes: 256 * 1_048_576
    )
}

public enum SourceLanguage: String, CaseIterable, Sendable {
    case swift, objectiveC, c, cpp, rust, go, python, ruby, java, kotlin
    case javascript, typescript, html, css, shell, json, yaml, toml, xml, sql, markdown

    public var displayName: String {
        switch self {
        case .swift: "Swift"
        case .objectiveC: "Objective-C"
        case .c: "C"
        case .cpp: "C++"
        case .rust: "Rust"
        case .go: "Go"
        case .python: "Python"
        case .ruby: "Ruby"
        case .java: "Java"
        case .kotlin: "Kotlin"
        case .javascript: "JavaScript"
        case .typescript: "TypeScript"
        case .html: "HTML"
        case .css: "CSS"
        case .shell: "Shell"
        case .json: "JSON"
        case .yaml: "YAML"
        case .toml: "TOML"
        case .xml: "XML"
        case .sql: "SQL"
        case .markdown: "Markdown"
        }
    }
}

public enum UnicodeTextEncoding: String, Sendable {
    case utf8 = "UTF-8"
    case utf16LittleEndian = "UTF-16 LE"
    case utf16BigEndian = "UTF-16 BE"
    case utf32LittleEndian = "UTF-32 LE"
    case utf32BigEndian = "UTF-32 BE"
}

public struct TextPreview: Sendable {
    public let text: String
    public let encoding: UnicodeTextEncoding
    public let language: SourceLanguage?

    public var wrapsLines: Bool { language == nil }
}

public struct ImagePreview: @unchecked Sendable {
    public let data: Data
    public let isSVG: Bool
    public let firstFrameOnly: Bool
    public let pixelWidth: Int
    public let pixelHeight: Int
}

public struct ContainerEntry: Identifiable, Equatable, Sendable {
    public let id: Int
    public let depth: Int
    public let name: String
    public let typeLabel: String
    public let size: Int64?
    public let isDirectory: Bool
    public let isHidden: Bool
    public let warning: String?

    public init(
        id: Int,
        depth: Int,
        name: String,
        typeLabel: String,
        size: Int64?,
        isDirectory: Bool,
        isHidden: Bool,
        warning: String? = nil
    ) {
        self.id = id
        self.depth = depth
        self.name = name
        self.typeLabel = typeLabel
        self.size = size
        self.isDirectory = isDirectory
        self.isHidden = isHidden
        self.warning = warning
    }
}

public struct ContainerPreview: Sendable {
    public let title: String
    public let entries: [ContainerEntry]
    public let knownBytes: Int64
    public let isComplete: Bool
    public let incompleteReason: String?
}

public enum PreviewMessageKind: Sendable {
    case refused
    case unsupported
    case corrupt
}

public struct PreviewMessage: Sendable {
    public let kind: PreviewMessageKind
    public let title: String
    public let detail: String
    public let fileName: String
    public let systemType: String?
    public let actualBytes: Int64?
    public let limitBytes: Int64?
}

public enum PreviewResult: @unchecked Sendable {
    case text(TextPreview)
    case image(ImagePreview)
    case container(ContainerPreview)
    case message(PreviewMessage)
}
