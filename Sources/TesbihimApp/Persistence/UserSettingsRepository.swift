import Foundation

/// `UserSettings`'in kalıcı saklanmasını soyutlar — bkz. PLAN.md Bölüm 3,
/// `CounterRepository` ile aynı desen.
protocol UserSettingsRepository {
    func load() -> UserSettings
    func save(_ settings: UserSettings)
}

final class UserDefaultsUserSettingsRepository: UserSettingsRepository {
    private let defaults: UserDefaults
    private let key = "tesbihim.userSettings"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> UserSettings {
        guard
            let data = defaults.data(forKey: key),
            let settings = try? JSONDecoder().decode(UserSettings.self, from: data)
        else {
            return .initial
        }
        return settings
    }

    func save(_ settings: UserSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }
}
