import AppKit
import QuickLookUI
import SwiftUI

final class PreviewViewController: NSViewController, QLPreviewingController {
    private let model = PreviewViewModel()

    override func loadView() {
        let hostingView = NSHostingView(rootView: PreviewRootView(model: model))
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        let container = NSView()
        container.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: container.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            container.widthAnchor.constraint(greaterThanOrEqualToConstant: 560),
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 420)
        ])
        view = container
        preferredContentSize = NSSize(width: 880, height: 640)
    }

    func preparePreviewOfFile(
        at url: URL,
        completionHandler handler: @escaping (Error?) -> Void
    ) {
        model.load(url)
        handler(nil)
    }
}
