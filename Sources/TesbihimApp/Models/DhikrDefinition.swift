import Foundation

enum DhikrCategory: String, Codable, CaseIterable, Hashable, Identifiable {
    case serbest, tesbihat, salavat, istigfar, diger
    var id: Self { self }
    var title: String {
        switch self {
        case .serbest: "Serbest Sayaç"
        case .tesbihat: "Namaz Sonrası Tesbihat"
        case .salavat: "Salavat"
        case .istigfar: "İstiğfar"
        case .diger: "Diğer"
        }
    }
}

enum FieldOverride<Value: Codable & Equatable>: Codable, Equatable {
    case inherit
    case set(Value)
    case clear
}

enum CompletionPolicy: String, Codable, CaseIterable { case stop, cycle }
enum SettingOverride: String, Codable, CaseIterable { case inherit, on, off }
enum FeedbackCharacter: String, Codable, CaseIterable { case system, wood, glass, soft, doubleTap }

struct ReminderSchedule: Codable, Equatable, Hashable {
    var weekday: Int
    var hour: Int
    var minute: Int
    func requestIdentifier(dhikrID: String) -> String { "\(dhikrID)_\(weekday)_\(hour)_\(minute)" }
}

struct BundledDhikrDefinition: Identifiable, Codable, Hashable {
    let id: String
    let category: DhikrCategory
    let arabicText: String
    let transliteration: String
    let meaning: String
    let defaultTarget: Int?
    let source: String
    let contentVersion: Int

    var turkishTransliteration: String { transliteration }
    var turkishMeaning: String { meaning }

    static let freeCounter = Self(id: "serbest", category: .serbest, arabicText: "",
        transliteration: "Serbest Sayaç", meaning: "", defaultTarget: nil,
        source: "", contentVersion: 1)
}

typealias DhikrDefinition = BundledDhikrDefinition

struct CustomDhikr: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var arabicText: String?
    var meaning: String?
    var defaultTarget: Int?
    var category: DhikrCategory
    var createdAt: Date
    var updatedAt: Date
}

struct DhikrUserState: Codable, Equatable, Identifiable {
    var dhikrID: String
    var name: FieldOverride<String> = .inherit
    var arabicText: FieldOverride<String> = .inherit
    var meaning: FieldOverride<String> = .inherit
    var defaultTarget: FieldOverride<Int> = .inherit
    var category: FieldOverride<DhikrCategory> = .inherit
    var completionPolicy: CompletionPolicy = .stop
    var reminders: [ReminderSchedule] = []
    var soundOverride: SettingOverride = .inherit
    var hapticOverride: SettingOverride = .inherit
    var feedbackCharacter: FeedbackCharacter = .system
    var milestoneInterval: Int?
    var removedAt: Date?
    var id: String { dhikrID }

    init(dhikrID: String, removedAt: Date? = nil) {
        self.dhikrID = dhikrID
        self.removedAt = removedAt
    }

    var hasContentOverrides: Bool {
        name != .inherit || arabicText != .inherit || meaning != .inherit ||
        defaultTarget != .inherit || category != .inherit
    }

    mutating func resetContentOverrides() {
        name = .inherit; arabicText = .inherit; meaning = .inherit
        defaultTarget = .inherit; category = .inherit
    }
}

struct ResolvedDhikr: Identifiable, Equatable {
    enum Origin: Equatable { case bundled, custom }
    var id: String
    var name: String
    var arabicText: String?
    var meaning: String?
    var defaultTarget: Int?
    var category: DhikrCategory
    var source: String?
    var contentVersion: Int?
    var origin: Origin
    var userState: DhikrUserState

    static func resolve(_ bundled: BundledDhikrDefinition, state: DhikrUserState?) -> Self {
        let state = state ?? DhikrUserState(dhikrID: bundled.id)
        return Self(id: bundled.id,
            name: resolve(state.name, inherited: bundled.transliteration) ?? bundled.transliteration,
            arabicText: resolve(state.arabicText, inherited: bundled.arabicText),
            meaning: resolve(state.meaning, inherited: bundled.meaning),
            defaultTarget: resolve(state.defaultTarget, inherited: bundled.defaultTarget),
            category: resolve(state.category, inherited: bundled.category) ?? bundled.category,
            source: bundled.source, contentVersion: bundled.contentVersion,
            origin: .bundled, userState: state)
    }

    static func resolve(_ custom: CustomDhikr, state: DhikrUserState?) -> Self {
        let state = state ?? DhikrUserState(dhikrID: custom.id)
        return Self(id: custom.id, name: custom.name, arabicText: custom.arabicText,
            meaning: custom.meaning, defaultTarget: custom.defaultTarget,
            category: custom.category, source: nil, contentVersion: nil,
            origin: .custom, userState: state)
    }

    private static func resolve<T>(_ override: FieldOverride<T>, inherited: T?) -> T? {
        switch override { case .inherit: inherited; case .set(let value): value; case .clear: nil }
    }
}
