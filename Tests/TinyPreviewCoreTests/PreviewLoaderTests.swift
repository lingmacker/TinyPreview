import Foundation
import XCTest
@testable import TinyPreviewCore

final class PreviewLoaderTests: XCTestCase {
    func testArbitraryExtensionUnicodeTextPreviews() throws {
        let url = temporaryURL(extension: "mystery")
        try Data("plain text without a known suffix".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        guard case .text(let preview) = PreviewLoader.load(url) else {
            return XCTFail("Expected a text preview")
        }
        XCTAssertEqual(preview.text, "plain text without a known suffix")
        XCTAssertNil(preview.language)
    }

    func testSourceFileOverCategoryLimitIsRefused() throws {
        let url = temporaryURL(extension: "swift")
        try Data(repeating: 0x20, count: 1_048_577).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        var limits = PreviewLimits.defaults
        limits.set(1_048_576, for: .sourceCode)

        guard case .message(let message) = PreviewLoader.load(url, limits: limits) else {
            return XCTFail("Expected a refusal")
        }
        XCTAssertEqual(message.kind, .refused)
        XCTAssertEqual(message.limitBytes, 1_048_576)
    }

    func testSVGIsValidatedAsImage() throws {
        let svg = Data(#"<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><rect width="10" height="10" fill="red"/></svg>"#.utf8)
        let preview = try ImagePreviewLoader.load(data: svg, isSVG: true)
        XCTAssertTrue(preview.isSVG)
    }

    func testFolderScannerShowsHiddenDirectoryWithoutDescendants() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent(".git"), withIntermediateDirectories: true)
        try Data("secret".utf8).write(to: root.appendingPathComponent(".git/config"))
        try Data("visible".utf8).write(to: root.appendingPathComponent("README"))
        defer { try? FileManager.default.removeItem(at: root) }

        let preview = FolderScanner.scan(root)
        XCTAssertEqual(preview.entries.map(\.name), [".git", "README"])
        XCTAssertFalse(preview.entries.contains { $0.name == "config" })
    }

    func testArchiveScannerReadsTarIndexWithoutExtracting() throws {
        let url = temporaryURL(extension: "tar")
        try makeTar(path: "src/main.swift", contents: Data("let value = 1\n".utf8)).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let preview = try ArchiveScanner.scan(url)
        XCTAssertEqual(preview.entries.map(\.name), ["src", "main.swift"])
        XCTAssertEqual(preview.entries.last?.depth, 1)
        XCTAssertEqual(preview.knownBytes, 14)
    }

    func testSharedSettingsRoundTripAndReset() {
        let original = SharedSettings.load()
        defer { XCTAssertTrue(SharedSettings.save(original)) }

        let expected = PreviewLimits(
            textBytes: 6 * 1_048_576,
            sourceCodeBytes: 3 * 1_048_576,
            imageBytes: 120 * 1_048_576,
            archiveBytes: 240 * 1_048_576
        )
        XCTAssertTrue(SharedSettings.save(expected))
        XCTAssertEqual(SharedSettings.load(), expected)

        XCTAssertTrue(SharedSettings.reset())
        XCTAssertEqual(SharedSettings.load(), .defaults)
    }

    func testTypeScriptSourceLoadsAsHighlightedText() throws {
        let url = temporaryURL(extension: "ts")
        try Data("interface User { name: string }\nconst user: User = { name: \"Tiny\" }\n".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        guard case .text(let preview) = PreviewLoader.load(url) else {
            return XCTFail("Expected a TypeScript text preview")
        }
        XCTAssertEqual(preview.language, .typescript)
        XCTAssertFalse(preview.wrapsLines)
    }

    private func temporaryURL(extension ext: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
    }

    private func makeTar(path: String, contents: Data) -> Data {
        var header = Data(repeating: 0, count: 512)
        write(path, into: &header, at: 0, length: 100)
        write("0000644\0", into: &header, at: 100, length: 8)
        write("0000000\0", into: &header, at: 108, length: 8)
        write("0000000\0", into: &header, at: 116, length: 8)
        write(String(format: "%011o\0", contents.count), into: &header, at: 124, length: 12)
        write("00000000000\0", into: &header, at: 136, length: 12)
        for index in 148 ..< 156 { header[index] = 0x20 }
        header[156] = Character("0").asciiValue!
        write("ustar\0", into: &header, at: 257, length: 6)
        write("00", into: &header, at: 263, length: 2)
        let checksum = header.reduce(0) { $0 + Int($1) }
        write(String(format: "%06o\0 ", checksum), into: &header, at: 148, length: 8)

        var tar = header
        tar.append(contents)
        let padding = (512 - contents.count % 512) % 512
        tar.append(Data(repeating: 0, count: padding + 1_024))
        return tar
    }

    private func write(_ string: String, into data: inout Data, at offset: Int, length: Int) {
        let bytes = Array(string.utf8.prefix(length))
        data.replaceSubrange(offset ..< offset + bytes.count, with: bytes)
    }
}
