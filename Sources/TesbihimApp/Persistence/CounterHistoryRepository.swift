import Foundation

/// Sayaç ve geçmişi tek dosyada seri, doğrulanabilir şekilde saklar.
actor CounterHistoryRepository {
    /// `recoveredFromCorruption`: hem ana hem yedek dosya okunamadı/bozuktu;
    /// ikisi de karantinaya alındı (adli inceleme için diskte saklanır,
    /// silinmez) ve bir sonraki `load()` çağrısı güvenli, boş bir
    /// başlangıç durumuna döner. Bu hata sessizce yutulmaz — çağıran taraf
    /// (`CounterViewModel.unifiedPersistenceError`) kullanıcıya bildirebilir;
    /// "sessiz sıfırlama olmaması" kuralı bu şekilde korunur.
    enum RepositoryError: Error, Equatable { case invalidSnapshot, recoveredFromCorruption }

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
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? decoder.decode(CounterHistorySnapshot.self, from: data),
           decoded.schemaVersion == CounterHistorySnapshot.currentSchemaVersion {
            snapshot = decoded
            return decoded
        }

        // Ana dosya okunamadı/bozuk/şema uyumsuz — son bilinen sağlam
        // yedeği dene.
        if let backupData = try? Data(contentsOf: backupURL),
           let backupDecoded = try? decoder.decode(CounterHistorySnapshot.self, from: backupData),
           backupDecoded.schemaVersion == CounterHistorySnapshot.currentSchemaVersion {
            quarantine(fileURL)
            try? encoder.encode(backupDecoded).write(to: fileURL, options: .atomic)
            snapshot = backupDecoded
            return backupDecoded
        }

        // İkisi de bozuk: sessizce sıfırlamak yerine kanıtı karantinaya
        // alıp açık bir hata fırlat. Karantina dosyaları temizlendiği için
        // bir sonraki `load()` güvenli bir başlangıç durumuna döner.
        quarantine(fileURL)
        quarantine(backupURL)
        throw RepositoryError.recoveredFromCorruption
    }

    /// Bozuk dosyayı silmeden, zaman damgalı bir adla kenara taşır — veri
    /// kaybı sessizce olmasın, gerekirse elle incelenebilsin.
    private func quarantine(_ url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let quarantineName = "\(url.deletingPathExtension().lastPathComponent).corrupt-\(Int(Date().timeIntervalSince1970)).json"
        let quarantineURL = url.deletingLastPathComponent().appendingPathComponent(quarantineName)
        try? FileManager.default.removeItem(at: quarantineURL)
        try? FileManager.default.moveItem(at: url, to: quarantineURL)
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
