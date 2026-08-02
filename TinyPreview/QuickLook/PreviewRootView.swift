import SwiftUI

struct PreviewRootView: View {
    @ObservedObject var model: PreviewViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if let result = model.result {
                content(result)
            } else {
                ProgressView("正在准备预览…")
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private func content(_ result: PreviewResult) -> some View {
        switch result {
        case .text(let preview):
            textView(preview)
        case .image(let preview):
            imageView(preview)
        case .container(let preview):
            ContainerContentView(preview: preview)
        case .message(let message):
            MessageContentView(message: message)
        }
    }

    private func textView(_ preview: TextPreview) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: preview.language == nil ? "doc.plaintext" : "chevron.left.forwardslash.chevron.right")
                Text(model.url?.lastPathComponent ?? "文本")
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(preview.language?.displayName ?? preview.encoding.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if model.highlightStatus == .unavailable {
                    Label("高亮不可用", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 46)
            .background(.bar)

            SelectableTextView(
                attributedText: model.attributedText ?? SyntaxHighlighter.plainText(
                    preview.text,
                    darkMode: colorScheme == .dark
                ),
                wrapsLines: preview.wrapsLines,
                showsLineNumbers: preview.language != nil
            )
        }
    }

    private func imageView(_ preview: ImagePreview) -> some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "photo")
                Text(model.url?.lastPathComponent ?? "图片")
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                if preview.pixelWidth > 0 {
                    Text("\(preview.pixelWidth) × \(preview.pixelHeight)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if preview.firstFrameOnly {
                    Label("仅显示首帧", systemImage: "pause.circle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 46)
            .background(.bar)
            ZoomableImageView(preview: preview)
        }
    }
}

private struct ContainerContentView: View {
    let preview: ContainerPreview

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "shippingbox")
                VStack(alignment: .leading, spacing: 2) {
                    Text(preview.title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(preview.isComplete ? Color.secondary : Color.orange)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(.bar)

            ScrollView([.vertical, .horizontal]) {
                LazyVStack(spacing: 0) {
                    ForEach(preview.entries) { entry in
                        ContainerEntryRow(entry: entry)
                        Divider().padding(.leading, CGFloat(entry.depth) * 18 + 44)
                    }
                }
                .frame(minWidth: 560)
                .padding(.vertical, 4)
            }
        }
    }

    private var summary: String {
        let bytes = ByteCountFormatter.string(fromByteCount: preview.knownBytes, countStyle: .file)
        let base = "已列出 \(preview.entries.count.formatted()) 项，已知大小 \(bytes)"
        if let reason = preview.incompleteReason { return "\(base) · 清单不完整：\(reason)" }
        return base
    }
}

private struct ContainerEntryRow: View {
    let entry: ContainerEntry

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: entry.isDirectory ? "folder.fill" : "doc")
                .foregroundStyle(entry.isDirectory ? Color.accentColor : .secondary)
                .frame(width: 18)
            Text(entry.name)
                .lineLimit(1)
            if let warning = entry.warning {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .help(warning)
            }
            Spacer(minLength: 20)
            Text(entry.typeLabel)
                .foregroundStyle(.secondary)
                .frame(width: 130, alignment: .leading)
            Text(entry.size.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "—")
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 90, alignment: .trailing)
        }
        .font(.system(size: 12.5))
        .padding(.leading, CGFloat(entry.depth) * 18 + 12)
        .padding(.trailing, 16)
        .frame(height: 30)
        .opacity(entry.isHidden ? 0.62 : 1)
    }
}

private struct MessageContentView: View {
    let message: PreviewMessage

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: icon)
                .font(.system(size: 42, weight: .regular))
                .foregroundStyle(tint)
            VStack(spacing: 6) {
                Text(message.title)
                    .font(.title2.weight(.semibold))
                Text(message.fileName)
                    .font(.headline)
                    .lineLimit(2)
                Text(message.detail)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 480)
            }
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 7) {
                if let type = message.systemType {
                    GridRow { Text("系统类型").foregroundStyle(.secondary); Text(type).textSelection(.enabled) }
                }
                if let actual = message.actualBytes {
                    GridRow { Text("文件大小").foregroundStyle(.secondary); Text(ByteCountFormatter.string(fromByteCount: actual, countStyle: .file)) }
                }
                if let limit = message.limitBytes {
                    GridRow { Text("当前上限").foregroundStyle(.secondary); Text(ByteCountFormatter.string(fromByteCount: limit, countStyle: .file)) }
                }
            }
            .font(.callout)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var icon: String {
        switch message.kind {
        case .refused: "gauge.with.dots.needle.50percent"
        case .unsupported: "questionmark.square.dashed"
        case .corrupt: "exclamationmark.triangle"
        }
    }

    private var tint: Color {
        switch message.kind {
        case .refused: .orange
        case .unsupported: .secondary
        case .corrupt: .red
        }
    }
}
