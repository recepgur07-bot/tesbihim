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

    var hapticIntensity: HapticIntensity
    var soundProfile: SoundProfile
    var theme: Theme
    var keepScreenAwake: Bool
    /// Kapalıyken sayma alanında çift dokunuşla güncel sayı VoiceOver
    /// tarafından sesli söylenmez.
    var spokenCountEnabled: Bool
    /// Sayma ve geri alma sırasında kısa tesbih ses efekti verilsin mi.
    /// Konuşma tercihinden bağımsızdır; eski kayıtlar için varsayılan açıktır.
    var soundEffectEnabled: Bool

    /// Sihirli Dokunuş ile açılan, tek dokunuşla art arda sayan Hızlı
    /// Sayım modunun ana anahtarı — bkz. karar taslağı Bölüm 7. Yanlışlıkla
    /// Sihirli Dokunuş yapılıp moda düşülmesin diye varsayılan kapalı;
    /// kapalıyken Sayaç ekranındaki Sihirli Dokunuş hiçbir şey yapmaz.
    var fastCountModeEnabled: Bool
    /// Hızlı Sayım'da her dokunuşta titreşim verilsin mi.
    var fastCountHapticEnabled: Bool
    /// Hızlı Sayım'da her dokunuşta kısa ses efekti çalsın mı.
    var fastCountSoundEnabled: Bool
    /// Hızlı Sayım'da güncel sayı VoiceOver ile duyurulsun mu. Açıksa
    /// duyuru her dokunuşta değil, dokunuşlar durduktan ~500ms sonra
    /// sadece son değer için gönderilir (debounce) — yine de çok hızlı
    /// art arda dokunuşta duyurunun geriden gelebileceği not edilmeli,
    /// bu yüzden varsayılan kapalı.
    var fastCountAnnounceEnabled: Bool

    private enum CodingKeys: String, CodingKey {
        case hapticIntensity
        case soundProfile
        case theme
        case keepScreenAwake
        case spokenCountEnabled
        case soundEffectEnabled
        case fastCountModeEnabled
        case fastCountHapticEnabled
        case fastCountSoundEnabled
        case fastCountAnnounceEnabled
    }

    init(
        hapticIntensity: HapticIntensity,
        soundProfile: SoundProfile,
        theme: Theme,
        keepScreenAwake: Bool,
        spokenCountEnabled: Bool,
        soundEffectEnabled: Bool = true,
        fastCountModeEnabled: Bool = false,
        fastCountHapticEnabled: Bool = true,
        fastCountSoundEnabled: Bool = true,
        fastCountAnnounceEnabled: Bool = false
    ) {
        self.hapticIntensity = hapticIntensity
        self.soundProfile = soundProfile
        self.theme = theme
        self.keepScreenAwake = keepScreenAwake
        self.spokenCountEnabled = spokenCountEnabled
        self.soundEffectEnabled = soundEffectEnabled
        self.fastCountModeEnabled = fastCountModeEnabled
        self.fastCountHapticEnabled = fastCountHapticEnabled
        self.fastCountSoundEnabled = fastCountSoundEnabled
        self.fastCountAnnounceEnabled = fastCountAnnounceEnabled
    }

    /// Eski kayıtlarda `swipeHapticEnabled` alanı olabilir (artık
    /// kaldırılan kaydırma özelliğine aitti, bkz. karar taslağı Bölüm 9);
    /// bilinmeyen anahtar olarak sessizce yok sayılır, decode'u bozmaz.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hapticIntensity = try container.decode(HapticIntensity.self, forKey: .hapticIntensity)
        soundProfile = try container.decode(SoundProfile.self, forKey: .soundProfile)
        theme = try container.decode(Theme.self, forKey: .theme)
        keepScreenAwake = try container.decode(Bool.self, forKey: .keepScreenAwake)
        spokenCountEnabled = try container.decode(Bool.self, forKey: .spokenCountEnabled)
        soundEffectEnabled = try container.decodeIfPresent(Bool.self, forKey: .soundEffectEnabled) ?? true
        fastCountModeEnabled = try container.decodeIfPresent(Bool.self, forKey: .fastCountModeEnabled) ?? false
        fastCountHapticEnabled = try container.decodeIfPresent(Bool.self, forKey: .fastCountHapticEnabled) ?? true
        fastCountSoundEnabled = try container.decodeIfPresent(Bool.self, forKey: .fastCountSoundEnabled) ?? true
        fastCountAnnounceEnabled = try container.decodeIfPresent(Bool.self, forKey: .fastCountAnnounceEnabled) ?? false
    }

    static let initial = UserSettings(
        hapticIntensity: .medium,
        soundProfile: .light,
        theme: .system,
        keepScreenAwake: false,
        spokenCountEnabled: true,
        soundEffectEnabled: true,
        fastCountModeEnabled: false,
        fastCountHapticEnabled: true,
        fastCountSoundEnabled: true,
        fastCountAnnounceEnabled: false
    )
}
