import Combine
import Foundation

final class AppLanguageStore: ObservableObject {
    @Published var language: AppLanguage {
        didSet {
            guard language != oldValue else { return }
            userDefaults.set(language.rawValue, forKey: AppLanguage.userDefaultsKey)
        }
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        language = AppLanguage.stored(in: userDefaults)
    }

    func text(_ key: L10n.Key) -> String {
        L10n.text(key, language: language)
    }

    func formatted(_ key: L10n.Key, _ arguments: CVarArg...) -> String {
        L10n.formatted(key, language: language, arguments)
    }
}