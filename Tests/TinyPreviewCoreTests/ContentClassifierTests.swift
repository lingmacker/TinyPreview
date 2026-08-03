import AppKit
import Foundation
import XCTest
@testable import TinyPreviewCore

final class ContentClassifierTests: XCTestCase {
    func testUnicodeTextDecoderAcceptsExtensionlessUTF8() {
        let result = UnicodeTextDecoder.decode(Data("hello, 世界\n".utf8))
        XCTAssertEqual(result?.0, "hello, 世界\n")
        XCTAssertEqual(result?.1, .utf8)
    }

    func testUnicodeTextDecoderRejectsNULAndExcessControls() {
        XCTAssertNil(UnicodeTextDecoder.decode(Data([0x41, 0x00, 0x42])))
        XCTAssertNil(UnicodeTextDecoder.decode(Data([0x41, 0x01, 0x42])))
    }

    func testLanguageDetectionUsesReliableSignalsOnly() {
        XCTAssertEqual(
            SourceLanguageDetector.detect(
                url: URL(fileURLWithPath: "/tmp/example.swift"),
                prefix: Data("let value = 1".utf8)
            ),
            .swift
        )
        XCTAssertEqual(
            SourceLanguageDetector.detect(
                url: URL(fileURLWithPath: "/tmp/example.cts"),
                prefix: Data("export const value = 1".utf8)
            ),
            .typescript
        )
        XCTAssertEqual(
            SourceLanguageDetector.detect(
                url: URL(fileURLWithPath: "/tmp/example.mts"),
                prefix: Data("export const value = 1".utf8)
            ),
            .typescript
        )
        XCTAssertNil(
            SourceLanguageDetector.detect(
                url: URL(fileURLWithPath: "/tmp/example.unknown"),
                prefix: Data("let value = 1".utf8)
            )
        )
    }

    func testImageContentWinsOverSourceExtension() throws {
        let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=")!
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".swift")
        try png.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let result = try ContentClassifier.classify(url)
        XCTAssertEqual(result.content, .image(isSVG: false))
    }

    func testPreviewLimitsClampToCategoryRanges() {
        var limits = PreviewLimits.defaults
        limits.set(.max, for: .sourceCode)
        XCTAssertEqual(limits.sourceCodeBytes, 20 * 1_048_576)
        limits.set(0, for: .text)
        XCTAssertEqual(limits.textBytes, 1 * 1_048_576)
    }

    func testSyntaxHighlighterUsesDraculaPalette() throws {
        let source = "// note\nlet value: String = \"text\" + 42"
        let rendered = SyntaxHighlighter.highlight(source, language: .swift)
        let string = rendered.string as NSString

        func color(of token: String) throws -> NSColor {
            let location = string.range(of: token).location
            return try XCTUnwrap(
                rendered.attribute(.foregroundColor, at: location, effectiveRange: nil) as? NSColor
            )
        }

        XCTAssertTrue(try color(of: "// note").isEqual(DraculaTheme.comment))
        XCTAssertTrue(try color(of: "let").isEqual(DraculaTheme.pink))
        XCTAssertTrue(try color(of: "value").isEqual(DraculaTheme.foreground))
        XCTAssertTrue(try color(of: "String").isEqual(DraculaTheme.cyan))
        XCTAssertTrue(try color(of: "\"text\"").isEqual(DraculaTheme.yellow))
        XCTAssertTrue(try color(of: "42").isEqual(DraculaTheme.purple))
    }

    func testMarkdownRendererProducesStyledDocument() throws {
        let rendered = try MarkdownRenderer.render(
            "# Heading\n\n- **first**\n- second with `code`\n",
            darkMode: false
        )

        XCTAssertEqual(rendered.string, "Heading\n\n• first\n• second with code\n")
        XCTAssertFalse(rendered.string.contains("# Heading"))
        XCTAssertFalse(rendered.string.contains("**first**"))

        let string = rendered.string as NSString
        let headingFont = try XCTUnwrap(
            rendered.attribute(.font, at: string.range(of: "Heading").location, effectiveRange: nil) as? NSFont
        )
        let bodyFont = try XCTUnwrap(
            rendered.attribute(.font, at: string.range(of: "second").location, effectiveRange: nil) as? NSFont
        )
        XCTAssertGreaterThan(headingFont.pointSize, bodyFont.pointSize)

        let boldFont = try XCTUnwrap(
            rendered.attribute(.font, at: string.range(of: "first").location, effectiveRange: nil) as? NSFont
        )
        XCTAssertTrue(NSFontManager.shared.traits(of: boldFont).contains(.boldFontMask))

        let codeFont = try XCTUnwrap(
            rendered.attribute(.font, at: string.range(of: "code").location, effectiveRange: nil) as? NSFont
        )
        XCTAssertTrue(NSFontManager.shared.traits(of: codeFont).contains(.fixedPitchFontMask))
    }
    func testMarkdownRendererRendersPipeTableAsRowsAndColumns() throws {
        let rendered = try MarkdownRenderer.render(
            """
            | Name | Value |
            | --- | ---: |
            | Alpha | 10 |
            """,
            darkMode: false
        )
        let textStorage = NSTextStorage(attributedString: rendered)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(
            size: NSSize(width: 600, height: CGFloat.greatestFiniteMagnitude)
        )
        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)
        layoutManager.ensureLayout(for: textContainer)

        func bounds(of text: String) throws -> NSRect {
            let characterRange = (rendered.string as NSString).range(of: text)
            let glyphRange = layoutManager.glyphRange(
                forCharacterRange: characterRange,
                actualCharacterRange: nil
            )
            return layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        }

        let name = try bounds(of: "Name")
        let value = try bounds(of: "Value")
        let alpha = try bounds(of: "Alpha")
        let number = try bounds(of: "10")
        XCTAssertEqual(name.minY, value.minY, accuracy: 1)
        XCTAssertGreaterThan(value.minX, name.maxX)
        XCTAssertGreaterThan(alpha.minY, name.maxY)
        XCTAssertEqual(alpha.minY, number.minY, accuracy: 1)
        XCTAssertGreaterThan(number.minX, alpha.maxX)
    }


}
