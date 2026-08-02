import Foundation
import UniformTypeIdentifiers

public enum FolderScanner {
    public static func scan(
        _ root: URL,
        budget: SafetyBudget = .standard
    ) -> ContainerPreview {
        let started = Date()
        var entries: [ContainerEntry] = []
        var knownBytes: Int64 = 0
        var stopReason: String?
        let keys: Set<URLResourceKey> = [
            .isDirectoryKey,
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .isPackageKey,
            .isHiddenKey,
            .fileSizeKey,
            .contentTypeKey,
            .isUbiquitousItemKey,
            .ubiquitousItemDownloadingStatusKey
        ]

        func budgetAllowsMore() -> Bool {
            if entries.count >= budget.maximumEntries {
                stopReason = "已达到 \(budget.maximumEntries.formatted()) 项安全上限"
                return false
            }
            if Date().timeIntervalSince(started) >= budget.maximumDuration {
                stopReason = "已达到 \(Int(budget.maximumDuration)) 秒处理时限"
                return false
            }
            return true
        }

        func appendUnreadable(_ url: URL, depth: Int, warning: String) {
            guard budgetAllowsMore() else { return }
            entries.append(ContainerEntry(
                id: entries.count,
                depth: depth,
                name: url.lastPathComponent,
                typeLabel: "不可读项目",
                size: nil,
                isDirectory: false,
                isHidden: url.lastPathComponent.hasPrefix("."),
                warning: warning
            ))
        }

        func visit(_ directory: URL, depth: Int) {
            guard budgetAllowsMore() else { return }
            let children: [URL]
            do {
                children = try FileManager.default.contentsOfDirectory(
                    at: directory,
                    includingPropertiesForKeys: Array(keys),
                    options: []
                ).sorted {
                    let leftDirectory = (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                    let rightDirectory = (try? $1.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                    if leftDirectory != rightDirectory { return leftDirectory }
                    return $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
                }
            } catch {
                if depth == 0 {
                    stopReason = "无法读取文件夹：\(error.localizedDescription)"
                } else {
                    appendUnreadable(directory, depth: depth, warning: "无法读取：\(error.localizedDescription)")
                }
                return
            }

            for child in children {
                guard budgetAllowsMore() else { return }
                let values: URLResourceValues
                do {
                    values = try child.resourceValues(forKeys: keys)
                } catch {
                    appendUnreadable(child, depth: depth, warning: "无法读取：\(error.localizedDescription)")
                    continue
                }

                let isDirectory = values.isDirectory == true
                let isLink = values.isSymbolicLink == true
                let isPackage = values.isPackage == true
                let isHidden = values.isHidden == true || child.lastPathComponent.hasPrefix(".")
                let isCloudPlaceholder = values.isUbiquitousItem == true && values.ubiquitousItemDownloadingStatus != .current
                let typeLabel: String
                if isLink {
                    typeLabel = "符号链接"
                } else if isPackage {
                    typeLabel = values.contentType?.localizedDescription ?? "包"
                } else if isDirectory {
                    typeLabel = "文件夹"
                } else {
                    typeLabel = values.contentType?.localizedDescription ?? "文件"
                }

                var warning: String?
                if isLink {
                    let target = (try? FileManager.default.destinationOfSymbolicLink(atPath: child.path)) ?? "未知目标"
                    warning = "链接到 \(target)；未跟随"
                } else if isCloudPlaceholder {
                    warning = "内容尚未下载"
                }

                let size = isDirectory ? nil : values.fileSize.map(Int64.init)
                if let size { knownBytes += size }
                entries.append(ContainerEntry(
                    id: entries.count,
                    depth: depth,
                    name: child.lastPathComponent,
                    typeLabel: typeLabel,
                    size: size,
                    isDirectory: isDirectory,
                    isHidden: isHidden,
                    warning: warning
                ))

                if isDirectory && !isLink && !isPackage && !isHidden && !isCloudPlaceholder {
                    visit(child, depth: depth + 1)
                }
            }
        }

        visit(root, depth: 0)
        return ContainerPreview(
            title: root.lastPathComponent,
            entries: entries,
            knownBytes: knownBytes,
            isComplete: stopReason == nil,
            incompleteReason: stopReason
        )
    }
}
