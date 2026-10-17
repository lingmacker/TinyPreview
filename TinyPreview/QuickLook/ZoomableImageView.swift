import AppKit
import ImageIO
import SwiftUI

struct ZoomableImageView: NSViewRepresentable {
    let preview: ImagePreview

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> ImageScrollView {
        let scrollView = ImageScrollView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 0.02
        scrollView.maxMagnification = 8
        scrollView.contentView = CenteringClipView()
        update(scrollView, coordinator: context.coordinator)
        return scrollView
    }

    func updateNSView(_ scrollView: ImageScrollView, context: Context) {
        update(scrollView, coordinator: context.coordinator)
    }

    private func update(_ scrollView: ImageScrollView, coordinator: Coordinator) {
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .windowBackgroundColor
        let hash = preview.data.hashValue ^ (preview.firstFrameOnly ? 1 : 0)
        guard coordinator.lastHash != hash else { return }
        coordinator.lastHash = hash
        guard let image = makeImage() else { return }

        scrollView.documentView = CheckerboardImageCanvas(image: image)
        scrollView.imageSize = image.size
        DispatchQueue.main.async { scrollView.fitImage() }
    }

    private func makeImage() -> NSImage? {
        if preview.firstFrameOnly,
           let source = CGImageSourceCreateWithData(preview.data as CFData, nil),
           let first = CGImageSourceCreateImageAtIndex(source, 0, nil) {
            return NSImage(cgImage: first, size: NSSize(width: first.width, height: first.height))
        }
        return NSImage(data: preview.data)
    }

    final class Coordinator {
        var lastHash: Int?
    }
}

private final class CheckerboardImageCanvas: NSView {
    private let imageView: NSImageView
    private static let checkerboard = NSColor(patternImage: NSImage(size: NSSize(width: 20, height: 20), flipped: false) { rect in
        NSColor(calibratedWhite: 0.88, alpha: 1).setFill()
        rect.fill()
        NSColor(calibratedWhite: 0.78, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: 10, height: 10).fill()
        NSRect(x: 10, y: 10, width: 10, height: 10).fill()
        return true
    })

    init(image: NSImage) {
        imageView = NSImageView(frame: NSRect(origin: .zero, size: image.size))
        super.init(frame: NSRect(origin: .zero, size: image.size))
        wantsLayer = true
        imageView.image = image
        imageView.imageScaling = .scaleNone
        imageView.imageAlignment = .alignCenter
        imageView.animates = true
        imageView.frame = bounds
        imageView.autoresizingMask = [.width, .height]
        addSubview(imageView)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let area = dirtyRect.intersection(bounds)
        guard !area.isEmpty, area.width.isFinite, area.height.isFinite else { return }
        Self.checkerboard.setFill()
        area.fill()
    }
}

private final class CenteringClipView: NSClipView {
    override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
        var constrained = super.constrainBoundsRect(proposedBounds)
        guard let documentView else { return constrained }
        if documentView.frame.width < proposedBounds.width {
            constrained.origin.x = (documentView.frame.width - proposedBounds.width) / 2
        }
        if documentView.frame.height < proposedBounds.height {
            constrained.origin.y = (documentView.frame.height - proposedBounds.height) / 2
        }
        return constrained
    }
}

final class ImageScrollView: NSScrollView {
    var imageSize: NSSize = .zero { didSet { needsInitialFit = true; needsLayout = true } }
    private var needsInitialFit = true
    private var fittedMagnification: CGFloat = 1
    private var dragOrigin: NSPoint?
    private var scrollOrigin: NSPoint?

    override func layout() {
        super.layout()
        if needsInitialFit { fitImage() }
    }

    func fitImage() {
        guard imageSize.width > 0, imageSize.height > 0 else { return }
        let available = contentSize
        guard available.width > 0, available.height > 0 else { return }
        needsInitialFit = false
        fittedMagnification = min(
            available.width / imageSize.width,
            available.height / imageSize.height,
            1
        )
        minMagnification = min(0.02, fittedMagnification)
        setMagnification(fittedMagnification, centeredAt: NSPoint(x: imageSize.width / 2, y: imageSize.height / 2))
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            let target: CGFloat = abs(magnification - fittedMagnification) < 0.01 ? 1 : fittedMagnification
            setMagnification(target, centeredAt: documentVisibleRect.center)
            return
        }
        dragOrigin = convert(event.locationInWindow, from: nil)
        scrollOrigin = contentView.bounds.origin
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragOrigin, let scrollOrigin else {
            super.mouseDragged(with: event)
            return
        }
        let current = convert(event.locationInWindow, from: nil)
        let delta = NSPoint(x: current.x - dragOrigin.x, y: current.y - dragOrigin.y)
        contentView.scroll(to: NSPoint(x: scrollOrigin.x - delta.x, y: scrollOrigin.y + delta.y))
        reflectScrolledClipView(contentView)
    }

    override func mouseUp(with event: NSEvent) {
        dragOrigin = nil
        scrollOrigin = nil
        super.mouseUp(with: event)
    }
}

private extension NSRect {
    var center: NSPoint { NSPoint(x: midX, y: midY) }
}
