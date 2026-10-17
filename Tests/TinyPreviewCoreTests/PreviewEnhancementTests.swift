import AppKit
import Foundation
import XCTest

final class PreviewEnhancementTests: XCTestCase {
    func testJSONFormattingPreservesTokensAndRejectsInvalidInput() throws {
        let source = #"{"large":9007199254740993,"exponent":1.2300e+20,"s":"a\\\"b","empty":[]}"#
        let formatted = try StructuredPreview.json(source)
        XCTAssertTrue(formatted.contains("9007199254740993"))
        XCTAssertTrue(formatted.contains("1.2300e+20"))
        XCTAssertTrue(formatted.contains("\n"))
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: Data(formatted.utf8)))
        XCTAssertThrowsError(try StructuredPreview.json("{broken"))
        XCTAssertThrowsError(try StructuredPreview.json(source, maximumBytes: 8))
    }

    func testCSVAndTSVAreUnsupportedInsteadOfFallingBackToText() throws {
        for ext in ["csv", "CSV", "tsv", "TSV"] {
            try withFile(Data("name,note\nAlice,\"unfinished".utf8), extension: ext) { url in
                XCTAssertEqual(try ContentClassifier.classify(url).content, .unsupported)
                guard case .message(let message) = PreviewLoader.load(url, allowPartialText: true) else {
                    return XCTFail("CSV/TSV must not enter text preview")
                }
                XCTAssertEqual(message.kind, .unsupported)
                XCTAssertFalse(message.canPreviewPrefix)
            }
        }
    }

    func testBinaryPlistLoadsAsXMLWithoutChangingTheFile() throws {
        let data = try PropertyListSerialization.data(fromPropertyList: ["name": "Tiny", "count": 3], format: .binary, options: 0)
        try withFile(data, extension: "plist") { url in
            guard case .text(let preview) = PreviewLoader.load(url, limits: .defaults) else { return XCTFail("Expected XML text") }
            XCTAssertEqual(preview.language, .xml)
            XCTAssertTrue(preview.text.contains("<key>name</key>"))
            XCTAssertTrue(preview.notice?.contains("二进制") == true)
            XCTAssertEqual(try Data(contentsOf: url), data)
        }
    }

    func testJSONLoaderFormatsContent() throws {
        try withFile(Data("{\"n\":1}".utf8), extension: "json") { url in
            guard case .text(let value) = PreviewLoader.load(url, limits: .defaults) else { return XCTFail() }
            XCTAssertNotNil(value.formattedText)
            XCTAssertEqual(value.text, "{\"n\":1}")
        }
    }

    func testLargeTextRequiresExplicitPartialPreviewAndTrimsIncompleteScalar() throws {
        var data = Data(repeating: 0x61, count: 1_048_575)
        data.append(Data("你好".utf8))
        try withFile(data, extension: "swift") { url in
            var limits = PreviewLimits.defaults
            limits.set(1_048_576, for: .sourceCode)
            guard case .message(let refusal) = PreviewLoader.load(url, limits: limits) else { return XCTFail("Expected refusal") }
            XCTAssertTrue(refusal.canPreviewPrefix)
            guard case .text(let prefix) = PreviewLoader.load(url, limits: limits, allowPartialText: true) else { return XCTFail("Expected prefix") }
            XCTAssertTrue(prefix.isTruncated)
            XCTAssertEqual(prefix.text.utf8.count, 1_048_575)
            XCTAssertNotNil(prefix.notice)
        }
        XCTAssertNil(UnicodeTextDecoder.decodePrefix(Data([0x61, 0, 0x62, 0x63, 0x64, 0x65])))
        XCTAssertEqual(UnicodeTextDecoder.decodePrefix(Data([0x61, 0xE4]))?.0, "a")
        XCTAssertNil(UnicodeTextDecoder.decodePrefix(Data([0x61, 0])))
        let utf16 = Data([0xFF, 0xFE, 0x61, 0, 0x3D, 0xD8, 0x00])
        XCTAssertEqual(UnicodeTextDecoder.decodePrefix(utf16)?.0, "a")
    }

    func testMarkdownFencedCodeUsesSyntaxColors() throws {
        let value = try MarkdownRenderer.render("```swift\nlet value = 42\n```", darkMode: false)
        let keyword = (value.string as NSString).range(of: "let")
        let number = (value.string as NSString).range(of: "42")
        XCTAssertNotEqual(keyword.location, NSNotFound)
        XCTAssertNotEqual(number.location, NSNotFound)
        XCTAssertNotEqual(value.attribute(.foregroundColor, at: keyword.location, effectiveRange: nil) as? NSColor,
                          value.attribute(.foregroundColor, at: number.location, effectiveRange: nil) as? NSColor)
    }

    func testContainerListingPreservesScanOrderPathsAndHiddenEntries() {
        let rows = ContainerListing.rows(listingFixture())
        XCTAssertEqual(rows.map(\.relativePath), ["src", "src/main.swift", ".secret", ".secret/token", "z.txt", "small.txt"])
        XCTAssertEqual(rows.map(\.id), [0, 1, 2, 3, 4, 5])
        XCTAssertEqual(rows.map(\.hasChildren), [true, false, true, false, false, false])
        XCTAssertEqual(ContainerListing.rows([]).count, 0)
    }

    func testContainerCollapseOnlyHidesDescendantsOfCollapsedDirectories() {
        let entries = listingFixture()
        XCTAssertEqual(ContainerListing.rows(entries, collapsed: [0]).map(\.relativePath),
                       ["src", ".secret", ".secret/token", "z.txt", "small.txt"])
        XCTAssertEqual(ContainerListing.rows(entries, collapsed: [0, 2]).map(\.id), [0, 2, 4, 5])
        XCTAssertEqual(ContainerListing.rows(entries, collapsed: [999]).count, entries.count)
    }

    func testRasterImageLoadsWithoutChangingData() throws {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 4, pixelsHigh: 3, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let data = bitmap.representation(using: .png, properties: [:])!
        let value = try ImagePreviewLoader.load(data: data, isSVG: false)
        XCTAssertEqual(value.data, data)
        XCTAssertFalse(value.isSVG)
        XCTAssertFalse(value.firstFrameOnly)
        let budget = SafetyBudget(maximumEntries: 5_000, maximumDuration: 2, maximumWorkingBytes: Int64(data.count + 47))
        XCTAssertThrowsError(try ImagePreviewLoader.load(data: data, isSVG: false, budget: budget)) { error in
            guard case ImagePreviewError.memoryBudget = error else { return XCTFail("Image memory limits must remain enforced") }
        }
    }

    func testPlistExpansionIsBounded() throws {
        let data = try PropertyListSerialization.data(fromPropertyList: Array(repeating: "xxxxxxxxxx", count: 1_000), format: .binary, options: 0)
        XCTAssertThrowsError(try StructuredPreview.propertyList(data, maximumBytes: 4_096))
    }

    private func listingFixture() -> [ContainerEntry] {
        [
            ContainerEntry(id: 0, depth: 0, name: "src", typeLabel: "目录", size: nil, isDirectory: true, isHidden: false),
            ContainerEntry(id: 1, depth: 1, name: "main.swift", typeLabel: "Swift", size: 30, isDirectory: false, isHidden: false),
            ContainerEntry(id: 2, depth: 0, name: ".secret", typeLabel: "目录", size: nil, isDirectory: true, isHidden: true),
            ContainerEntry(id: 3, depth: 1, name: "token", typeLabel: "文件", size: 20, isDirectory: false, isHidden: false),
            ContainerEntry(id: 4, depth: 0, name: "z.txt", typeLabel: "文本", size: 80, isDirectory: false, isHidden: false),
            ContainerEntry(id: 5, depth: 0, name: "small.txt", typeLabel: "文本", size: 5, isDirectory: false, isHidden: false)
        ]
    }

    private func withFile(_ data: Data, extension ext: String, body: (URL) throws -> Void) throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        try body(url)
    }
}
