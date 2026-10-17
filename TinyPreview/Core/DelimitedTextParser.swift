import Foundation

public enum DelimitedTextParser {
    public static func parse(_ text: String, separator: Character, budget: SafetyBudget = .standard) throws -> DelimitedPreview {
        let delimiter: UInt8 = separator == "\t" ? 9 : 44
        let bytes = Array(text.utf8)
        var rows: [[String]] = []
        var row: [String] = []
        var field: [UInt8] = []
        var quoted = false
        var closedQuote = false
        var fieldStarted = false
        var index = 0
        var cells = 0
        let started = Date()
        let maximumCells = min(20_000, budget.maximumEntries)
        let maximumFieldBytes = min(65_536, Int(max(0, budget.maximumWorkingBytes / 8)))

        func finishField() throws {
            guard row.count < 100 else { throw failure("列数超过 100 列") }
            row.append(String(decoding: field, as: UTF8.self))
            field.removeAll(keepingCapacity: true)
            fieldStarted = false
            closedQuote = false
        }
        func finishRow() -> Bool {
            guard cells + row.count <= maximumCells else { return false }
            cells += row.count
            rows.append(row)
            row.removeAll(keepingCapacity: true)
            return true
        }
        func preview(truncated: Bool) -> DelimitedPreview {
            DelimitedPreview(
                rows: rows, columnCount: rows.map(\.count).max() ?? 0, isTruncated: truncated,
                notice: truncated ? "仅显示开头的完整记录（最多 1,000 行、\(maximumCells) 个单元格）；非完整文件。" : nil
            )
        }
        while index < bytes.count {
            if index.isMultiple(of: 4096), Date().timeIntervalSince(started) > budget.maximumDuration {
                throw failure("处理时间超过安全预算")
            }
            let byte = bytes[index]
            if quoted {
                if byte == 34 {
                    if index + 1 < bytes.count, bytes[index + 1] == 34 {
                        field.append(34)
                        index += 1
                    } else {
                        quoted = false
                        closedQuote = true
                    }
                } else { field.append(byte) }
            } else if byte == delimiter {
                try finishField()
            } else if byte == 10 || byte == 13 {
                try finishField()
                if !finishRow() { return preview(truncated: true) }
                if byte == 13, index + 1 < bytes.count, bytes[index + 1] == 10 { index += 1 }
                if rows.count >= 1_000, index + 1 < bytes.count { return preview(truncated: true) }
            } else if byte == 34 {
                guard !fieldStarted && !closedQuote else { throw failure("引号必须位于字段开头") }
                quoted = true
                fieldStarted = true
            } else {
                guard !closedQuote else { throw failure("引号闭合后存在意外字符") }
                fieldStarted = true
                field.append(byte)
            }
            guard field.count <= maximumFieldBytes else { throw failure("单元格内容超过安全预算") }
            index += 1
        }
        guard !quoted else { throw failure("字段引号未闭合") }
        if fieldStarted || closedQuote || !row.isEmpty {
            try finishField()
            if !finishRow() { return preview(truncated: true) }
        }
        return preview(truncated: false)
    }

    private static func failure(_ reason: String) -> NSError {
        NSError(domain: "TinyPreview.DelimitedText", code: 1, userInfo: [NSLocalizedDescriptionKey: reason])
    }
}
