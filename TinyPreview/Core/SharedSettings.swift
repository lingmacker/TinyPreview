import CoreFoundation
import Foundation

public enum SharedSettings {
    /// The host app's own preferences domain. The sandboxed extension reads it through the
    /// `temporary-exception.shared-preference.read-only` entitlement, so no app group is needed.
    public static let domain = "com.lingmacker.TinyPreview"

    private static let keys: [PreviewCategory: String] = [
        .text: "textLimitBytes",
        .sourceCode: "sourceCodeLimitBytes",
        .image: "imageLimitBytes",
        .archive: "archiveLimitBytes"
    ]

    public static func load() -> PreviewLimits {
        var limits = PreviewLimits.defaults
        for category in PreviewCategory.allCases {
            guard
                let key = keys[category],
                let number = CFPreferencesCopyAppValue(key as CFString, domain as CFString) as? NSNumber
            else { continue }
            limits.set(number.int64Value, for: category)
        }
        return limits
    }

    @discardableResult
    public static func save(_ limits: PreviewLimits) -> Bool {
        for category in PreviewCategory.allCases {
            guard let key = keys[category] else { continue }
            CFPreferencesSetAppValue(key as CFString, NSNumber(value: limits.value(for: category)), domain as CFString)
        }
        return CFPreferencesAppSynchronize(domain as CFString)
    }

    @discardableResult
    public static func reset() -> Bool {
        for category in PreviewCategory.allCases {
            guard let key = keys[category] else { continue }
            CFPreferencesSetAppValue(key as CFString, nil, domain as CFString)
        }
        return CFPreferencesAppSynchronize(domain as CFString)
    }

    /// Moves limits written by earlier versions into the app domain and removes them from the
    /// global domain, where every app could see them. Only the unsandboxed host app can do this.
    public static func migrateLegacyGlobalValues() {
        var moved = false
        for category in PreviewCategory.allCases {
            guard let key = keys[category] else { continue }
            let legacyKey = "\(domain).\(key)" as CFString
            guard let value = CFPreferencesCopyValue(
                legacyKey, kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost
            ) else { continue }
            if CFPreferencesCopyAppValue(key as CFString, domain as CFString) == nil {
                CFPreferencesSetAppValue(key as CFString, value, domain as CFString)
            }
            CFPreferencesSetValue(legacyKey, nil, kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
            moved = true
        }
        guard moved else { return }
        CFPreferencesAppSynchronize(domain as CFString)
        CFPreferencesSynchronize(kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    }
}
