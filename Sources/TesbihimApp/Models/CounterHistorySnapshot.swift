import Foundation

enum LocalDayKey {
    static func make(for date: Date, timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}

/// Sayaç ve günlük geçmişin tek, sürümlü kalıcı kaynağı.
///
/// `mutationRevision`, şema sürümünden ayrıdır: her başarılı kullanıcı
/// mutasyonunda artar ve geç dönen async sonuçların UI'ı geri sarmasını önler.
struct CounterHistorySnapshot: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var mutationRevision: Int64
    var counter: CounterState
    var entries: [HistoryEntry]

    init(
        schemaVersion: Int = CounterHistorySnapshot.currentSchemaVersion,
        counter: CounterState,
        entries: [HistoryEntry],
        mutationRevision: Int64 = 0
    ) {
        self.schemaVersion = schemaVersion
        self.mutationRevision = mutationRevision
        self.counter = counter
        self.entries = entries
    }
}
