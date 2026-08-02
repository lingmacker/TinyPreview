import AppKit
import Foundation

@MainActor
final class PreviewViewModel: ObservableObject {
    enum HighlightStatus {
        case none
        case loading
        case ready
        case unavailable
    }

    @Published private(set) var result: PreviewResult?
    @Published private(set) var attributedText: NSAttributedString?
    @Published private(set) var highlightStatus: HighlightStatus = .none
    private(set) var url: URL?
    private var generation = UUID()

    func load(_ url: URL) {
        self.url = url
        result = nil
        attributedText = nil
        highlightStatus = .none
        let token = UUID()
        generation = token
        let limits = SharedSettings.load()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let loaded = PreviewLoader.load(url, limits: limits)
            DispatchQueue.main.async {
                guard let self, self.generation == token else { return }
                self.result = loaded
                if case .text(let preview) = loaded, let language = preview.language {
                    self.highlightStatus = .loading
                    self.highlight(preview, language: language, token: token)
                }
            }
        }
    }

    private func highlight(_ preview: TextPreview, language: SourceLanguage, token: UUID) {
        let darkMode = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let started = Date()
            let rendered: NSAttributedString?
            if language == .markdown {
                rendered = try? MarkdownRenderer.render(preview.text, darkMode: darkMode)
            } else {
                rendered = SyntaxHighlighter.highlight(preview.text, language: language, darkMode: darkMode)
            }
            let elapsed = Date().timeIntervalSince(started)
            DispatchQueue.main.async {
                guard let self, self.generation == token else { return }
                if let rendered, elapsed <= SafetyBudget.standard.maximumDuration {
                    self.attributedText = rendered
                    self.highlightStatus = .ready
                } else {
                    self.attributedText = nil
                    self.highlightStatus = .unavailable
                }
            }
        }
    }
}
