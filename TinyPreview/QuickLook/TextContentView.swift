import SwiftUI

struct TextContentView: View {
    let preview: TextPreview
    @ObservedObject var model: PreviewViewModel

    private var isCode: Bool {
        preview.language != nil && (preview.language != .markdown || preview.isTruncated)
    }

    var body: some View {
        VStack(spacing: 0) {
            if model.highlightStatus == .unavailable {
                Label("渲染或高亮不可用，显示未处理内容。", systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                Divider()
            }
            if let notice = preview.notice {
                Label(notice, systemImage: preview.isTruncated ? "doc.badge.ellipsis" : "info.circle")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16).padding(.vertical, 8)
                Divider()
            }
            SelectableTextView(
                attributedText: model.attributedText ?? SyntaxHighlighter.plainText(preview.text, darkMode: model.darkMode),
                wrapsLines: preview.wrapsLines, showsLineNumbers: isCode,
                style: isCode ? .code(darkMode: model.darkMode) : .system
            )
        }
    }
}
