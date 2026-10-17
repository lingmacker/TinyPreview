import AppKit
import Foundation

@MainActor
final class PreviewViewModel: ObservableObject {
    enum HighlightStatus { case none, loading, ready, unavailable }

    @Published private(set) var result: PreviewResult?
    @Published private(set) var attributedText: NSAttributedString?
    @Published private(set) var highlightStatus: HighlightStatus = .none
    @Published private(set) var darkMode = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    private(set) var url: URL?
    private var generation = UUID()
    private var renderGeneration = UUID()

    func load(_ url: URL, allowPartialText: Bool = false) {
        self.url = url
        result = nil
        attributedText = nil
        highlightStatus = .none
        let token = UUID()
        generation = token
        let limits = SharedSettings.load()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let loaded = PreviewLoader.load(url, limits: limits, allowPartialText: allowPartialText)
            DispatchQueue.main.async {
                guard let self, self.generation == token else { return }
                self.result = loaded
                if case .text(let preview) = loaded {
                    self.render(preview)
                }
            }
        }
    }

    func setDarkMode(_ value: Bool) {
        guard darkMode != value else { return }
        darkMode = value
        if case .text(let preview) = result { render(preview) }
    }

    private func render(_ preview: TextPreview) {
        let darkMode = self.darkMode
        let rendersMarkdown = preview.language == .markdown && !preview.isTruncated
        let text = preview.formattedText ?? preview.text
        let code = preview.language != nil && !rendersMarkdown
        attributedText = code ? SyntaxHighlighter.plainCode(text, darkMode: darkMode) : SyntaxHighlighter.plainText(text, darkMode: darkMode)
        highlightStatus = .loading
        let token = UUID()
        renderGeneration = token
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let started = Date()
            let rendered: NSAttributedString?
            if text.utf8.count > Int(SafetyBudget.standard.maximumWorkingBytes / 32) {
                rendered = nil
            } else if rendersMarkdown {
                rendered = try? MarkdownRenderer.render(text, darkMode: darkMode)
            } else if let language = preview.language {
                rendered = SyntaxHighlighter.highlight(text, language: language, darkMode: darkMode)
            } else {
                rendered = SyntaxHighlighter.plainText(text, darkMode: darkMode)
            }
            let elapsed = Date().timeIntervalSince(started)
            DispatchQueue.main.async {
                guard let self, self.renderGeneration == token, case .text = self.result else { return }
                if let rendered, elapsed <= SafetyBudget.standard.maximumDuration {
                    self.attributedText = rendered
                    self.highlightStatus = .ready
                } else {
                    self.highlightStatus = .unavailable
                }
            }
        }
    }
}
