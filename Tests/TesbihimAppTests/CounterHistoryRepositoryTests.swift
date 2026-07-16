import Foundation
import Testing
@testable import TesbihimApp

struct CounterHistoryRepositoryTests {
    @Test func mutationSerializesAndPersistsRevision() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let repository = CounterHistoryRepository(directoryURL: directory)
        let first = try await repository.mutate { snapshot in
            snapshot.counter.currentCount += 1
        }
        let second = try await repository.mutate { snapshot in
            snapshot.counter.currentCount += 1
        }

        #expect(first.counter.currentCount == 1)
        #expect(second.counter.currentCount == 2)
        #expect(second.mutationRevision == first.mutationRevision + 1)
    }

    @Test func corruptPrimaryLoadsLastVerifiedBackup() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let repository = CounterHistoryRepository(directoryURL: directory)
        _ = try await repository.mutate { $0.counter.currentCount = 7 }
        try Data("bozuk".utf8).write(to: directory.appendingPathComponent("counter-history.json"))

        let recovered = try await CounterHistoryRepository(directoryURL: directory).load()

        #expect(recovered.counter.currentCount == 7)
    }

    @Test func migratesLegacyCounterWithoutDiscardingItsCount() async throws {
        var legacy = CounterState.initial
        legacy.currentCount = 12
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let snapshot = try await CounterHistoryRepository(directoryURL: directory, legacyCounterData: try JSONEncoder().encode(legacy)).load()

        #expect(snapshot.counter.currentCount == 12)
    }

    @Test func migratesLegacyHistoryEntries() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let legacy = [HistoryEntry(date: .distantPast, dhikrID: "a", addedCount: 9, completedTargetCount: 1)]

        let snapshot = try await CounterHistoryRepository(directoryURL: directory, legacyHistoryData: try JSONEncoder().encode(legacy)).load()

        #expect(snapshot.entries.first?.addedCount == 9)
    }

    @Test func clearingAllHistoryPreservesTheCounter() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = CounterHistoryRepository(directoryURL: directory)

        _ = try await repository.mutate { snapshot in
            snapshot.counter.currentCount = 21
            snapshot.entries = [
                HistoryEntry(date: .now, dhikrID: "a", addedCount: 8, completedTargetCount: 1),
                HistoryEntry(date: .now, dhikrID: "b", addedCount: 13, completedTargetCount: 2)
            ]
        }

        let cleared = try await repository.clearHistory()

        #expect(cleared.counter.currentCount == 21)
        #expect(cleared.entries.isEmpty)
        #expect(cleared.mutationRevision == 2)
    }

    @Test func clearingDhikrHistoryRemovesOnlyMatchingEntries() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = CounterHistoryRepository(directoryURL: directory)

        _ = try await repository.mutate { snapshot in
            snapshot.counter.currentCount = 21
            snapshot.entries = [
                HistoryEntry(date: .now, dhikrID: "a", addedCount: 8, completedTargetCount: 1),
                HistoryEntry(date: .now, dhikrID: "b", addedCount: 13, completedTargetCount: 2),
                HistoryEntry(date: .distantPast, dhikrID: "a", addedCount: 5, completedTargetCount: 0)
            ]
        }

        let cleared = try await repository.clearHistory(forDhikrID: "a")

        #expect(cleared.counter.currentCount == 21)
        #expect(cleared.entries.map(\.dhikrID) == ["b"])
        #expect(cleared.mutationRevision == 2)
    }

    @Test func mutationNormalizesNegativeHistoryCounts() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = CounterHistoryRepository(directoryURL: directory)

        let persisted = try await repository.mutate { snapshot in
            snapshot.entries = [
                HistoryEntry(date: .now, dhikrID: "a", addedCount: -1, completedTargetCount: -2)
            ]
        }

        #expect(persisted.entries.first?.addedCount == 0)
        #expect(persisted.entries.first?.completedTargetCount == 0)
    }
}
