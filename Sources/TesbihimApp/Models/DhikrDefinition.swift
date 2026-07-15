import Foundation

/// Hazır veya (Faz 2'de) özel bir zikir tanımı — bkz. PLAN.md Bölüm 3, 7.2.
struct DhikrDefinition: Identifiable, Codable, Hashable {
    enum Category: String, Codable {
        case tesbihat
        case salavat
        case istigfar
        case serbest
    }

    let id: String
    let category: Category
    let arabicText: String
    let turkishTransliteration: String
    let turkishMeaning: String
    let defaultTarget: Int?
    let source: String
}
