import AppKit
import SwiftUI

struct SelectableTextView: NSViewRepresentable {
    let attributedText: NSAttributedString
    let wrapsLines: Bool
    let showsLineNumbers: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = !wrapsLines
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor

        let textView = NSTextView(frame: .zero)
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.allowsUndo = false
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: 14, height: 12)
        textView.usesFindPanel = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticTextCompletionEnabled = false
        scrollView.documentView = textView
        context.coordinator.textView = textView
        configure(textView, in: scrollView)
        updateText(textView, coordinator: context.coordinator)
        configureRuler(scrollView, textView: textView, coordinator: context.coordinator)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }
        scrollView.hasHorizontalScroller = !wrapsLines
        configure(textView, in: scrollView)
        updateText(textView, coordinator: context.coordinator)
        configureRuler(scrollView, textView: textView, coordinator: context.coordinator)
    }

    private func configure(_ textView: NSTextView, in scrollView: NSScrollView) {
        if wrapsLines {
            textView.isHorizontallyResizable = false
            textView.autoresizingMask = [.width]
            textView.textContainer?.widthTracksTextView = true
            textView.textContainer?.containerSize = NSSize(
                width: max(1, scrollView.contentSize.width),
                height: .greatestFiniteMagnitude
            )
        } else {
            textView.isHorizontallyResizable = true
            textView.autoresizingMask = []
            textView.textContainer?.widthTracksTextView = false
            textView.textContainer?.containerSize = NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
        }
        textView.isVerticallyResizable = true
        textView.minSize = NSSize(width: 0, height: scrollView.contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
    }

    private func updateText(_ textView: NSTextView, coordinator: Coordinator) {
        let hash = attributedText.hash
        guard coordinator.lastHash != hash else { return }
        coordinator.lastHash = hash
        textView.textStorage?.setAttributedString(attributedText)
        coordinator.ruler?.updateLineStarts(for: attributedText.string)
    }

    private func configureRuler(_ scrollView: NSScrollView, textView: NSTextView, coordinator: Coordinator) {
        if showsLineNumbers {
            if coordinator.ruler == nil {
                coordinator.ruler = LineNumberRulerView(textView: textView)
            }
            scrollView.verticalRulerView = coordinator.ruler
            scrollView.hasVerticalRuler = true
            scrollView.rulersVisible = true
            coordinator.ruler?.updateLineStarts(for: attributedText.string)
        } else {
            scrollView.rulersVisible = false
            scrollView.hasVerticalRuler = false
            scrollView.verticalRulerView = nil
        }
    }

    final class Coordinator {
        weak var textView: NSTextView?
        var ruler: LineNumberRulerView?
        var lastHash: Int?
    }
}

final class LineNumberRulerView: NSRulerView {
    private weak var textView: NSTextView?
    private var lineStarts: [Int] = [0]

    init(textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 46
        textView.enclosingScrollView?.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(needsDisplayAfterScroll),
            name: NSView.boundsDidChangeNotification,
            object: textView.enclosingScrollView?.contentView
        )
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit { NotificationCenter.default.removeObserver(self) }

    func updateLineStarts(for text: String) {
        lineStarts = [0]
        let utf16 = Array(text.utf16)
        for (index, value) in utf16.enumerated() where value == 10 {
            lineStarts.append(index + 1)
        }
        needsDisplay = true
    }

    @objc private func needsDisplayAfterScroll() { needsDisplay = true }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard
            let textView,
            let layoutManager = textView.layoutManager,
            let textContainer = textView.textContainer,
            let scrollView = textView.enclosingScrollView
        else { return }

        NSColor.controlBackgroundColor.setFill()
        bounds.fill()
        let visible = scrollView.contentView.bounds
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visible, in: textContainer)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor
        ]

        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { [weak self] _, usedRect, _, lineGlyphRange, _ in
            guard let self else { return }
            let characterIndex = layoutManager.characterIndexForGlyph(at: lineGlyphRange.location)
            let line = self.lineNumber(containing: characterIndex)
            let label = "\(line)" as NSString
            let size = label.size(withAttributes: attributes)
            let pointInText = NSPoint(
                x: 0,
                y: usedRect.minY + textView.textContainerInset.height
            )
            let point = self.convert(pointInText, from: textView)
            label.draw(
                at: NSPoint(x: self.ruleThickness - size.width - 9, y: point.y),
                withAttributes: attributes
            )
        }
    }

    private func lineNumber(containing characterIndex: Int) -> Int {
        var low = 0
        var high = lineStarts.count
        while low < high {
            let middle = (low + high) / 2
            if lineStarts[middle] <= characterIndex {
                low = middle + 1
            } else {
                high = middle
            }
        }
        return max(1, low)
    }
}
