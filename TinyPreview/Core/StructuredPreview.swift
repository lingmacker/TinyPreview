import Foundation

public enum StructuredPreview {
    public static func json(_ text: String, maximumBytes: Int = 16 * 1_048_576) throws -> String {
        _ = try JSONSerialization.jsonObject(with: Data(text.utf8), options: [.fragmentsAllowed])
        // Reflow validated tokens instead of reserializing NSNumber and changing numeric precision.
        let bytes = Array(text.utf8)
        var output: [UInt8] = []
        var depth = 0
        var inString = false
        var escaped = false
        var previous: UInt8?
        func newline() {
            output.append(10)
            output.append(contentsOf: repeatElement(32, count: depth * 2))
        }
        for byte in bytes {
            if inString {
                output.append(byte)
                if escaped { escaped = false }
                else if byte == 92 { escaped = true }
                else if byte == 34 { inString = false }
            } else {
                if [9, 10, 13, 32].contains(byte) { continue }
                switch byte {
                case 34:
                    if previous == 123 || previous == 91 { newline() }
                    inString = true
                    output.append(byte)
                case 123, 91:
                    if previous == 123 || previous == 91 { newline() }
                    output.append(byte)
                    depth += 1
                case 125, 93:
                    depth -= 1
                    if previous != 123 && previous != 91 { newline() }
                    output.append(byte)
                case 44:
                    output.append(byte)
                    newline()
                case 58:
                    output.append(contentsOf: [58, 32])
                default:
                    if previous == 123 || previous == 91 { newline() }
                    output.append(byte)
                }
                previous = byte
            }
            guard output.count <= maximumBytes else { throw CocoaError(.fileReadTooLarge) }
        }
        return String(decoding: output, as: UTF8.self)
    }

    public static func propertyList(_ data: Data, maximumBytes: Int = 16 * 1_048_576) throws -> String {
        let value = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        // Bound XML expansion too: binary plists can reference the same large value many times.
        var pending: [Any] = [value]
        var estimatedBytes = 0
        var visited = 0
        while let item = pending.popLast() {
            visited += 1
            guard visited <= 20_000 else { throw CocoaError(.fileReadTooLarge) }
            if let string = item as? String { estimatedBytes += string.utf8.count * 6 + 32 }
            else if let bytes = item as? Data { estimatedBytes += bytes.count * 2 + 32 }
            else if let dictionary = item as? [String: Any] {
                guard dictionary.count <= 10_000 else { throw CocoaError(.fileReadTooLarge) }
                pending.append(contentsOf: dictionary.keys.map { $0 as Any })
                pending.append(contentsOf: dictionary.values)
            } else if let array = item as? [Any] {
                guard array.count <= 20_000 else { throw CocoaError(.fileReadTooLarge) }
                pending.append(contentsOf: array)
            } else { estimatedBytes += 64 }
            guard estimatedBytes <= maximumBytes, pending.count <= 20_000 else { throw CocoaError(.fileReadTooLarge) }
        }
        let xml = try PropertyListSerialization.data(fromPropertyList: value, format: .xml, options: 0)
        guard xml.count <= maximumBytes else { throw CocoaError(.fileReadTooLarge) }
        return String(decoding: xml, as: UTF8.self)
    }
}
