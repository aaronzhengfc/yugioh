import Foundation

enum AppLanguage: String, CaseIterable {
    case english = "en"
    case simplifiedChinese = "cn"

    static let preferenceKey = "appLanguage"
    static var current = resolve(
        savedValue: UserDefaults.standard.string(forKey: preferenceKey),
        preferredLanguages: Locale.preferredLanguages
    )

    static func resolve(savedValue: String?, preferredLanguages: [String]) -> AppLanguage {
        if let savedValue = savedValue, let saved = AppLanguage(rawValue: savedValue) {
            return saved
        }
        for identifier in preferredLanguages {
            let code = identifier.replacingOccurrences(of: "_", with: "-").lowercased()
            if code == "zh" || code.hasPrefix("zh-") { return .simplifiedChinese }
            if code == "en" || code.hasPrefix("en-") { return .english }
        }
        return .english
    }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .simplifiedChinese: return "简体中文"
        }
    }
}

enum L10n {
    static func text(_ chinese: String, _ english: String) -> String {
        return AppLanguage.current == .simplifiedChinese ? chinese : english
    }
}
