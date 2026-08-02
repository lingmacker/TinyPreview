import CoreFoundation
import Foundation

public enum SharedSettings {
    public static let keyPrefix = "com.lingmacker.TinyPreview"

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
                let key = preferenceKey(for: category),
                let number = CFPreferencesCopyValue(
                    key,
                    kCFPreferencesAnyApplication,
                    kCFPreferencesCurrentUser,
                    kCFPreferencesAnyHost
                ) as? NSNumber
            else { continue }
            limits.set(number.int64Value, for: category)
        }
        return limits
    }

    @discardableResult
    public static func save(_ limits: PreviewLimits) -> Bool {
        for category in PreviewCategory.allCases {
            guard let key = preferenceKey(for: category) else { continue }
            CFPreferencesSetValue(
                key,
                NSNumber(value: limits.value(for: category)),
                kCFPreferencesAnyApplication,
                kCFPreferencesCurrentUser,
                kCFPreferencesAnyHost
            )
        }
        return synchronize()
    }

    @discardableResult
    public static func reset() -> Bool {
        for category in PreviewCategory.allCases {
            guard let key = preferenceKey(for: category) else { continue }
            CFPreferencesSetValue(
                key,
                nil,
                kCFPreferencesAnyApplication,
                kCFPreferencesCurrentUser,
                kCFPreferencesAnyHost
            )
        }
        return synchronize()
    }

    private static func preferenceKey(for category: PreviewCategory) -> CFString? {
        keys[category].map { "\(keyPrefix).\($0)" as CFString }
    }

    private static func synchronize() -> Bool {
        CFPreferencesSynchronize(
            kCFPreferencesAnyApplication,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
    }
}
