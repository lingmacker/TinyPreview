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

}
