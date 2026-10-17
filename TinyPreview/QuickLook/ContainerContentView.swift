import AppKit
import SwiftUI

struct ContainerContentView: View {
    let preview: ContainerPreview
    @State private var collapsed: Set<Int> = []

    private var rows: [ContainerRow] {
        ContainerListing.rows(preview.entries, collapsed: collapsed)
    }

    var body: some View {
        VStack(spacing: 0) {
            let visible = rows
            if visible.isEmpty {
                ContentUnavailableView("清单为空", systemImage: "folder", description: Text("没有可显示的内容；扫描状态见下方。"))
            } else {
                ScrollView([.vertical, .horizontal]) {
                    LazyVStack(spacing: 0) {
                        ForEach(visible) { row in
                            entryRow(row)
                            Divider().padding(.leading, CGFloat(row.entry.depth) * 18 + 44)
                        }
                    }
                    .frame(minWidth: 560).padding(.vertical, 4)
                }
            }
            Divider()
            if !preview.isComplete {
                Label("清单不完整：\(preview.incompleteReason ?? "扫描提前结束")", systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(10)
            }
            Text("显示 \(visible.count.formatted()) / 已扫描 \(preview.entries.count.formatted()) 项 · 右键复制名称或相对路径")
                .font(.caption).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading).padding(10)
        }
    }

    private func entryRow(_ row: ContainerRow) -> some View {
        let entry = row.entry
        return HStack(spacing: 8) {
            if row.hasChildren {
                Button {
                    if !collapsed.insert(entry.id).inserted { collapsed.remove(entry.id) }
                } label: {
                    Image(systemName: !collapsed.contains(entry.id) ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold)).frame(width: 14, height: 24)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(collapsed.contains(entry.id) ? "展开" : "折叠") \(entry.name)")
            } else { Color.clear.frame(width: 14, height: 24) }
            Image(systemName: entry.isDirectory ? "folder.fill" : "doc")
                .foregroundStyle(entry.isDirectory ? Color.accentColor : .secondary).frame(width: 18)
            Text(entry.name).lineLimit(1).help(row.relativePath)
            if let warning = entry.warning {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange).help(warning)
            }
            Spacer(minLength: 20)
            Text(entry.typeLabel).foregroundStyle(.secondary).frame(width: 130, alignment: .leading)
            Text(entry.size.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "—")
                .foregroundStyle(.secondary).monospacedDigit().frame(width: 90, alignment: .trailing)
        }
        .font(.system(size: 12.5))
        .padding(.leading, CGFloat(min(entry.depth, 32)) * 18 + 12).padding(.trailing, 16).frame(height: 30)
        .foregroundStyle(entry.isHidden ? .secondary : .primary)
        .contentShape(Rectangle())
        .contextMenu {
            Button("复制名称") { copy(entry.name) }
            Button("复制相对路径") { copy(row.relativePath) }
        }
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

}
