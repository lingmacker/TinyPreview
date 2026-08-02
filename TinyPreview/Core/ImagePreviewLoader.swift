import AppKit
import Foundation
import ImageIO

public enum ImagePreviewError: LocalizedError {
    case corrupt
    case memoryBudget

    public var errorDescription: String? {
        switch self {
        case .corrupt: "图片内容损坏或无法解码"
        case .memoryBudget: "解码图片会超过 256 MB 安全预算"
        }
    }
}

public enum ImagePreviewLoader {
    public static func load(
        data: Data,
        isSVG: Bool,
        budget: SafetyBudget = .standard
    ) throws -> ImagePreview {
        if isSVG {
            guard SVGValidator.isValid(data), NSImage(data: data) != nil else {
                throw ImagePreviewError.corrupt
            }
            guard Int64(data.count) <= budget.maximumWorkingBytes else {
                throw ImagePreviewError.memoryBudget
            }
            return ImagePreview(
                data: data,
                isSVG: true,
                firstFrameOnly: false,
                pixelWidth: 0,
                pixelHeight: 0
            )
        }

        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = integer(properties[kCGImagePropertyPixelWidth]),
              let height = integer(properties[kCGImagePropertyPixelHeight]),
              width > 0, height > 0 else {
            throw ImagePreviewError.corrupt
        }

        let frameCount = max(1, CGImageSourceGetCount(source))
        let frameBytes = multipliedWithoutOverflow(Int64(width), Int64(height), 4)
        guard let frameBytes else { throw ImagePreviewError.memoryBudget }
        let totalFramesBytes = multipliedWithoutOverflow(frameBytes, Int64(frameCount), 1)
        let fileBytes = Int64(data.count)
        let firstFrameWorkingSet = fileBytes.addingReportingOverflow(frameBytes)
        guard !firstFrameWorkingSet.overflow, firstFrameWorkingSet.partialValue <= budget.maximumWorkingBytes else {
            throw ImagePreviewError.memoryBudget
        }
        let totalWorkingSet = totalFramesBytes.map { fileBytes.addingReportingOverflow($0) }
        let firstFrameOnly = frameCount > 1 && (
            totalWorkingSet == nil ||
            totalWorkingSet!.overflow ||
            totalWorkingSet!.partialValue > budget.maximumWorkingBytes
        )

        guard CGImageSourceCreateImageAtIndex(source, 0, nil) != nil else {
            throw ImagePreviewError.corrupt
        }
        return ImagePreview(
            data: data,
            isSVG: false,
            firstFrameOnly: firstFrameOnly,
            pixelWidth: width,
            pixelHeight: height
        )
    }

    private static func integer(_ value: Any?) -> Int? {
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? Int { return value }
        return nil
    }

    private static func multipliedWithoutOverflow(_ lhs: Int64, _ rhs: Int64, _ extra: Int64) -> Int64? {
        let first = lhs.multipliedReportingOverflow(by: rhs)
        guard !first.overflow else { return nil }
        let second = first.partialValue.multipliedReportingOverflow(by: extra)
        return second.overflow ? nil : second.partialValue
    }
}

private final class SVGValidator: NSObject, XMLParserDelegate {
    private var sawSVGRoot = false
    private var sawRoot = false

    static func isValid(_ data: Data) -> Bool {
        let delegate = SVGValidator()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldProcessNamespaces = true
        parser.shouldReportNamespacePrefixes = false
        parser.shouldResolveExternalEntities = false
        return parser.parse() && delegate.sawSVGRoot
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        guard !sawRoot else { return }
        sawRoot = true
        sawSVGRoot = elementName.lowercased() == "svg"
        if !sawSVGRoot { parser.abortParsing() }
    }

    func parser(
        _ parser: XMLParser,
        resolveExternalEntityName name: String,
        systemID: String?
    ) -> Data? {
        nil
    }
}
