import Foundation

/// Geri bildirim ve erişilebilirlik tercihleri — bkz. PLAN.md Bölüm 3, 5, 7.4.
struct UserSettings: Codable, Equatable {
    enum HapticIntensity: String, Codable, CaseIterable {
        case light, medium, strong
    }

    enum SoundProfile: String, Codable, CaseIterable {
        case silent, light, normal
    }

    enum Theme: String, Codable, CaseIterable {
        case system, light, dark
    }

    var quickCountEnabled: Bool
    var hapticIntensity: HapticIntensity
    var soundProfile: SoundProfile
    var theme: Theme
    var keepScreenAwake: Bool

    static let initial = UserSettings(
        quickCountEnabled: false,
        hapticIntensity: .medium,
        soundProfile: .light,
        theme: .system,
        keepScreenAwake: false
    )
}
