import Foundation
import Observation

/// Sayaç ekranının durumunu ve Bölüm 7.1'deki kurallarını yönetir.
/// Min iOS 17 kesinleştiği için `@Observable` kullanılır (bkz. Bölüm 3).
@MainActor
@Observable
final class CounterViewModel {
    private(set) var state: CounterState
    private(set) var settings: UserSettings
    private let repository: CounterRepository
    private let settingsRepository: UserSettingsRepository
    private let feedback: FeedbackProviding
    private let announcer: AccessibilityAnnouncing
    private let history: HistoryViewModel
    private let snapshotRepository: CounterHistoryRepository?
    private var unifiedPersistenceTask: Task<Void, Never>?
    private(set) var unifiedPersistenceError: Error?
    private var fastCountAnnounceTask: Task<Void, Never>?
    private var resolvedDisplayName: String?

    init(
        repository: CounterRepository = UserDefaultsCounterRepository(),
        settingsRepository: UserSettingsRepository = UserDefaultsUserSettingsRepository(),
        feedback: FeedbackProviding = SystemFeedbackProvider(),
        announcer: AccessibilityAnnouncing = SystemAccessibilityAnnouncer(),
        history: HistoryViewModel? = nil,
        snapshotRepository: CounterHistoryRepository? = nil
    ) {
        self.repository = repository
        self.settingsRepository = settingsRepository
        self.feedback = feedback
        self.announcer = announcer
        self.snapshotRepository = snapshotRepository
        self.history = history ?? HistoryViewModel()
        self.state = snapshotRepository == nil ? repository.load() : .initial
        self.settings = settingsRepository.load()
    }

    /// Ayarlar ekranındaki (Bölüm 7.4) diğer alanlar için tek giriş
    /// noktası.
    func updateSettings(_ transform: (inout UserSettings) -> Void) {
        transform(&settings)
        settingsRepository.save(settings)
    }

    /// Geçmiş ekranı da aynı örneği kullanır — bkz. `RootTabView` (tek
    /// kaynak, sekmeler arası tutarsız state riskini önler).
    var historyViewModel: HistoryViewModel { history }

    /// Birleşik snapshot kullanılırken ilk görünümden önce actor'daki son
    /// sağlam veriyi alır. Bu açık async sınır, UI'ı disk erişiminde
    /// bloklamaz ve testlerin yüklemeyi deterministik beklemesini sağlar.
    func reloadUnifiedSnapshot() async {
        guard let snapshotRepository else { return }
        do {
            let snapshot = try await snapshotRepository.load()
            state = snapshot.counter
            history.replaceEntries(snapshot.entries)
            unifiedPersistenceError = nil
        } catch {
            unifiedPersistenceError = error
        }
    }

    /// Sıraya alınmış birleşik yazımın bitmesini bekler. Görünüm bunu
    /// çağırmak zorunda değildir; özellikle kontrollü kapanış ve testlerde
    /// kullanılır.
    func flushUnifiedPersistence() async throws {
        await unifiedPersistenceTask?.value
        if let unifiedPersistenceError { throw unifiedPersistenceError }
    }

    var selectedDhikrDisplayName: String {
        if let resolvedDisplayName { return resolvedDisplayName }
        return (DhikrLibrary.definition(for: state.selectedDhikrID) ?? .freeCounter).turkishTransliteration
    }
    func updateResolvedDisplayName(_ name: String?) { resolvedDisplayName = name }

    var selectedDhikrSummary: String {
        guard let target = state.target, target > 0 else {
            return "\(selectedDhikrDisplayName), hedef belirlenmedi"
        }
        return "\(selectedDhikrDisplayName), hedef \(target)"
    }

    var currentCount: Int { state.currentCount }
    var canUndo: Bool { state.canUndo }
    var canReset: Bool { state.canReset }

    /// Bölüm 7.1 madde 2: "33 üzerinden 18, yüzde 55" / hedefsizken
    /// "Serbest Sayaç seçili, hedef yok".
    var progressAnnouncement: String {
        guard let target = state.target, target > 0 else {
            return "Serbest Sayaç seçili, hedef yok"
        }
        let percent = Int((Double(state.currentCount) / Double(target) * 100).rounded())
        return "\(target) üzerinden \(state.currentCount), yüzde \(percent)"
    }

    var compactCountDisplay: String {
        guard let target = state.target, target > 0 else { return "\(state.currentCount)" }
        return "\(state.currentCount) / \(target)"
    }

    var countProgressDescription: String {
        guard let target = state.target, target > 0 else {
            return "\(state.currentCount) çekildi, hedef belirlenmedi"
        }
        return "\(state.currentCount) çekildi, hedef \(target)"
    }

    /// Sayma alanının `accessibilityLabel`'i — hedef bilgisini taşır,
    /// böylece her kaydırmada tekrar okunmaz (sadece `accessibilityValue`
    /// okunur), yalnızca elemana ilk odaklanıldığında duyulur. Bkz.
    /// 2026-07-15-sayac-sayma-alani-karar-taslagi.md Bölüm 4.2.
    var accessibilityContextLabel: String {
        guard let target = state.target, target > 0 else {
            return "Sayım"
        }
        return "Sayım"
    }

    /// Sayma yüzeyinin `accessibilityValue`'sü. `spokenCountEnabled`
    /// kapalıyken boş string döner — VoiceOver'ın her etkileşimde otomatik
    /// okuduğu içerik böylece kalmaz, sayı sesli söylenmez (mute API'si
    /// yok ama okunacak içeriği boş bırakmak aynı sonucu verir).
    var accessibilitySpokenValue: String {
        settings.spokenCountEnabled ? countProgressDescription : ""
    }

    /// `soundEffectEnabled` açıksa (Say düğmesi dahil, her yerde tutarlı
    /// olsun diye) titreşimin yanına kısa bir ses efekti (`countTick`)
    /// eklenir.
    func increment(milestoneInterval: Int? = nil, soundOverride: SettingOverride = .inherit, hapticOverride: SettingOverride = .inherit) {
        let target = state.target
        let didCompleteTarget = state.increment()
        history.recordDelta(
            dhikrID: state.selectedDhikrID,
            dhikrName: selectedDhikrDisplayName,
            addedCountDelta: 1,
            completedTargetDelta: didCompleteTarget ? 1 : 0
        )
        persist()
        if let interval = milestoneInterval, interval > 0, state.currentCount > 0, state.currentCount % interval == 0, !didCompleteTarget { feedback.milestoneReached() }
        else { feedback.countFeedback(hapticEnabled: hapticOverride == .off ? false : true, soundEnabled: soundOverride == .off ? false : (soundOverride == .on || settings.soundEffectEnabled)) }
        if didCompleteTarget {
            feedback.targetCompleted()
            announcer.announceQueued("\(target ?? 0) tamamlandı; yeni tur 0")
        }
    }

    /// Hızlı Sayım yüzeyindeki her tek dokunuş için — bkz. karar taslağı
    /// Bölüm 7. `increment()`'tan kasıtlı olarak ayrı: geri bildirim
    /// burada genel `soundEffectEnabled` yerine Hızlı Sayım'a özel
    /// `fastCount*` ayarlarına tabidir, çünkü çok hızlı art arda
    /// dokunuşta aynı davranışın (özellikle sesli duyuru) farklı bir
    /// denge gerektirdiği görüldü (bkz. Bölüm 6.4/7).
    func incrementFast(milestoneInterval: Int? = nil, soundOverride: SettingOverride = .inherit, hapticOverride: SettingOverride = .inherit) {
        let target = state.target
        let didCompleteTarget = state.increment()
        history.recordDelta(
            dhikrID: state.selectedDhikrID,
            dhikrName: selectedDhikrDisplayName,
            addedCountDelta: 1,
            completedTargetDelta: didCompleteTarget ? 1 : 0
        )
        persist()
        if let interval = milestoneInterval, interval > 0, state.currentCount > 0, state.currentCount % interval == 0, !didCompleteTarget { feedback.milestoneReached() }
        else { feedback.countFeedback(hapticEnabled: hapticOverride == .off ? false : (hapticOverride == .on || settings.fastCountHapticEnabled), soundEnabled: soundOverride == .off ? false : (soundOverride == .on || settings.fastCountSoundEnabled)) }
        if didCompleteTarget {
            feedback.targetCompleted()
            announcer.announceQueued("\(target ?? 0) tamamlandı; yeni tur 0")
        } else if settings.fastCountAnnounceEnabled {
            scheduleDebouncedFastCountAnnouncement()
        }
    }

    /// Hızlı Sayım geçişi mevcut konuşmayı keserek tek ve güncel bir durum
    /// bilgisi verir; hızlı modda eski anonsların kuyrukta kalmaması gerekir.
    func announceFastCountModeChange(isEnabled: Bool) {
        announcer.announceInterrupting(isEnabled ? "Hızlı sayım açık" : "Hızlı sayım kapalı")
    }

    func announceFastCountStatus() {
        let status = state.target.map { "\(state.currentCount) / \($0)" } ?? "\(state.currentCount)"
        announcer.announceInterrupting(status)
    }

    /// Dokunuşlar durduktan ~500ms sonra sadece o anki sayıyı bir kez
    /// duyurur; her dokunuşta ayrı anons göndermek hızlı art arda
    /// dokunuşta VoiceOver'ın konuşma kuyruğunu doldurup gecikmeli
    /// okumaya yol açar (bkz. Bölüm 7 — swipe'ta gözlemlenen aynı sorun).
    private func scheduleDebouncedFastCountAnnouncement() {
        fastCountAnnounceTask?.cancel()
        let countAtSchedule = state.currentCount
        fastCountAnnounceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled, let self else { return }
            self.announcer.announceInterrupting("\(countAtSchedule)")
        }
    }

    /// Zikir Kütüphanesi'nde "Bu Zikri Seç" onayı — bkz. Bölüm 7.2. Zikir
    /// veya hedef gerçekten değişiyorsa güncel tur ve tamamlanan hedef
    /// sayısı sıfırlanır (farklı bir zikre geçmek eski sayımı taşımaz);
    /// aynı zikir + aynı hedef yeniden onaylanırsa mevcut sayım korunur.
    func selectDhikr(id: String, target: Int?) {
        guard state.selectedDhikrID != id || state.target != target else { return }
        state.selectedDhikrID = id
        state.target = target
        state.currentCount = 0
        state.completedTargetCount = 0
        state.lastIncrement = nil
        resolvedDisplayName = nil
        persist()
    }

    func undo() {
        guard state.canUndo else { return }
        let wasTargetCompletion = state.lastIncrement?.completedTarget ?? false
        let dhikrID = state.selectedDhikrID
        state.undoLastIncrement()
        history.recordDelta(
            dhikrID: dhikrID,
            dhikrName: selectedDhikrDisplayName,
            addedCountDelta: -1,
            completedTargetDelta: wasTargetCompletion ? -1 : 0
        )
        persist()
        feedback.countFeedback(playsSound: settings.soundEffectEnabled)
    }

    func reset() {
        guard state.canReset else { return }
        state.reset()
        persist()
    }

    func setCurrentCount(_ value: Int) {
        let old = state.currentCount
        state.currentCount = min(max(0, value), state.target.map { max(0, $0 - 1) } ?? Int.max)
        state.lastIncrement = nil
        state.updatedAt = Date()
        history.recordDelta(dhikrID: state.selectedDhikrID, dhikrName: selectedDhikrDisplayName, addedCountDelta: state.currentCount - old, completedTargetDelta: 0)
        persist()
    }

    /// Ayarlar/Geçmiş ekranındaki "Tüm Verilerimi Sil" — bkz. Bölüm 7.3.
    /// Geçmiş kayıtları ayrıca `HistoryViewModel.clearHistory()` ile
    /// silinir; burası yalnızca güncel zikir sayaç durumunu sıfırlar.
    func resetAllData() {
        state = CounterState(
            selectedDhikrID: DhikrDefinition.freeCounter.id,
            target: nil,
            currentCount: 0,
            completedTargetCount: 0,
            updatedAt: Date(),
            lastIncrement: nil
        )
        persist()
    }

    private func persist() {
        guard let snapshotRepository else {
            repository.save(state)
            return
        }

        let counter = state
        let entries = history.entries
        unifiedPersistenceTask = Task { [weak self, snapshotRepository, counter, entries] in
            do {
                let persisted = try await snapshotRepository.replace(counter: counter, entries: entries)
                guard let self else { return }
                self.history.replaceEntries(persisted.entries)
                self.unifiedPersistenceError = nil
            } catch {
                self?.unifiedPersistenceError = error
            }
        }
    }
}
