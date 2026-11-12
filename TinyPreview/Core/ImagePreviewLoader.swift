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
                firstFrameOnly: false
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
        let fileBytes = Int64(data.count)
        let availableBytes = budget.maximumWorkingBytes - fileBytes
        guard availableBytes > 0 else { throw ImagePreviewError.memoryBudget }

        if frameCount > 1,
           let frameBytes,
           let totalFramesBytes = multipliedWithoutOverflow(frameBytes, Int64(frameCount), 1),
           totalFramesBytes <= availableBytes,
           max(width, height) <= maximumDisplayDimension {
            // Keep the encoded data so NSImageView can play every frame.
            guard CGImageSourceCreateImageAtIndex(source, 0, nil) != nil else { throw ImagePreviewError.corrupt }
            return ImagePreview(data: data, isSVG: false, firstFrameOnly: false)
        }

        // Decode the still (or first frame) off the main thread, shrinking it when the
        // full-resolution bitmap would exceed the memory budget or any sensible display size.
        let longestSide = Double(max(width, height))
        var targetSide = min(longestSide, Double(maximumDisplayDimension))
        if let frameBytes, frameBytes > availableBytes {
            targetSide = min(targetSide, longestSide * (Double(availableBytes) / Double(frameBytes)).squareRoot())
        } else if frameBytes == nil {
            targetSide = min(targetSide, (Double(availableBytes) / 4).squareRoot())
        }
        let maximumPixelSize = Int(targetSide.rounded(.down))
        guard maximumPixelSize >= 1 else { throw ImagePreviewError.memoryBudget }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw ImagePreviewError.corrupt
        }
        guard Int64(image.width) * Int64(image.height) * 4 <= availableBytes else {
            throw ImagePreviewError.memoryBudget
        }
        // Report the original pixel dimensions so 100% zoom keeps its meaning after downsampling;
        // swap them when the EXIF orientation rotated the decoded image by 90°.
        let rotated = width != height && image.width != image.height && (image.width > image.height) != (width > height)
        return ImagePreview(
            data: data,
            isSVG: false,
            firstFrameOnly: frameCount > 1,
            stillImage: image,
            displaySize: rotated ? CGSize(width: height, height: width) : CGSize(width: width, height: height),
            isDownsampled: maximumPixelSize < Int(longestSide)
        )
    }

    private static let maximumDisplayDimension = 8_192

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
