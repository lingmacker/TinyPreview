import SwiftUI

struct SettingsView: View {
    @StateObject private var model = SettingsModel()

    var body: some View {
        Form {
            Section {
                limitRow(.text, icon: "doc.plaintext")
                limitRow(.sourceCode, icon: "chevron.left.forwardslash.chevron.right")
                limitRow(.image, icon: "photo")
                limitRow(.archive, icon: "archivebox")
            } header: {
                Text("预览大小上限")
            } footer: {
                Text("超过对应上限的文件不会读取正文。文件夹不使用大小上限，仍受 5,000 项、2 秒和 256 MB 安全预算保护。新设置从下一次快速预览开始生效。")
            }

            Section {
                HStack {
                    Button("恢复默认值") { model.reset() }
                    Spacer()
                    if model.saveFailed {
                        Label("设置未能保存", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 370)
    }

    @ViewBuilder
    private func limitRow(_ category: PreviewCategory, icon: String) -> some View {
        let range = PreviewLimits.ranges[category]!
        let lower = Int(range.lowerBound / 1_048_576)
        let upper = Int(range.upperBound / 1_048_576)
        LabeledContent {
            HStack(spacing: 8) {
                TextField(
                    "MB",
                    value: Binding(
                        get: { model.megabytes(for: category) },
                        set: { model.update(megabytes: $0, for: category) }
                    ),
                    format: .number
                )
                .multilineTextAlignment(.trailing)
                .frame(width: 72)
                Text("MB")
                    .foregroundStyle(.secondary)
                    .frame(width: 26, alignment: .leading)
                Stepper(
                    "",
                    value: Binding(
                        get: { model.megabytes(for: category) },
                        set: { model.update(megabytes: $0, for: category) }
                    ),
                    in: lower ... upper
                )
                .labelsHidden()
            }
        } label: {
            Label(category.displayName, systemImage: icon)
        }
    }
}
