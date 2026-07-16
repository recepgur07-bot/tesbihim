import Foundation
import Testing
@testable import TesbihimApp

struct HistoryStatisticsCalculatorTests {
    private let timeZone = TimeZone(secondsFromGMT: 3 * 60 * 60)!

    @Test func weekStartsOnMondayAndIncludesZeroValueDays() {
        let calculator = calculator(on: "2026-07-16") // Thursday
        let summary = calculator.summary(
            for: .week,
            entries: [entry("2026-07-13", id: "a", name: "A", count: 10)]
        )

        #expect(summary.range.startDayKey == "2026-07-13")
        #expect(summary.dailyPoints.map(\.localDayKey) == [
            "2026-07-13", "2026-07-14", "2026-07-15", "2026-07-16", "2026-07-17", "2026-07-18", "2026-07-19"
        ])
        #expect(summary.dailyPoints.map(\.addedCount) == [10, 0, 0, 0, 0, 0, 0])
        #expect(summary.averageAddedCount == 2.5)
    }

    @Test func ongoingMonthAverageOnlyUsesDaysThroughReferenceDay() {
        let calculator = calculator(on: "2026-07-16")
        let summary = calculator.summary(
            for: .month,
            entries: [entry("2026-07-01", id: "a", name: "A", count: 16)]
        )

        #expect(summary.averageAddedCount == 1)
        #expect(summary.dailyPoints.count == 31)
    }

    @Test func allTimeOmitsAverageAndComparison() {
        let calculator = calculator(on: "2026-07-16")
        let summary = calculator.summary(
            for: .all,
            entries: [entry("2026-06-01", id: "a", name: "A", count: 5)]
        )

        #expect(summary.averageAddedCount == nil)
        #expect(summary.comparison == nil)
    }

    @Test func comparisonRepresentsPreviousEmptyPeriodWithoutPercentage() {
        let calculator = calculator(on: "2026-07-16")
        let summary = calculator.summary(
            for: .today,
            entries: [entry("2026-07-16", id: "a", name: "A", count: 5)]
        )

        #expect(summary.comparison?.previousAddedCount == 0)
        #expect(summary.comparison?.difference == 5)
        #expect(summary.comparison?.previousPeriodHadRecords == false)
    }

    @Test func dhikrBreakdownUsesNameThenIDForDeterministicTies() {
        let calculator = calculator(on: "2026-07-16")
        let summary = calculator.summary(
            for: .today,
            entries: [
                entry("2026-07-16", id: "z", name: "Aynı", count: 3),
                entry("2026-07-16", id: "a", name: "Aynı", count: 3),
                entry("2026-07-16", id: "b", name: "Başka", count: 3)
            ]
        )

        #expect(summary.dhikrBreakdown.map(\.dhikrID) == ["a", "z", "b"])
        #expect(summary.mostPerformedDhikr?.dhikrID == "a")
    }

    @Test func busiestDayUsesNewestDayForEqualCounts() {
        let calculator = calculator(on: "2026-07-16")
        let summary = calculator.summary(
            for: .week,
            entries: [
                entry("2026-07-14", id: "a", name: "A", count: 9),
                entry("2026-07-15", id: "b", name: "B", count: 9)
            ]
        )

        #expect(summary.busiestDay?.localDayKey == "2026-07-15")
    }

    @Test func canonicalDayKeyConversionIsGregorianAndStable() {
        let calculator = calculator(on: "2026-07-16")
        #expect(calculator.date(forLocalDayKey: "2026-02-28") != nil)
        #expect(calculator.date(forLocalDayKey: "2026-02-30") == nil)
    }

    private func calculator(on dayKey: String) -> HistoryStatisticsCalculator {
        HistoryStatisticsCalculator(referenceDate: LocalDayKeyDate.make(dayKey, timeZone: timeZone), timeZone: timeZone)
    }

    private func entry(_ dayKey: String, id: String, name: String, count: Int, targets: Int = 0) -> HistoryEntry {
        HistoryEntry(date: LocalDayKeyDate.make(dayKey, timeZone: timeZone), dhikrID: id, dhikrNameSnapshot: name, addedCount: count, completedTargetCount: targets)
    }
}

private enum LocalDayKeyDate {
    static func make(_ key: String, timeZone: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = key.split(separator: "-").compactMap { Int($0) }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))!
    }
}
