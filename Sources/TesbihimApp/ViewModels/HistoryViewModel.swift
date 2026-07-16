import Foundation
import Observation

/// Geçmiş ekranının durumunu yönetir — bkz. PLAN.md Bölüm 7.3.
@Observable
final class HistoryViewModel {
    private(set) var entries: [HistoryEntry]
    private let repository: HistoryRepository
    private let calendar: Calendar

    struct PeriodSummary: Equatable {
        var addedCount: Int
        var completedTargetCount: Int
    }

    struct DhikrBreakdown: Identifiable, Equatable {
        var id: String { dhikrID }
        var dhikrID: String
        var addedCount: Int
        var completedTargetCount: Int
    }

    init(repository: HistoryRepository = UserDefaultsHistoryRepository(), calendar: Calendar = .current) {
        self.repository = repository
        self.calendar = calendar
        self.entries = repository.load()
    }

    /// Birleşik snapshot yüklemesinden gelen kayıtları sayaçla aynı anda
    /// görünür kılar. Kalıcılık actor tarafından yapılır; bu sınıf yalnızca
    /// ana aktördeki ekran durumunu tutar.
    func replaceEntries(_ entries: [HistoryEntry]) {
        self.entries = entries
    }

    /// Bölüm 7.3: "Bugün: 3 hedef tamamlandı, toplam 247 tekrar."
    var today: PeriodSummary { summary(since: calendar.startOfDay(for: Date())) }
    var thisWeek: PeriodSummary { summary(since: startOfWeek) }
    var total: PeriodSummary { summary(since: nil) }

    var breakdownByDhikr: [DhikrBreakdown] {
        Dictionary(grouping: entries, by: \.dhikrID)
            .map { dhikrID, entries in
                DhikrBreakdown(
                    dhikrID: dhikrID,
                    addedCount: entries.reduce(0) { $0 + $1.addedCount },
                    completedTargetCount: entries.reduce(0) { $0 + $1.completedTargetCount }
                )
            }
            .sorted { $0.addedCount > $1.addedCount }
    }

    /// "Geçmişi Sil" — bkz. Bölüm 7.3. Sadece bu kayıtları temizler,
    /// güncel zikir sayaç durumuna dokunmaz.
    func clearHistory() {
        entries = []
        repository.save(entries)
    }

    /// "Bu Zikrin Geçmişini Sil" — bkz. Bölüm 7.3. Yalnız verilen `dhikrID`
    /// kayıtlarını siler, diğer zikirleri ve güncel sayacı etkilemez.
    func clearHistory(forDhikrID dhikrID: String) {
        entries.removeAll { $0.dhikrID == dhikrID }
        repository.save(entries)
    }

    /// Sayaç ekranındaki her artış/geri alma sonrası çağrılır; aynı gün +
    /// aynı zikir için tek bir satırda toplanır. `date`, artışın gerçekte
    /// yapıldığı anı taşır — Geri Al gece yarısını aştıktan sonra bile
    /// bugüne değil, artışın ait olduğu güne yazılmasını sağlar.
    func recordDelta(dhikrID: String, dhikrName: String? = nil, date: Date = Date(), addedCountDelta: Int, completedTargetDelta: Int) {
        let dayStart = calendar.startOfDay(for: date)
        if let index = entries.firstIndex(where: { $0.dhikrID == dhikrID && calendar.isDate($0.date, inSameDayAs: dayStart) }) {
            entries[index].addedCount = max(0, entries[index].addedCount + addedCountDelta)
            entries[index].completedTargetCount = max(0, entries[index].completedTargetCount + completedTargetDelta)
        } else if addedCountDelta > 0 {
            entries.append(
                HistoryEntry(
                    date: dayStart,
                    dhikrID: dhikrID,
                    dhikrNameSnapshot: dhikrName,
                    addedCount: max(0, addedCountDelta),
                    completedTargetCount: max(0, completedTargetDelta)
                )
            )
        }
        repository.save(entries)
    }

    private var startOfWeek: Date {
        let dayStart = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: dayStart)
        let daysSinceWeekStart = (weekday - calendar.firstWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: -daysSinceWeekStart, to: dayStart) ?? dayStart
    }

    private func summary(since date: Date?) -> PeriodSummary {
        let relevant = date == nil ? entries : entries.filter { $0.date >= date! }
        return PeriodSummary(
            addedCount: relevant.reduce(0) { $0 + $1.addedCount },
            completedTargetCount: relevant.reduce(0) { $0 + $1.completedTargetCount }
        )
    }
}
