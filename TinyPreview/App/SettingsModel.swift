import Foundation

@MainActor
final class SettingsModel: ObservableObject {
    @Published private(set) var limits: PreviewLimits
    @Published private(set) var saveFailed = false

    init() {
        limits = SharedSettings.load()
    }

    func megabytes(for category: PreviewCategory) -> Int {
        Int(limits.value(for: category) / 1_048_576)
    }

    func update(megabytes: Int, for category: PreviewCategory) {
        var updated = limits
        updated.set(Int64(megabytes) * 1_048_576, for: category)
        limits = updated
        saveFailed = !SharedSettings.save(updated)
    }

    func reset() {
        limits = .defaults
        saveFailed = !SharedSettings.reset()
    }
}
