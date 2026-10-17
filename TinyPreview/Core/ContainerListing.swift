import Foundation

public struct ContainerRow: Identifiable, Sendable {
    public let entry: ContainerEntry
    public let relativePath: String
    public let hasChildren: Bool
    public var id: Int { entry.id }
}

public enum ContainerListing {
    public static func rows(_ entries: [ContainerEntry], collapsed: Set<Int> = []) -> [ContainerRow] {
        var ancestors: [(depth: Int, path: String, collapsed: Bool)] = []
        var output: [ContainerRow] = []
        for (index, entry) in entries.enumerated() {
            while let parent = ancestors.last, parent.depth >= entry.depth { ancestors.removeLast() }
            let path = ancestors.last.map { $0.path + "/" + entry.name } ?? entry.name
            let hiddenByParent = ancestors.last?.collapsed ?? false
            if !hiddenByParent {
                let nextIndex = index + 1
                output.append(ContainerRow(
                    entry: entry, relativePath: path,
                    hasChildren: entry.isDirectory && nextIndex < entries.count && entries[nextIndex].depth > entry.depth
                ))
            }
            ancestors.append((entry.depth, path, hiddenByParent || collapsed.contains(entry.id)))
        }
        return output
    }
}
