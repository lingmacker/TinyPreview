import AppKit
import SwiftUI

@main
struct PreviewInteractionChecks {
    @MainActor static func main() throws {
        setbuf(stdout, nil)
        let watchdog = DispatchWorkItem { fputs("UI checks exceeded 45 seconds\n", stderr); exit(1) }
        DispatchQueue.global().asyncAfter(deadline: .now() + 45, execute: watchdog)
        defer { watchdog.cancel() }
        NSApplication.shared.setActivationPolicy(.accessory)
        let output = URL(fileURLWithPath: ".build/preview-checks", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try checkImageZoom()
        try capturePreviews(in: output)
        print("PASS: content-only text previews, automatic Markdown/JSON rendering, metadata-free image previews, zoom and preview captures.")
    }

    @MainActor private static func check(_ value: @autoclosure () -> Bool, _ message: String) throws {
        if !value() { throw NSError(domain: "PreviewInteractionChecks", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }

    @MainActor private static func pump(_ seconds: TimeInterval = 0.15) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    @MainActor private static func host<V: View>(_ view: V, width: CGFloat = 880, height: CGFloat = 640) -> (NSWindow, NSHostingView<V>) {
        let window = NSWindow(contentRect: NSRect(x: -10_000, y: -10_000, width: width, height: height),
                              styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .aqua)
        let hosting = NSHostingView(rootView: view)
        window.contentView = hosting
        window.orderFront(nil)
        pump()
        hosting.layoutSubtreeIfNeeded()
        return (window, hosting)
    }

    @MainActor private static func descendants(_ view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap(descendants)
    }

    @MainActor private static func checkImageZoom() throws {
        let svg = Data(##"<svg xmlns="http://www.w3.org/2000/svg" width="160" height="120"><circle cx="80" cy="60" r="35" fill="#F5C842"/></svg>"##.utf8)
        print("Loading SVG fixture…")
        let preview = try ImagePreviewLoader.load(data: svg, isSVG: true)
        print("Hosting image canvas…")
        let (imageWindow, imageHost) = host(ZoomableImageView(preview: preview))
        print("Checking image zoom preservation…")
        defer { imageWindow.close() }
        guard let scroll = descendants(imageHost).compactMap({ $0 as? ImageScrollView }).first else { throw CocoaError(.coderInvalidValue) }
        scroll.magnification = 1.75
        imageHost.rootView = ZoomableImageView(preview: preview)
        pump()
        try check(abs(scroll.magnification - 1.75) < 0.01, "View updates must preserve image zoom")
        guard let canvas = scroll.documentView,
              let bitmap = canvas.bitmapImageRepForCachingDisplay(in: canvas.bounds) else { throw CocoaError(.coderInvalidValue) }
        canvas.cacheDisplay(in: canvas.bounds, to: bitmap)
        let scale = CGFloat(bitmap.pixelsWide) / canvas.bounds.width
        let first = bitmap.colorAt(x: Int(4 * scale), y: Int(4 * scale))?.usingColorSpace(.deviceRGB)
        let second = bitmap.colorAt(x: Int(14 * scale), y: Int(4 * scale))?.usingColorSpace(.deviceRGB)
        try check(abs((first?.redComponent ?? 0) - (second?.redComponent ?? 0)) > 0.05, "Transparent image areas must use a checkerboard by default")
        let unlaidOut = ImageScrollView(frame: .zero)
        unlaidOut.imageSize = NSSize(width: 160, height: 120)
        unlaidOut.fitImage()
        try check(unlaidOut.magnification > 0, "A zero-sized initial viewport must never produce zero magnification")
    }

    @MainActor private static func rasterFixture(_ type: NSBitmapImageRep.FileType) throws -> Data {
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1280, pixelsHigh: 960, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
            let context = NSGraphicsContext(bitmapImageRep: bitmap) else { throw CocoaError(.coderInvalidValue) }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        NSColor.systemYellow.setFill()
        NSRect(x: 0, y: 0, width: 1280, height: 960).fill()
        NSColor.systemBlue.setFill()
        NSRect(x: 320, y: 240, width: 640, height: 480).fill()
        NSGraphicsContext.restoreGraphicsState()
        guard let data = bitmap.representation(using: type, properties: [.compressionFactor: 0.85]) else { throw CocoaError(.coderInvalidValue) }
        return data
    }

    @MainActor private static func capturePreviews(in output: URL) throws {
        let fixtures = output.appendingPathComponent("fixtures", isDirectory: true)
        try FileManager.default.createDirectory(at: fixtures.appendingPathComponent("folder/src"), withIntermediateDirectories: true)
        try Data("let value = 42\n".utf8).write(to: fixtures.appendingPathComponent("folder/src/main.swift"))
        try Data("hidden".utf8).write(to: fixtures.appendingPathComponent("folder/.env"))
        let samples: [(String, Data)] = [
            ("sample.json", Data(#"{"name":"TinyPreview","count":9007199254740993,"enabled":true,"items":["text","archive","image"]}"#.utf8)),
            ("sample.md", Data("# TinyPreview\n\nRead-only **Markdown** preview.\n\n| Format | Status |\n| --- | --- |\n| JSON | Ready |\n\n```swift\nlet value = 42\nprint(value)\n```\n".utf8)),
            ("sample.svg", Data(##"<svg xmlns="http://www.w3.org/2000/svg" width="320" height="240"><circle cx="160" cy="120" r="80" fill="#F5C842"/></svg>"##.utf8)),
            ("sample.png", try rasterFixture(.png)),
            ("sample.jpg", try rasterFixture(.jpeg)),
            ("large.txt", Data(String(repeating: "Preview content — 你好。\n", count: 70_000).utf8))
        ]
        for (name, data) in samples { try data.write(to: fixtures.appendingPathComponent(name)) }
        let limited = FolderScanner.scan(fixtures.appendingPathComponent("folder"), budget: SafetyBudget(
            maximumEntries: 1, maximumDuration: 2, maximumWorkingBytes: SafetyBudget.standard.maximumWorkingBytes
        ))
        try check(!limited.isComplete && limited.incompleteReason != nil, "A bounded scan must retain its incomplete reason")
        let (warningWindow, warningHost) = host(ContainerContentView(preview: limited).background(Color(nsColor: .windowBackgroundColor)), width: 560, height: 420)
        defer { warningWindow.close() }
        if let bitmap = warningHost.bitmapImageRepForCachingDisplay(in: warningHost.bounds) {
            warningHost.cacheDisplay(in: warningHost.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("folder-incomplete.png"))
        }
        for name in ["sample.json", "sample.md", "sample.svg", "sample.png", "sample.jpg", "folder", "large.txt"] {
            print("Capturing \(name)…")
            let model = PreviewViewModel()
            model.load(fixtures.appendingPathComponent(name), allowPartialText: name == "large.txt")
            let deadline = Date().addingTimeInterval(8)
            while (model.result == nil || model.highlightStatus == .loading) && Date() < deadline { pump(0.03) }
            try check(model.result != nil, "Preview must finish loading: \(name)")
            if name == "sample.json", case .text(let preview) = model.result {
                try check(preview.formattedText != nil && model.attributedText?.string == preview.formattedText, "JSON should format automatically")
                try check(model.attributedText?.string.contains("9007199254740993") == true, "JSON numeric tokens must remain intact")
            }
            if name == "sample.md" {
                try check(model.attributedText?.string.hasPrefix("TinyPreview\n") == true, "Markdown should render automatically without a mode picker")
            }
            for (label, width, height) in [("regular", CGFloat(880), CGFloat(640)), ("compact", CGFloat(560), CGFloat(420)), ("dark", CGFloat(880), CGFloat(640))] {
                let (window, hosting) = host(PreviewRootView(model: model), width: width, height: height)
                defer { window.close() }
                if label == "dark" { window.appearance = NSAppearance(named: .darkAqua) }
                pump()
                while model.highlightStatus == .loading && Date() < deadline { pump(0.03) }
                try check(model.darkMode == (label == "dark"), "Text colors must follow the preview window")
                hosting.layoutSubtreeIfNeeded()
                if case .text(let preview) = model.result {
                    let children = descendants(hosting)
                    try check(!children.contains { $0 is NSButton || $0 is NSSegmentedControl || $0 is NSTextField }, "Text previews must not contain a toolbar or input controls")
                    guard let reader = children.compactMap({ $0 as? NSTextView }).first,
                          let scroll = reader.enclosingScrollView else { throw CocoaError(.coderInvalidValue) }
                    try check(!reader.isEditable && reader.isSelectable, "Preview must remain read-only and selectable")
                    try check(!reader.usesFindBar && !reader.usesFindPanel, "Text search must remain disabled")
                    if preview.notice == nil && model.highlightStatus == .ready {
                        let visible = scroll.convert(scroll.bounds, to: hosting)
                        try check(abs(visible.height - hosting.bounds.height) < 1, "Text content must use the full height without a duplicate title or toolbar")
                    }
                }
                if case .image = model.result {
                    guard let scroll = descendants(hosting).compactMap({ $0 as? ImageScrollView }).first else { throw CocoaError(.coderInvalidValue) }
                    let region = scroll.convert(scroll.bounds, to: hosting)
                    try check(abs(region.height - hosting.bounds.height) < 1, "Image canvas must use the full height without a top information bar")
                    try check(!descendants(hosting).contains { $0 is NSSegmentedControl || $0 is NSPopUpButton }, "Image background switching must be removed")
                    let corner = NSPoint(x: hosting.bounds.maxX - 24, y: hosting.isFlipped ? hosting.bounds.maxY - 24 : hosting.bounds.minY + 24)
                    let target = hosting.hitTest(corner)
                    try check(target === scroll || target?.isDescendant(of: scroll) == true, "The full image canvas must remain interactive")
                }
                if case .container = model.result {
                    let children = descendants(hosting)
                    try check(!children.contains { $0 is NSTextField || $0 is NSPopUpButton || $0 is NSSegmentedControl }, "Container previews must not contain filter, visibility or sorting controls")
                    guard let scroll = children.compactMap({ $0 as? NSScrollView }).first else { throw CocoaError(.coderInvalidValue) }
                    let region = scroll.convert(scroll.bounds, to: hosting)
                    let topInset = hosting.isFlipped ? region.minY - hosting.bounds.minY : hosting.bounds.maxY - region.maxY
                    try check(abs(topInset) < 1, "Container content must begin at the top without summary or toolbar")
                }
                guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { throw CocoaError(.coderInvalidValue) }
                hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
                if case .image(let preview) = model.result, !preview.firstFrameOnly {
                    let (bareWindow, bareHost) = host(ZoomableImageView(preview: preview).background(Color(nsColor: .windowBackgroundColor)), width: width, height: height)
                    defer { bareWindow.close() }
                    if label == "dark" { bareWindow.appearance = NSAppearance(named: .darkAqua) }
                    pump()
                    guard let bareBitmap = bareHost.bitmapImageRepForCachingDisplay(in: bareHost.bounds) else { throw CocoaError(.coderInvalidValue) }
                    bareHost.cacheDisplay(in: bareHost.bounds, to: bareBitmap)
                    try check(bitmap.representation(using: .png, properties: [:]) == bareBitmap.representation(using: .png, properties: [:]),
                        "Image previews must match the bare canvas without a metadata overlay")
                }
                try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("\(name)-\(label).png"))
            }
        }
    }
}
