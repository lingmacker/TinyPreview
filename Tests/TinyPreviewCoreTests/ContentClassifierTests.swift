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

    func testSyntaxHighlighterUsesDayAndNightPalettes() throws {
        let source = "// note\nlet value: String = \"text\" + 42"
        let rendered = SyntaxHighlighter.highlight(source, language: .swift, darkMode: true)
        let string = rendered.string as NSString

        func color(of token: String) throws -> NSColor {
            let location = string.range(of: token).location
            return try XCTUnwrap(
                rendered.attribute(.foregroundColor, at: location, effectiveRange: nil) as? NSColor
            )
        }

        XCTAssertTrue(try color(of: "// note").isEqual(NSColor(hex: 0x5C6370)))
        XCTAssertTrue(try color(of: "let").isEqual(NSColor(hex: 0xC678DD)))
        XCTAssertTrue(try color(of: "value").isEqual(NSColor(hex: 0xABB2BF)))
        XCTAssertTrue(try color(of: "String").isEqual(NSColor(hex: 0xE5C07B)))
        XCTAssertTrue(try color(of: "\"text\"").isEqual(NSColor(hex: 0x98C379)))
        XCTAssertTrue(try color(of: "42").isEqual(NSColor(hex: 0xD19A66)))

        let light = SyntaxHighlighter.highlight(source, language: .swift, darkMode: false)
        let keyword = (light.attribute(.foregroundColor, at: (light.string as NSString).range(of: "let").location, effectiveRange: nil) as? NSColor)
        XCTAssertTrue(keyword?.isEqual(NSColor(hex: 0x0000FF)) == true)
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
    func testMarkdownFrontMatterUsesSmallSecondaryTextInBothThemes() throws {
        let metadata = "---\nname: 预览\ndescription: **literal**\ntags: [one, two]\n---\n"
        for darkMode in [false, true] {
            let rendered = try MarkdownRenderer.render(
                metadata + "\n# Heading\n\nBody text\n",
                darkMode: darkMode
            )
            XCTAssertEqual(rendered.string, metadata + "\nHeading\n\nBody text\n")
            let text = rendered.string as NSString
            let metadataRange = text.range(of: metadata)
            rendered.enumerateAttributes(in: metadataRange) { attributes, _, _ in
                let font = attributes[.font] as? NSFont
                XCTAssertEqual(font?.pointSize, 12)
                XCTAssertTrue(font.map {
                    NSFontManager.shared.traits(of: $0).contains(.fixedPitchFontMask)
                } ?? false)
                XCTAssertTrue((attributes[.foregroundColor] as? NSColor)?.isEqual(
                    NSColor(calibratedWhite: darkMode ? 0.65 : 0.45, alpha: 1)
                ) == true)
            }
            let headingFont = rendered.attribute(
                .font, at: text.range(of: "Heading").location, effectiveRange: nil
            ) as? NSFont
            let bodyFont = rendered.attribute(
                .font, at: text.range(of: "Body text").location, effectiveRange: nil
            ) as? NSFont
            let bodyColor = rendered.attribute(
                .foregroundColor, at: text.range(of: "Body text").location, effectiveRange: nil
            ) as? NSColor
            XCTAssertEqual(headingFont?.pointSize, 28)
            XCTAssertEqual(bodyFont?.pointSize, 14)
            XCTAssertTrue(bodyColor?.isEqual(
                NSColor(calibratedWhite: darkMode ? 0.88 : 0.14, alpha: 1)
            ) == true)
        }
    }

    func testMarkdownFrontMatterAcceptsCRLFAndEmptyMetadata() throws {
        for metadata in [
            "---\r\nname: 示例\r\n---\r\n",
            "\u{FEFF}---\nname: 示例\n---\n",
            "---\n---\n",
            "---\nname: 示例\n---"
        ] {
            let rendered = try MarkdownRenderer.render(metadata, darkMode: false)
            XCTAssertTrue(rendered.string.hasPrefix(metadata))
            let font = rendered.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
            XCTAssertEqual(font?.pointSize, 12)
        }
    }

    func testMarkdownFrontMatterDoesNotChangeBodySetextHeadingsOrUnclosedBlocks() throws {
        let heading = try MarkdownRenderer.render("Title\n---\n", darkMode: false)
        let headingFont = heading.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        XCTAssertEqual(headingFont?.pointSize, 24)
        for source in ["---\nname: example\n", "# Intro\n\n---\nname: example\n---\n"] {
            let rendered = try MarkdownRenderer.render(source, darkMode: false)
            let location = (rendered.string as NSString).range(of: "name:").location
            let font = rendered.attribute(.font, at: location, effectiveRange: nil) as? NSFont
            XCTAssertNotEqual(font?.pointSize, 12)
        }
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
