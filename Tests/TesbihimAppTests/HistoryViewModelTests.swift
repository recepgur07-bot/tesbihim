import Testing
import Foundation
@testable import TesbihimApp

private final class InMemoryHistoryRepository: HistoryRepository {
    private(set) var savedEntries: [[HistoryEntry]] = []
    private var entries: [HistoryEntry]

    init(initial: [HistoryEntry] = []) {
        self.entries = initial
    }

    func load() -> [HistoryEntry] { entries }

    func save(_ entries: [HistoryEntry]) {
        self.entries = entries
        savedEntries.append(entries)
    }
}

struct HistoryViewModelTests {
    private var calendar: Calendar { Calendar(identifier: .gregorian) }

    @Test func recordingNewDeltaCreatesTodayEntry() {
        let viewModel = HistoryViewModel(repository: InMemoryHistoryRepository())
        viewModel.recordDelta(dhikrID: "subhanallah", addedCountDelta: 1, completedTargetDelta: 0)

        #expect(viewModel.today.addedCount == 1)
        #expect(viewModel.today.completedTargetCount == 0)
        #expect(viewModel.total.addedCount == 1)
    }

    @Test func recordingSameDayDhikrAggregatesIntoSingleEntry() {
        let viewModel = HistoryViewModel(repository: InMemoryHistoryRepository())
        viewModel.recordDelta(dhikrID: "subhanallah", addedCountDelta: 1, completedTargetDelta: 0)
        viewModel.recordDelta(dhikrID: "subhanallah", addedCountDelta: 1, completedTargetDelta: 0)
        viewModel.recordDelta(dhikrID: "subhanallah", addedCountDelta: 1, completedTargetDelta: 1)

        #expect(viewModel.entries.count == 1)
        #expect(viewModel.today.addedCount == 3)
        #expect(viewModel.today.completedTargetCount == 1)
    }

    @Test func undoDeltaDecrementsWithoutGoingNegative() {
        let viewModel = HistoryViewModel(repository: InMemoryHistoryRepository())
        viewModel.recordDelta(dhikrID: "subhanallah", addedCountDelta: 1, completedTargetDelta: 0)
        viewModel.recordDelta(dhikrID: "subhanallah", addedCountDelta: -1, completedTargetDelta: 0)
        viewModel.recordDelta(dhikrID: "subhanallah", addedCountDelta: -1, completedTargetDelta: 0)

        #expect(viewModel.today.addedCount == 0)
    }

    @Test func totalIncludesEntriesFromPreviousDaysButTodayDoesNot() {
        let calendar = self.calendar
        let today = calendar.startOfDay(for: Date())
        let lastWeek = calendar.date(byAdding: .day, value: -10, to: today)!
        let repository = InMemoryHistoryRepository(initial: [
            HistoryEntry(date: lastWeek, dhikrID: "subhanallah", addedCount: 33, completedTargetCount: 1)
        ])
        let viewModel = HistoryViewModel(repository: repository, calendar: calendar)

        #expect(viewModel.today.addedCount == 0)
        #expect(viewModel.thisWeek.addedCount == 0)
        #expect(viewModel.total.addedCount == 33)
    }

    @Test func breakdownByDhikrGroupsAcrossDays() {
        let calendar = self.calendar
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let repository = InMemoryHistoryRepository(initial: [
            HistoryEntry(date: yesterday, dhikrID: "subhanallah", addedCount: 33, completedTargetCount: 1),
            HistoryEntry(date: today, dhikrID: "subhanallah", addedCount: 10, completedTargetCount: 0),
            HistoryEntry(date: today, dhikrID: "estagfirullah", addedCount: 5, completedTargetCount: 0)
        ])
        let viewModel = HistoryViewModel(repository: repository, calendar: calendar)

        let subhanallah = viewModel.breakdownByDhikr.first { $0.dhikrID == "subhanallah" }
        #expect(subhanallah?.addedCount == 43)
        #expect(subhanallah?.completedTargetCount == 1)
        #expect(viewModel.breakdownByDhikr.count == 2)
    }

    @Test func clearHistoryEmptiesEntriesAndPersists() {
        let repository = InMemoryHistoryRepository()
        let viewModel = HistoryViewModel(repository: repository)
        viewModel.recordDelta(dhikrID: "subhanallah", addedCountDelta: 5, completedTargetDelta: 0)

        viewModel.clearHistory()

        #expect(viewModel.entries.isEmpty)
        #expect(repository.savedEntries.last?.isEmpty == true)
    }
}
