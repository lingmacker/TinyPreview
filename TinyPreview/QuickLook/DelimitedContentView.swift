import AppKit
import SwiftUI

struct DelimitedContentView: View {
    let preview: DelimitedPreview

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "tablecells")
                Spacer()
                Text("已显示 \(preview.rows.count.formatted()) 行 · \(preview.columnCount) 列")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16).frame(height: 46).background(.bar)
            if let notice = preview.notice {
                Label(notice, systemImage: "info.circle").font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(12)
            }
            if preview.rows.isEmpty {
                ContentUnavailableView("没有记录", systemImage: "tablecells", description: Text("文件为空，没有可显示的单元格。"))
            } else {
                DelimitedTableView(preview: preview)
            }
            Divider()
            Text("点击单元格后按 ⌘C，或右键复制单元格。首行保留为原始记录，不自动作为表头。")
                .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(10)
        }
    }
}

struct DelimitedTableView: NSViewRepresentable {
    let preview: DelimitedPreview

    func makeCoordinator() -> Coordinator { Coordinator(preview: preview) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = true
        let table = CellCopyTableView()
        table.dataSource = context.coordinator
        table.delegate = context.coordinator
        table.usesAlternatingRowBackgroundColors = true
        table.columnAutoresizingStyle = .noColumnAutoresizing
        table.rowHeight = 36
        table.allowsMultipleSelection = false
        table.setAccessibilityLabel("只读数据表格")
        table.onCopy = { [weak coordinator = context.coordinator] row, column in
            guard let coordinator, coordinator.preview.rows.indices.contains(row), column >= 0 else { return }
            let cells = coordinator.preview.rows[row]
            let value = column < cells.count ? cells[column] : ""
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(value, forType: .string)
        }
        scroll.documentView = table
        updateNSView(scroll, context: context)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let table = scroll.documentView as? NSTableView else { return }
        context.coordinator.preview = preview
        if table.tableColumns.count != preview.columnCount {
            for column in table.tableColumns { table.removeTableColumn(column) }
            for index in 0..<preview.columnCount {
                let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(String(index)))
                column.title = "列 \(index + 1)"
                column.width = 160
                column.minWidth = 80
                column.resizingMask = .userResizingMask
                table.addTableColumn(column)
            }
        }
        table.reloadData()
    }

    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        var preview: DelimitedPreview
        init(preview: DelimitedPreview) { self.preview = preview }
        func numberOfRows(in tableView: NSTableView) -> Int { preview.rows.count }
        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard let column = tableColumn, let index = Int(column.identifier.rawValue) else { return nil }
            let field = tableView.makeView(withIdentifier: column.identifier, owner: self) as? NSTextField ?? NSTextField(labelWithString: "")
            field.identifier = column.identifier
            field.maximumNumberOfLines = 2
            field.lineBreakMode = .byTruncatingTail
            field.font = .systemFont(ofSize: 12.5)
            let cells = preview.rows[row]
            field.stringValue = index < cells.count ? cells[index] : ""
            field.toolTip = field.stringValue
            return field
        }
    }
}

final class CellCopyTableView: NSTableView {
    var onCopy: ((Int, Int) -> Void)?
    private var cellColumn = 0

    override func mouseDown(with event: NSEvent) {
        cellColumn = column(at: convert(event.locationInWindow, from: nil))
        super.mouseDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.intersection([.command, .option, .control, .shift]) == .command,
           event.charactersIgnoringModifiers?.lowercased() == "c" {
            copyCell(nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.intersection([.command, .option, .control, .shift]) == .command,
           event.charactersIgnoringModifiers?.lowercased() == "c" {
            copyCell(nil)
        } else { super.keyDown(with: event) }
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let point = convert(event.locationInWindow, from: nil)
        let row = row(at: point)
        cellColumn = column(at: point)
        guard row >= 0, cellColumn >= 0 else { return nil }
        selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        let menu = NSMenu()
        let item = NSMenuItem(title: "复制单元格", action: #selector(copyCell(_:)), keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        return menu
    }

    @objc func copyCell(_ sender: Any?) { onCopy?(selectedRow, cellColumn) }
}
