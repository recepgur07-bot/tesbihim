import Foundation

/// Sayaç ve geçmişi tek dosyada seri, doğrulanabilir şekilde saklar.
actor CounterHistoryRepository {
    enum RepositoryError: Error { case invalidSnapshot }

    private let fileURL: URL
    private let backupURL: URL
    private let legacyCounterData: Data?
    private let legacyHistoryData: Data?
    private var snapshot: CounterHistorySnapshot?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(directoryURL: URL, legacyCounterData: Data? = nil, legacyHistoryData: Data? = nil) {
        self.fileURL = directoryURL.appendingPathComponent("counter-history.json")
        self.backupURL = directoryURL.appendingPathComponent("counter-history.backup.json")
        self.legacyCounterData = legacyCounterData
        self.legacyHistoryData = legacyHistoryData
    }

    func load() throws -> CounterHistorySnapshot {
        if let snapshot { return snapshot }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            let legacyCounter: CounterState
            if let data = legacyCounterData,
               let decoded = try? decoder.decode(CounterState.self, from: data) {
                legacyCounter = decoded
            } else {
                legacyCounter = .initial
            }
            let legacyEntries = legacyHistoryData.flatMap { try? decoder.decode([HistoryEntry].self, from: $0) } ?? []
            let initial = CounterHistorySnapshot(counter: legacyCounter, entries: legacyEntries)
            snapshot = initial
            return initial
        }
        let data = try Data(contentsOf: fileURL)
        let decoded: CounterHistorySnapshot
        do {
            decoded = try decoder.decode(CounterHistorySnapshot.self, from: data)
        } catch {
            let backupData = try Data(contentsOf: backupURL)
            decoded = try decoder.decode(CounterHistorySnapshot.self, from: backupData)
        }
        guard decoded.schemaVersion == CounterHistorySnapshot.currentSchemaVersion else {
            throw RepositoryError.invalidSnapshot
        }
        snapshot = decoded
        return decoded
    }

    func mutate(_ operation: (inout CounterHistorySnapshot) -> Void) throws -> CounterHistorySnapshot {
        var next = try load()
        operation(&next)
        for index in next.entries.indices {
            next.entries[index].addedCount = max(0, next.entries[index].addedCount)
            next.entries[index].completedTargetCount = max(0, next.entries[index].completedTargetCount)
        }
        next.mutationRevision += 1
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try encoder.encode(next)
        try data.write(to: fileURL, options: .atomic)
        let verified = try decoder.decode(CounterHistorySnapshot.self, from: Data(contentsOf: fileURL))
        try encoder.encode(verified).write(to: backupURL, options: .atomic)
        snapshot = verified
        return verified
    }

    /// Ana aktörden closure aktarmadan, sayaç ve geçmişi aynı revision'da
    /// kalıcılaştıran ortak ViewModel yazım noktası.
    func replace(counter: CounterState, entries: [HistoryEntry]) throws -> CounterHistorySnapshot {
        try mutate { snapshot in
            snapshot.counter = counter
            snapshot.entries = entries
        }
    }

    /// Tüm geçmiş agregasyonlarını siler; etkin sayaç durumu değişmeden kalır.
    func clearHistory() throws -> CounterHistorySnapshot {
        try mutate { $0.entries.removeAll() }
    }

    /// Yalnız seçili zikrin geçmiş agregasyonlarını siler; sayaç ve diğer
    /// zikirlerin geçmişi değişmeden kalır.
    func clearHistory(forDhikrID dhikrID: String) throws -> CounterHistorySnapshot {
        try mutate { snapshot in
            snapshot.entries.removeAll { $0.dhikrID == dhikrID }
        }
    }
}
