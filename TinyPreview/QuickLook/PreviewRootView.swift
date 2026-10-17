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
        .onChange(of: colorScheme, initial: true) { _, value in model.setDarkMode(value == .dark) }
    }

    @ViewBuilder
    private func content(_ result: PreviewResult) -> some View {
        switch result {
        case .text(let preview):
            TextContentView(preview: preview, model: model)
        case .image(let preview):
            ImageContentView(preview: preview)
        case .container(let preview):
            ContainerContentView(preview: preview)
        case .message(let message):
            MessageContentView(message: message) {
                if let url = model.url { model.load(url, allowPartialText: true) }
            }
        }
    }
}

private struct MessageContentView: View {
    let message: PreviewMessage
    let previewPrefix: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: icon).font(.system(size: 42, weight: .regular)).foregroundStyle(tint)
            VStack(spacing: 6) {
                Text(message.title).font(.title2.weight(.semibold))
                Text(message.fileName).font(.headline).lineLimit(2)
                Text(message.detail).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 480)
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
            if message.canPreviewPrefix {
                Button("仅预览开头", action: previewPrefix).buttonStyle(.borderedProminent)
                Text("仅读取受限片段，不会调高上限，也不会修改原文件。").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(32).frame(maxWidth: .infinity, maxHeight: .infinity)
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
