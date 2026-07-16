import Foundation
import Testing
@testable import TesbihimApp

struct CounterHistorySnapshotTests {
    @Test func snapshotKeepsPersistedMutationRevision() {
        let snapshot = CounterHistorySnapshot(
            counter: .initial,
            entries: [],
            mutationRevision: 42
        )

        #expect(snapshot.mutationRevision == 42)
    }

    @Test func localDayKeyUsesGregorianCalendarInsteadOfCurrentCalendar() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 3 * 60 * 60)!
        let date = calendar.date(from: DateComponents(year: 2026, month: 3, day: 30, hour: 0, minute: 30))!

        #expect(LocalDayKey.make(for: date, timeZone: calendar.timeZone) == "2026-03-30")
    }

    @Test func legacyHistoryEntryDerivesCanonicalLocalDayKey() {
        let entry = HistoryEntry(
            date: Date(timeIntervalSince1970: 0),
            dhikrID: "serbest",
            addedCount: 1,
            completedTargetCount: 0
        )

        #expect(entry.localDayKey == LocalDayKey.make(for: entry.date))
    }
}
