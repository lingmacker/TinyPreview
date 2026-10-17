import AppKit
import Foundation
import XCTest
@testable import TinyPreviewCore

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

    func testCSVSupportsQuotedSeparatorsEscapedQuotesAndMultilineFields() throws {
        let csv = "name,note\r\nAlice,\"one,two\"\r\nBob,\"a\"\"b\nc\"\r\n"
        let result = try DelimitedTextParser.parse(csv, separator: ",")
        XCTAssertEqual(result.rows, [["name", "note"], ["Alice", "one,two"], ["Bob", "a\"b\nc"]])
        XCTAssertEqual(result.columnCount, 2)
        XCTAssertFalse(result.isTruncated)
    }

    func testDelimitedLimitsAndMalformedInput() throws {
        XCTAssertEqual(try DelimitedTextParser.parse("a\tb\t", separator: "\t").rows, [["a", "b", ""]])
        XCTAssertEqual(try DelimitedTextParser.parse("", separator: ",").rows, [])
        XCTAssertThrowsError(try DelimitedTextParser.parse("a,\"unfinished", separator: ","))
        XCTAssertThrowsError(try DelimitedTextParser.parse("\"a\"x,b", separator: ","))
        let result = try DelimitedTextParser.parse(String(repeating: "a,b\n", count: 1_001), separator: ",")
        XCTAssertEqual(result.rows.count, 1_000)
        XCTAssertTrue(result.isTruncated)
        XCTAssertThrowsError(try DelimitedTextParser.parse(String(repeating: "x,", count: 100) + "x", separator: ","))
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

    func testStructuredLoadersAndMalformedFallback() throws {
        try withFile(Data("{\"n\":1}".utf8), extension: "json") { url in
            guard case .text(let value) = PreviewLoader.load(url, limits: .defaults) else { return XCTFail() }
            XCTAssertNotNil(value.formattedText)
            XCTAssertEqual(value.text, "{\"n\":1}")
        }
        try withFile(Data("a,\"broken".utf8), extension: "csv") { url in
            guard case .text(let value) = PreviewLoader.load(url, limits: .defaults) else { return XCTFail("Expected raw fallback") }
            XCTAssertNotNil(value.notice)
        }
        try withFile(Data("a\tb\n1\t2".utf8), extension: "tsv") { url in
            guard case .delimited(let value) = PreviewLoader.load(url, limits: .defaults) else { return XCTFail("Expected table") }
            XCTAssertEqual(value.rows, [["a", "b"], ["1", "2"]])
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

    func testImageMetadataReportsFormatSizeAndAlpha() throws {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 4, pixelsHigh: 3, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let data = bitmap.representation(using: .png, properties: [:])!
        let value = try ImagePreviewLoader.load(data: data, isSVG: false)
        XCTAssertEqual(value.formatName, "PNG")
        XCTAssertEqual(value.pixelWidth, 4)
        XCTAssertEqual(value.pixelHeight, 3)
        XCTAssertEqual(value.hasAlpha, true)
        XCTAssertEqual(value.data.count, data.count)
    }

    func testPlistExpansionAndCSVCellBudgetAreBounded() throws {
        let data = try PropertyListSerialization.data(fromPropertyList: Array(repeating: "xxxxxxxxxx", count: 1_000), format: .binary, options: 0)
        XCTAssertThrowsError(try StructuredPreview.propertyList(data, maximumBytes: 4_096))
        let budget = SafetyBudget(maximumEntries: 4, maximumDuration: 2, maximumWorkingBytes: 1_048_576)
        let table = try DelimitedTextParser.parse("a,b\nc,d\ne,f", separator: ",", budget: budget)
        XCTAssertEqual(table.rows, [["a", "b"], ["c", "d"]])
        XCTAssertTrue(table.isTruncated)
    }

    func testOverBudgetCSVDoesNotOfferAnUnusablePrefixAction() throws {
        try withFile(Data("a,b\nc,d".utf8), extension: "csv") { url in
            let budget = SafetyBudget(maximumEntries: 5_000, maximumDuration: 2, maximumWorkingBytes: 16)
            guard case .message(let result) = PreviewLoader.load(url, limits: .defaults, budget: budget) else { return XCTFail("Expected refusal") }
            XCTAssertEqual(result.kind, .refused)
            XCTAssertFalse(result.canPreviewPrefix)
        }
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
