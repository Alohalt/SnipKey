import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    static let userDefaultsKey = "SnipKey.appLanguage"
    static let defaultLanguage: AppLanguage = .simplifiedChinese

    var id: String { rawValue }

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    var pickerTitle: String {
        switch self {
        case .english:
            return "English"
        case .simplifiedChinese:
            return "简体中文"
        }
    }

    static var current: AppLanguage {
        stored(in: .standard)
    }

    static func stored(in defaults: UserDefaults) -> AppLanguage {
        guard let rawValue = defaults.string(forKey: userDefaultsKey),
              let language = AppLanguage(rawValue: rawValue) else {
            return defaultLanguage
        }

        return language
    }
}