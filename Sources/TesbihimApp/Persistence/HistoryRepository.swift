import Foundation

/// `HistoryEntry` listesinin kalıcı saklanmasını soyutlar — bkz. PLAN.md
/// Bölüm 3, diğer repository'lerle aynı desen.
protocol HistoryRepository {
    func load() -> [HistoryEntry]
    func save(_ entries: [HistoryEntry])
}

final class UserDefaultsHistoryRepository: HistoryRepository {
    private let defaults: UserDefaults
    private let key = "tesbihim.historyEntries"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [HistoryEntry] {
        guard
            let data = defaults.data(forKey: key),
            let entries = try? JSONDecoder().decode([HistoryEntry].self, from: data)
        else {
            return []
        }
        return entries
    }

    func save(_ entries: [HistoryEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: key)
    }
}
