import Foundation

public enum PreviewLoader {
    public static func load(
        _ url: URL,
        limits: PreviewLimits = SharedSettings.load(),
        budget: SafetyBudget = .standard
    ) -> PreviewResult {
        let started = Date()
        do {
            let cloudValues = try url.resourceValues(forKeys: [
                .isUbiquitousItemKey,
                .ubiquitousItemDownloadingStatusKey
            ])
            if cloudValues.isUbiquitousItem == true && cloudValues.ubiquitousItemDownloadingStatus != .current {
                return .message(unsupported(
                    url,
                    systemType: nil,
                    detail: "内容尚未下载；TinyPreview 不会主动触发云端下载。"
                ))
            }

            let classification = try ContentClassifier.classify(url)
            switch classification.content {
            case .folder:
                return .container(FolderScanner.scan(url, budget: budget))

            case .archive:
                if let refusal = sizeRefusal(url, classification: classification, category: .archive, limits: limits) {
                    return .message(refusal)
                }
                do {
                    return .container(try ArchiveScanner.scan(url, budget: budget))
                } catch ArchiveScanError.encrypted {
                    return .message(unsupported(url, systemType: classification.systemType, detail: "加密或密码压缩包暂不支持。"))
                } catch ArchiveScanError.multipart {
                    return .message(unsupported(url, systemType: classification.systemType, detail: "分卷压缩包暂不支持。"))
                } catch {
                    return .message(corrupt(url, systemType: classification.systemType, detail: error.localizedDescription))
                }

            case .image(let isSVG):
                if let refusal = sizeRefusal(url, classification: classification, category: .image, limits: limits) {
                    return .message(refusal)
                }
                let data = try Data(contentsOf: url, options: .mappedIfSafe)
                do {
                    let image = try ImagePreviewLoader.load(data: data, isSVG: isSVG, budget: budget)
                    if timedOut(started, budget: budget) {
                        return .message(timeoutRefusal(url, category: .image))
                    }
                    return .image(image)
                } catch {
                    if error is ImagePreviewError,
                       error.localizedDescription.contains("安全预算") {
                        return .message(resourceRefusal(url, category: .image, detail: error.localizedDescription))
                    }
                    return .message(corrupt(url, systemType: classification.systemType, detail: error.localizedDescription))
                }

            case .source(let language):
                if let refusal = sizeRefusal(url, classification: classification, category: .sourceCode, limits: limits) {
                    return .message(refusal)
                }
                return loadText(
                    url,
                    classification: classification,
                    language: language,
                    category: .sourceCode,
                    started: started,
                    budget: budget
                )

            case .text:
                if let refusal = sizeRefusal(url, classification: classification, category: .text, limits: limits) {
                    return .message(refusal)
                }
                return loadText(
                    url,
                    classification: classification,
                    language: nil,
                    category: .text,
                    started: started,
                    budget: budget
                )

            case .unsupported:
                return .message(unsupported(
                    url,
                    systemType: classification.systemType,
                    detail: "TinyPreview 不支持此内容。"
                ))
            }
        } catch {
            return .message(corrupt(url, systemType: nil, detail: error.localizedDescription))
        }
    }

    private static func loadText(
        _ url: URL,
        classification: Classification,
        language: SourceLanguage?,
        category: PreviewCategory,
        started: Date,
        budget: SafetyBudget
    ) -> PreviewResult {
        do {
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            let estimated = Int64(data.count).multipliedReportingOverflow(by: 3)
            guard !estimated.overflow, estimated.partialValue <= budget.maximumWorkingBytes else {
                return .message(resourceRefusal(
                    url,
                    category: category,
                    detail: "解码文本会超过 256 MB 安全预算。"
                ))
            }
            guard let (text, encoding) = UnicodeTextDecoder.decode(data) else {
                return .message(unsupported(
                    url,
                    systemType: classification.systemType,
                    detail: "内容不是受支持的 Unicode 纯文本。"
                ))
            }
            guard !timedOut(started, budget: budget) else {
                return .message(timeoutRefusal(url, category: category))
            }
            return .text(TextPreview(text: text, encoding: encoding, language: language))
        } catch {
            return .message(corrupt(url, systemType: classification.systemType, detail: error.localizedDescription))
        }
    }

    private static func sizeRefusal(
        _ url: URL,
        classification: Classification,
        category: PreviewCategory,
        limits: PreviewLimits
    ) -> PreviewMessage? {
        guard let actual = classification.fileSize else { return nil }
        let limit = limits.value(for: category)
        guard actual > limit else { return nil }
        return PreviewMessage(
            kind: .refused,
            title: "文件超过\(category.displayName)上限",
            detail: "请在 TinyPreview 设置中调高此类别的有限上限。新设置会在下一次快速预览时生效。",
            fileName: url.lastPathComponent,
            systemType: classification.systemType,
            actualBytes: actual,
            limitBytes: limit
        )
    }

    private static func timeoutRefusal(_ url: URL, category: PreviewCategory) -> PreviewMessage {
        resourceRefusal(url, category: category, detail: "处理时间超过 2 秒安全预算。")
    }

    private static func resourceRefusal(_ url: URL, category: PreviewCategory, detail: String) -> PreviewMessage {
        PreviewMessage(
            kind: .refused,
            title: "已停止\(category.displayName)预览",
            detail: detail,
            fileName: url.lastPathComponent,
            systemType: nil,
            actualBytes: nil,
            limitBytes: nil
        )
    }

    private static func unsupported(_ url: URL, systemType: String?, detail: String) -> PreviewMessage {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init)
        return PreviewMessage(
            kind: .unsupported,
            title: "不支持的内容",
            detail: detail,
            fileName: url.lastPathComponent,
            systemType: systemType,
            actualBytes: size,
            limitBytes: nil
        )
    }

    private static func corrupt(_ url: URL, systemType: String?, detail: String) -> PreviewMessage {
        PreviewMessage(
            kind: .corrupt,
            title: "无法完成预览",
            detail: detail,
            fileName: url.lastPathComponent,
            systemType: systemType,
            actualBytes: nil,
            limitBytes: nil
        )
    }

    private static func timedOut(_ started: Date, budget: SafetyBudget) -> Bool {
        Date().timeIntervalSince(started) > budget.maximumDuration
    }
}
