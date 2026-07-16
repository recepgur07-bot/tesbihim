import Foundation

enum HistoryPeriod: Equatable, Sendable {
    case today
    case week
    case month
    case all
}

struct HistoryPeriodRange: Equatable, Sendable {
    let startDayKey: String
    let endDayKey: String
}

struct HistoryDailyPoint: Equatable, Sendable {
    let localDayKey: String
    let addedCount: Int
    let completedTargetCount: Int
}

struct HistoryDhikrStatistic: Equatable, Sendable {
    let dhikrID: String
    let name: String
    let addedCount: Int
    let completedTargetCount: Int
}

struct HistoryComparison: Equatable, Sendable {
    let previousAddedCount: Int
    let difference: Int
    let previousPeriodHadRecords: Bool
}

struct HistoryPeriodSummary: Equatable, Sendable {
    let range: HistoryPeriodRange
    let addedCount: Int
    let completedTargetCount: Int
    let activeDayCount: Int
    let averageAddedCount: Double?
    let comparison: HistoryComparison?
    let dailyPoints: [HistoryDailyPoint]
    let dhikrBreakdown: [HistoryDhikrStatistic]
    let mostPerformedDhikr: HistoryDhikrStatistic?
    let busiestDay: HistoryDailyPoint?
}

/// Saf günlük agrega hesaplayıcısı. Tarihleri cihazın bugünkü saat diliminde
/// yeniden yorumlamak yerine sadece kanonik `localDayKey` değerleriyle eşler.
struct HistoryStatisticsCalculator {
    private let referenceDate: Date
    private var calendar: Calendar

    init(referenceDate: Date, timeZone: TimeZone = .current) {
        self.referenceDate = referenceDate
        self.calendar = Calendar(identifier: .gregorian)
        self.calendar.locale = Locale(identifier: "en_US_POSIX")
        self.calendar.timeZone = timeZone
    }

    func date(forLocalDayKey key: String) -> Date? {
        let parts = key.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts.allSatisfy({ !$0.isEmpty }),
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              (1...12).contains(month), (1...31).contains(day) else { return nil }
        let components = DateComponents(year: year, month: month, day: day)
        guard let date = calendar.date(from: components),
              calendar.dateComponents([.year, .month, .day], from: date) == components else { return nil }
        return date
    }

    func summary(for period: HistoryPeriod, entries: [HistoryEntry]) -> HistoryPeriodSummary {
        let range = range(for: period, entries: entries)
        let points = dailyPoints(in: range, entries: entries)
        let inPeriod = entries.filter { $0.localDayKey >= range.startDayKey && $0.localDayKey <= range.endDayKey }
        let total = points.reduce(0) { $0 + $1.addedCount }
        let targets = points.reduce(0) { $0 + $1.completedTargetCount }
        let activeDays = points.filter { $0.addedCount > 0 }.count
        let breakdown = dhikrStatistics(in: inPeriod)
        let busiest = points.filter { $0.addedCount > 0 }.sorted {
            $0.addedCount != $1.addedCount ? $0.addedCount > $1.addedCount : $0.localDayKey > $1.localDayKey
        }.first

        return HistoryPeriodSummary(
            range: range,
            addedCount: total,
            completedTargetCount: targets,
            activeDayCount: activeDays,
            averageAddedCount: period == .all ? nil : Double(total) / Double(averageDayCount(for: range)),
            comparison: comparison(for: period, currentTotal: total, entries: entries),
            dailyPoints: points,
            dhikrBreakdown: breakdown,
            mostPerformedDhikr: breakdown.first,
            busiestDay: busiest
        )
    }

    private func range(for period: HistoryPeriod, entries: [HistoryEntry]) -> HistoryPeriodRange {
        let today = dayKey(for: referenceDate)
        guard period != .all else {
            let first = entries.map(\.localDayKey).min() ?? today
            return HistoryPeriodRange(startDayKey: first, endDayKey: today)
        }
        let todayDate = date(forLocalDayKey: today)!
        switch period {
        case .today:
            return HistoryPeriodRange(startDayKey: today, endDayKey: today)
        case .week:
            let weekday = calendar.component(.weekday, from: todayDate)
            let mondayOffset = (weekday + 5) % 7
            let monday = calendar.date(byAdding: .day, value: -mondayOffset, to: todayDate)!
            let sunday = calendar.date(byAdding: .day, value: 6, to: monday)!
            return HistoryPeriodRange(startDayKey: dayKey(for: monday), endDayKey: dayKey(for: sunday))
        case .month:
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: todayDate))!
            let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start)!
            return HistoryPeriodRange(startDayKey: dayKey(for: start), endDayKey: dayKey(for: end))
        case .all:
            fatalError("Handled above")
        }
    }

    private func dailyPoints(in range: HistoryPeriodRange, entries: [HistoryEntry]) -> [HistoryDailyPoint] {
        var totals: [String: (added: Int, targets: Int)] = [:]
        for entry in entries where entry.localDayKey >= range.startDayKey && entry.localDayKey <= range.endDayKey {
            let value = totals[entry.localDayKey, default: (0, 0)]
            totals[entry.localDayKey] = (value.added + entry.addedCount, value.targets + entry.completedTargetCount)
        }
        guard let start = date(forLocalDayKey: range.startDayKey), let end = date(forLocalDayKey: range.endDayKey) else { return [] }
        var result: [HistoryDailyPoint] = []
        var cursor = start
        while cursor <= end {
            let key = dayKey(for: cursor)
            let total = totals[key, default: (0, 0)]
            result.append(HistoryDailyPoint(localDayKey: key, addedCount: total.added, completedTargetCount: total.targets))
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor)!
        }
        return result
    }

    private func averageDayCount(for range: HistoryPeriodRange) -> Int {
        let today = dayKey(for: referenceDate)
        let end = min(range.endDayKey, today)
        guard let startDate = date(forLocalDayKey: range.startDayKey), let endDate = date(forLocalDayKey: end) else { return 1 }
        return max(1, calendar.dateComponents([.day], from: startDate, to: endDate).day! + 1)
    }

    private func comparison(for period: HistoryPeriod, currentTotal: Int, entries: [HistoryEntry]) -> HistoryComparison? {
        guard period != .all else { return nil }
        let current = range(for: period, entries: entries)
        guard let start = date(forLocalDayKey: current.startDayKey), let end = date(forLocalDayKey: current.endDayKey) else { return nil }
        let previous: HistoryPeriodRange
        switch period {
        case .today:
            let day = calendar.date(byAdding: .day, value: -1, to: start)!
            previous = HistoryPeriodRange(startDayKey: dayKey(for: day), endDayKey: dayKey(for: day))
        case .week:
            let previousStart = calendar.date(byAdding: .day, value: -7, to: start)!
            let previousEnd = calendar.date(byAdding: .day, value: -7, to: end)!
            previous = HistoryPeriodRange(startDayKey: dayKey(for: previousStart), endDayKey: dayKey(for: previousEnd))
        case .month:
            let previousStart = calendar.date(byAdding: .month, value: -1, to: start)!
            let previousEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: previousStart)!
            previous = HistoryPeriodRange(startDayKey: dayKey(for: previousStart), endDayKey: dayKey(for: previousEnd))
        case .all: return nil
        }
        let previousEntries = entries.filter { $0.localDayKey >= previous.startDayKey && $0.localDayKey <= previous.endDayKey }
        let previousTotal = previousEntries.reduce(0) { $0 + $1.addedCount }
        return HistoryComparison(previousAddedCount: previousTotal, difference: currentTotal - previousTotal, previousPeriodHadRecords: !previousEntries.isEmpty)
    }

    private func dhikrStatistics(in entries: [HistoryEntry]) -> [HistoryDhikrStatistic] {
        var grouped: [String: (name: String, added: Int, targets: Int, latestIndex: Int)] = [:]
        for (index, entry) in entries.enumerated() {
            let existing = grouped[entry.dhikrID, default: (entry.dhikrNameSnapshot, 0, 0, -1)]
            grouped[entry.dhikrID] = (index >= existing.latestIndex ? entry.dhikrNameSnapshot : existing.name, existing.added + entry.addedCount, existing.targets + entry.completedTargetCount, max(index, existing.latestIndex))
        }
        return grouped.map { id, value in
            HistoryDhikrStatistic(dhikrID: id, name: value.name, addedCount: value.added, completedTargetCount: value.targets)
        }.sorted {
            if $0.addedCount != $1.addedCount { return $0.addedCount > $1.addedCount }
            let nameOrder = $0.name.localizedCompare($1.name)
            return nameOrder == .orderedSame ? $0.dhikrID < $1.dhikrID : nameOrder == .orderedAscending
        }
    }

    private func dayKey(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year!, components.month!, components.day!)
    }
}
