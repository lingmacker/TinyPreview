import Foundation

public enum PreviewLoader {
    public static func load(
        _ url: URL,
        limits: PreviewLimits = SharedSettings.load(),
        budget: SafetyBudget = .standard,
        allowPartialText: Bool = false
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

            case .propertyList:
                return loadPropertyList(url, classification: classification, limits: limits, budget: budget, started: started)

            case .source(let language):
                if !allowPartialText, let refusal = sizeRefusal(url, classification: classification, category: .sourceCode, limits: limits, canPreviewPrefix: true) {
                    return .message(refusal)
                }
                return loadText(
                    url,
                    classification: classification,
                    language: language,
                    category: .sourceCode,
                    started: started,
                    budget: budget,
                    maximumBytes: limits.sourceCodeBytes,
                    allowPartial: allowPartialText
                )

            case .text:
                if !allowPartialText,
                   let refusal = sizeRefusal(url, classification: classification, category: .text, limits: limits, canPreviewPrefix: true) {
                    return .message(refusal)
                }
                return loadText(
                    url,
                    classification: classification,
                    language: nil,
                    category: .text,
                    started: started,
                    budget: budget,
                    maximumBytes: limits.textBytes,
                    allowPartial: allowPartialText
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
        budget: SafetyBudget,
        maximumBytes: Int64,
        allowPartial: Bool
    ) -> PreviewResult {
        do {
            let ceiling = min(maximumBytes, budget.maximumWorkingBytes / 16, Int64(Int.max - 1))
            let cap = Int(allowPartial ? min(1_048_576, ceiling) : ceiling)
            guard cap > 0 else { return .message(resourceRefusal(url, category: category, detail: "文本安全预算不足。")) }
            let data = try readBounded(url, maximumBytes: cap)
            let truncated = data.count > cap
            if truncated && !allowPartial {
                return .message(PreviewMessage(
                    kind: .refused, title: "已停止文本预览",
                    detail: "内容超过读取或内存安全预算，可仅预览开头。",
                    fileName: url.lastPathComponent, systemType: classification.systemType,
                    actualBytes: classification.fileSize, limitBytes: Int64(cap), canPreviewPrefix: true
                ))
            }
            let payload = Data(data.prefix(cap))
            guard let (text, encoding) = truncated ? UnicodeTextDecoder.decodePrefix(payload) : UnicodeTextDecoder.decode(payload) else {
                return .message(unsupported(url, systemType: classification.systemType, detail: "内容不是受支持的 Unicode 纯文本。"))
            }
            var formatted: String?
            var notice = truncated ? "仅显示开头最多 1 MB 的内容；文件已截断，不代表完整内容。" : nil
            if !truncated, language == .json {
                do { formatted = try StructuredPreview.json(text, maximumBytes: Int(min(16 * 1_048_576, budget.maximumWorkingBytes / 4))) }
                catch { notice = "JSON 格式化不可用：语法无效或超过安全预算；显示原文。" }
            }
            guard !timedOut(started, budget: budget) else { return .message(timeoutRefusal(url, category: category)) }
            return .text(TextPreview(text: text, encoding: encoding, language: language, formattedText: formatted, notice: notice, isTruncated: truncated))
        } catch {
            return .message(corrupt(url, systemType: classification.systemType, detail: error.localizedDescription))
        }
    }

    private static func readBounded(_ url: URL, maximumBytes: Int) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        return try handle.read(upToCount: maximumBytes + 1) ?? Data()
    }

    private static func loadPropertyList(_ url: URL, classification: Classification, limits: PreviewLimits,
                                         budget: SafetyBudget, started: Date) -> PreviewResult {
        if let refusal = sizeRefusal(url, classification: classification, category: .sourceCode, limits: limits) { return .message(refusal) }
        do {
            let cap = Int(max(0, min(limits.sourceCodeBytes, budget.maximumWorkingBytes / 16, Int64(Int.max - 1))))
            let data = try readBounded(url, maximumBytes: cap)
            guard data.count <= cap else { return .message(resourceRefusal(url, category: .sourceCode, detail: "plist 超过内存安全预算。")) }
            let binary = data.starts(with: Array("bplist00".utf8))
            let original = UnicodeTextDecoder.decode(data)
            let preview: TextPreview
            do {
                let xml = try StructuredPreview.propertyList(data, maximumBytes: Int(min(16 * 1_048_576, max(0, budget.maximumWorkingBytes / 4))))
                preview = TextPreview(text: original?.0 ?? xml, encoding: original?.1 ?? .utf8, language: .xml,
                                      formattedText: original == nil ? nil : xml,
                                      notice: binary ? "二进制 plist：以只读 XML 展示，不是原始二进制内容。" : nil)
            } catch {
                guard let original else { return .message(corrupt(url, systemType: classification.systemType, detail: "plist 无法解析：\(error.localizedDescription)")) }
                preview = TextPreview(text: original.0, encoding: original.1, language: .xml, notice: "plist 解析失败；显示原文。")
            }
            guard !timedOut(started, budget: budget) else { return .message(timeoutRefusal(url, category: .sourceCode)) }
            return .text(preview)
        } catch {
            return .message(corrupt(url, systemType: classification.systemType, detail: error.localizedDescription))
        }
    }

    private static func sizeRefusal(
        _ url: URL,
        classification: Classification,
        category: PreviewCategory,
        limits: PreviewLimits,
        canPreviewPrefix: Bool = false
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
            limitBytes: limit,
            canPreviewPrefix: canPreviewPrefix
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
