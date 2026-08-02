import Darwin
import Foundation
import UniformTypeIdentifiers

private let archiveOK: Int32 = 0
private let archiveEOF: Int32 = 1
private let archiveWarn: Int32 = -20
private let archiveIfmt: UInt32 = 0xF000
private let archiveIfdir: UInt32 = 0x4000
private let archiveIflnk: UInt32 = 0xA000

@_silgen_name("archive_read_new") private func archiveReadNew() -> OpaquePointer?
@_silgen_name("archive_read_support_filter_all") private func archiveReadSupportFilterAll(_ archive: OpaquePointer?) -> Int32
@_silgen_name("archive_read_support_format_all") private func archiveReadSupportFormatAll(_ archive: OpaquePointer?) -> Int32
@_silgen_name("archive_read_open_filename") private func archiveReadOpenFilename(_ archive: OpaquePointer?, _ path: UnsafePointer<CChar>?, _ blockSize: Int) -> Int32
@_silgen_name("archive_read_next_header") private func archiveReadNextHeader(_ archive: OpaquePointer?, _ entry: UnsafeMutablePointer<OpaquePointer?>) -> Int32
@_silgen_name("archive_read_data_skip") private func archiveReadDataSkip(_ archive: OpaquePointer?) -> Int32
@_silgen_name("archive_read_free") private func archiveReadFree(_ archive: OpaquePointer?) -> Int32
@_silgen_name("archive_error_string") private func archiveErrorString(_ archive: OpaquePointer?) -> UnsafePointer<CChar>?
@_silgen_name("archive_entry_pathname_utf8") private func archiveEntryPathnameUTF8(_ entry: OpaquePointer?) -> UnsafePointer<CChar>?
@_silgen_name("archive_entry_pathname") private func archiveEntryPathname(_ entry: OpaquePointer?) -> UnsafePointer<CChar>?
@_silgen_name("archive_entry_filetype") private func archiveEntryFiletype(_ entry: OpaquePointer?) -> UInt32
@_silgen_name("archive_entry_size") private func archiveEntrySize(_ entry: OpaquePointer?) -> Int64
@_silgen_name("archive_entry_size_is_set") private func archiveEntrySizeIsSet(_ entry: OpaquePointer?) -> Int32
@_silgen_name("archive_entry_is_encrypted") private func archiveEntryIsEncrypted(_ entry: OpaquePointer?) -> Int32

public enum ArchiveScanError: LocalizedError, Equatable {
    case encrypted
    case multipart
    case unreadable(String)

    public var errorDescription: String? {
        switch self {
        case .encrypted: "加密或密码压缩包暂不支持"
        case .multipart: "分卷压缩包暂不支持"
        case .unreadable(let reason): "无法读取压缩包：\(reason)"
        }
    }
}

public enum ArchiveScanner {
    private struct RawEntry {
        let components: [String]
        let size: Int64?
        let isDirectory: Bool
        let isLink: Bool
        let warning: String?
    }

    private final class Node {
        let name: String
        var children: [String: Node] = [:]
        var size: Int64?
        var isDirectory = true
        var isLink = false
        var warning: String?
        var isSynthetic = true

        init(name: String) { self.name = name }
    }

    public static func scan(
        _ url: URL,
        budget: SafetyBudget = .standard
    ) throws -> ContainerPreview {
        if isMultipart(url) { throw ArchiveScanError.multipart }
        guard let archive = archiveReadNew() else {
            throw ArchiveScanError.unreadable("无法创建解析器")
        }
        defer { _ = archiveReadFree(archive) }
        _ = archiveReadSupportFilterAll(archive)
        _ = archiveReadSupportFormatAll(archive)
        let openStatus = url.withUnsafeFileSystemRepresentation {
            archiveReadOpenFilename(archive, $0, 64 * 1_024)
        }
        guard openStatus >= archiveWarn else {
            throw mappedError(errorMessage(archive))
        }

        let started = Date()
        var rawEntries: [RawEntry] = []
        var stopReason: String?
        var entry: OpaquePointer?

        while true {
            if rawEntries.count >= budget.maximumEntries {
                stopReason = "已达到 \(budget.maximumEntries.formatted()) 项安全上限"
                break
            }
            if Date().timeIntervalSince(started) >= budget.maximumDuration {
                stopReason = "已达到 \(Int(budget.maximumDuration)) 秒处理时限"
                break
            }

            let status = archiveReadNextHeader(archive, &entry)
            if status == archiveEOF { break }
            guard status >= archiveWarn, let entry else {
                throw mappedError(errorMessage(archive))
            }
            if archiveEntryIsEncrypted(entry) != 0 {
                throw ArchiveScanError.encrypted
            }

            let originalName = entryName(entry)
            let normalized = normalizePath(originalName)
            guard !normalized.components.isEmpty else {
                _ = archiveReadDataSkip(archive)
                continue
            }
            let filetype = archiveEntryFiletype(entry) & archiveIfmt
            let isDirectory = filetype == archiveIfdir || originalName.hasSuffix("/")
            let isLink = filetype == archiveIflnk
            let size = archiveEntrySizeIsSet(entry) != 0 && !isDirectory ? max(0, archiveEntrySize(entry)) : nil
            var warning = normalized.warning
            if isLink {
                warning = [warning, "符号链接；未跟随"].compactMap { $0 }.joined(separator: "；")
            }
            rawEntries.append(RawEntry(
                components: normalized.components,
                size: size,
                isDirectory: isDirectory,
                isLink: isLink,
                warning: warning
            ))
            _ = archiveReadDataSkip(archive)
        }

        let root = Node(name: "")
        for raw in rawEntries { insert(raw, into: root) }
        var flattened: [ContainerEntry] = []
        var knownBytes: Int64 = 0
        flatten(root, depth: 0, output: &flattened, knownBytes: &knownBytes, budget: budget)
        if flattened.count >= budget.maximumEntries && stopReason == nil {
            stopReason = "已达到 \(budget.maximumEntries.formatted()) 项安全上限"
        }
        return ContainerPreview(
            title: url.lastPathComponent,
            entries: Array(flattened.prefix(budget.maximumEntries)),
            knownBytes: knownBytes,
            isComplete: stopReason == nil,
            incompleteReason: stopReason
        )
    }

    private static func insert(_ raw: RawEntry, into root: Node) {
        var node = root
        for (index, component) in raw.components.enumerated() {
            if node.children[component] == nil {
                node.children[component] = Node(name: component)
            }
            node = node.children[component]!
            if index == raw.components.count - 1 {
                node.size = raw.size
                node.isDirectory = raw.isDirectory
                node.isLink = raw.isLink
                node.warning = raw.warning
                node.isSynthetic = false
            }
        }
    }

    private static func flatten(
        _ node: Node,
        depth: Int,
        output: inout [ContainerEntry],
        knownBytes: inout Int64,
        budget: SafetyBudget
    ) {
        let children = node.children.values.sorted {
            if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        for child in children where output.count < budget.maximumEntries {
            let isHidden = child.name.hasPrefix(".")
            let packageType = child.isDirectory ? UTType(filenameExtension: URL(fileURLWithPath: child.name).pathExtension) : nil
            let isPackage = packageType?.conforms(to: .package) == true
            let typeLabel: String
            if child.isLink {
                typeLabel = "符号链接"
            } else if isPackage {
                typeLabel = packageType?.localizedDescription ?? "包"
            } else if child.isDirectory {
                typeLabel = "文件夹"
            } else {
                typeLabel = UTType(filenameExtension: URL(fileURLWithPath: child.name).pathExtension)?.localizedDescription ?? "文件"
            }
            if let size = child.size { knownBytes += size }
            output.append(ContainerEntry(
                id: output.count,
                depth: depth,
                name: child.name,
                typeLabel: typeLabel,
                size: child.size,
                isDirectory: child.isDirectory,
                isHidden: isHidden,
                warning: child.warning
            ))
            if child.isDirectory && !child.isLink && !isHidden && !isPackage {
                flatten(child, depth: depth + 1, output: &output, knownBytes: &knownBytes, budget: budget)
            }
        }
    }

    private static func entryName(_ entry: OpaquePointer) -> String {
        let pointer = archiveEntryPathnameUTF8(entry) ?? archiveEntryPathname(entry)
        guard let pointer else { return "�" }
        let utf8 = UnsafeRawPointer(pointer).assumingMemoryBound(to: UInt8.self)
        return String(decodingCString: utf8, as: UTF8.self)
    }

    private static func normalizePath(_ raw: String) -> (components: [String], warning: String?) {
        let escaped = String(raw.unicodeScalars.map { scalar in
            let value = scalar.value
            let control = value < 0x20 || (0x7F...0x9F).contains(value)
            return control ? Character("�") : Character(String(scalar))
        })
        let slashNormalized = escaped.replacingOccurrences(of: "\\", with: "/")
        var dangerous = slashNormalized.hasPrefix("/") || slashNormalized.range(of: #"^[A-Za-z]:/"#, options: .regularExpression) != nil
        var components: [String] = []
        for component in slashNormalized.split(separator: "/", omittingEmptySubsequences: true).map(String.init) {
            if component == "." { continue }
            if component == ".." {
                dangerous = true
                continue
            }
            components.append(component)
        }
        return (components, dangerous ? "危险路径已规范化" : (escaped == raw ? nil : "文件名含控制字符，已替换"))
    }

    private static func isMultipart(_ url: URL) -> Bool {
        let name = url.lastPathComponent.lowercased()
        return name.range(of: #"\.part\d+\.rar$"#, options: .regularExpression) != nil ||
            name.range(of: #"\.r\d{2,3}$"#, options: .regularExpression) != nil ||
            name.range(of: #"\.\d{3}$"#, options: .regularExpression) != nil
    }

    private static func mappedError(_ message: String) -> ArchiveScanError {
        let lowercased = message.lowercased()
        if lowercased.contains("passphrase") || lowercased.contains("password") || lowercased.contains("encrypted") {
            return .encrypted
        }
        if lowercased.contains("multi-volume") || lowercased.contains("next volume") || lowercased.contains("missing volume") {
            return .multipart
        }
        return .unreadable(message)
    }

    private static func errorMessage(_ archive: OpaquePointer) -> String {
        archiveErrorString(archive).map { String(cString: $0) } ?? "未知解析错误"
    }
}
