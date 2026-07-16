import Foundation
import Testing
@testable import TesbihimApp

private final class InMemoryCounterRepository: CounterRepository {
    private(set) var savedStates: [CounterState] = []
    private var state: CounterState

    init(initial: CounterState = .initial) {
        self.state = initial
    }

    func load() -> CounterState { state }

    func save(_ state: CounterState) {
        self.state = state
        savedStates.append(state)
    }
}

private final class InMemoryUserSettingsRepository: UserSettingsRepository {
    private(set) var savedSettings: [UserSettings] = []
    private var settings: UserSettings

    init(initial: UserSettings = .initial) {
        self.settings = initial
    }

    func load() -> UserSettings { settings }

    func save(_ settings: UserSettings) {
        self.settings = settings
        savedSettings.append(settings)
    }
}

@MainActor
private final class RecordingFeedbackProvider: FeedbackProviding {
    private(set) var incrementCount = 0
    private(set) var targetCompletedCount = 0
    private(set) var tickCount = 0
    private(set) var milestoneCount = 0

    func countIncremented() { incrementCount += 1 }
    func targetCompleted() { targetCompletedCount += 1 }
    func countTick() { tickCount += 1 }
    func milestoneReached() { milestoneCount += 1 }
}

extension CounterViewModelTests {
    @Test func milestoneUsesDistinctFeedbackAtCurrentRoundMultiple() {
        let feedback = RecordingFeedbackProvider(); let viewModel = makeViewModel(feedback: feedback)
        viewModel.increment(milestoneInterval: 2); viewModel.increment(milestoneInterval: 2)
        #expect(feedback.milestoneCount == 1)
    }
}

private final class RecordingAnnouncer: AccessibilityAnnouncing {
    private(set) var announcements: [String] = []
    private(set) var interruptingAnnouncements: [String] = []

    func announceQueued(_ message: String) {
        announcements.append(message)
    }

    func announceInterrupting(_ message: String) {
        interruptingAnnouncements.append(message)
    }
}

private final class InMemoryHistoryRepository: HistoryRepository {
    private var entries: [HistoryEntry] = []
    func load() -> [HistoryEntry] { entries }
    func save(_ entries: [HistoryEntry]) { self.entries = entries }
}

@MainActor
private func makeViewModel(
    counterState: CounterState = .initial,
    settings: UserSettings = .initial,
    feedback: RecordingFeedbackProvider = RecordingFeedbackProvider(),
    announcer: RecordingAnnouncer = RecordingAnnouncer(),
    history: HistoryViewModel = HistoryViewModel(repository: InMemoryHistoryRepository())
) -> CounterViewModel {
    CounterViewModel(
        repository: InMemoryCounterRepository(initial: counterState),
        settingsRepository: InMemoryUserSettingsRepository(initial: settings),
        feedback: feedback,
        announcer: announcer,
        history: history
    )
}

@MainActor
struct CounterViewModelTests {
    @Test func incrementPersistsStateAndTriggersFeedback() {
        let repository = InMemoryCounterRepository()
        let feedback = RecordingFeedbackProvider()
        let viewModel = CounterViewModel(
            repository: repository,
            settingsRepository: InMemoryUserSettingsRepository(),
            feedback: feedback,
            announcer: RecordingAnnouncer(),
            history: HistoryViewModel(repository: InMemoryHistoryRepository())
        )

        viewModel.increment()

        #expect(viewModel.currentCount == 1)
        #expect(repository.savedStates.count == 1)
        #expect(feedback.incrementCount == 1)
        #expect(feedback.targetCompletedCount == 0)
    }

    @Test func reachingTargetAnnouncesCompletionAndTriggersFeedback() {
        var initial = CounterState.initial
        initial.target = 2
        let feedback = RecordingFeedbackProvider()
        let announcer = RecordingAnnouncer()
        let viewModel = makeViewModel(counterState: initial, feedback: feedback, announcer: announcer)

        viewModel.increment()
        viewModel.increment()

        #expect(viewModel.currentCount == 0)
        #expect(feedback.targetCompletedCount == 1)
        #expect(announcer.announcements == ["2 tamamlandı; yeni tur 0"])
    }

    @Test func undoAndResetRespectCanUndoCanReset() {
        let viewModel = makeViewModel()

        #expect(viewModel.canUndo == false)
        #expect(viewModel.canReset == false)

        viewModel.increment()
        #expect(viewModel.canUndo)
        #expect(viewModel.canReset)

        viewModel.undo()
        #expect(viewModel.currentCount == 0)
        #expect(viewModel.canUndo == false)
        #expect(viewModel.canReset == false)
    }

    @Test func progressAnnouncementDescribesFreeCounterAndTarget() {
        let viewModel = makeViewModel()
        #expect(viewModel.progressAnnouncement == "Serbest Sayaç seçili, hedef yok")
    }

    @Test func selectingDifferentDhikrResetsCurrentRound() {
        let viewModel = makeViewModel()
        viewModel.increment()
        viewModel.increment()

        viewModel.selectDhikr(id: "subhanallah", target: 33)

        #expect(viewModel.selectedDhikrDisplayName == "Sübhanallah")
        #expect(viewModel.currentCount == 0)
        #expect(viewModel.canUndo == false)
        #expect(viewModel.progressAnnouncement == "33 üzerinden 0, yüzde 0")
    }

    @Test func reselectingSameDhikrAndTargetKeepsProgress() {
        let repository = InMemoryCounterRepository()
        let viewModel = CounterViewModel(
            repository: repository,
            settingsRepository: InMemoryUserSettingsRepository(),
            feedback: RecordingFeedbackProvider(),
            announcer: RecordingAnnouncer(),
            history: HistoryViewModel(repository: InMemoryHistoryRepository())
        )
        viewModel.selectDhikr(id: "subhanallah", target: 33)
        viewModel.increment()

        viewModel.selectDhikr(id: "subhanallah", target: 33)

        #expect(viewModel.currentCount == 1)
    }

    @Test func unknownDhikrIDFallsBackToFreeCounterDisplayName() {
        var state = CounterState.initial
        state.selectedDhikrID = "bilinmeyen-id"
        let viewModel = makeViewModel(counterState: state)
        #expect(viewModel.selectedDhikrDisplayName == "Serbest Sayaç")
    }

    @Test func selectedDhikrSummaryIncludesTargetOrMissingTarget() {
        let viewModel = makeViewModel()
        #expect(viewModel.selectedDhikrSummary == "Serbest Sayaç, hedef belirlenmedi")

        viewModel.selectDhikr(id: "subhanallah", target: 33)
        #expect(viewModel.selectedDhikrSummary == "Sübhanallah, hedef 33")
    }

    @Test func accessibilityContextLabelDescribesFreeCounterAndTarget() {
        let viewModel = makeViewModel()
        #expect(viewModel.accessibilityContextLabel == "Sayım")

        viewModel.selectDhikr(id: "subhanallah", target: 33)
        #expect(viewModel.accessibilityContextLabel == "Sayım")
    }

    @Test func compactCountDisplayUsesCurrentAndTarget() {
        var state = CounterState.initial
        state.target = 36
        state.currentCount = 15
        let viewModel = makeViewModel(counterState: state)

        #expect(viewModel.compactCountDisplay == "15 / 36")
        #expect(viewModel.countProgressDescription == "15 çekildi, hedef 36")
        #expect(viewModel.accessibilitySpokenValue == "15 çekildi, hedef 36")
    }

    @Test func tickPlaysWhenEnabledRegardlessOfSpokenCountSetting() {
        let feedback = RecordingFeedbackProvider()
        let settings = UserSettings(
            hapticIntensity: .medium,
            soundProfile: .light,
            theme: .system,
            keepScreenAwake: false,
            spokenCountEnabled: true,
            soundEffectEnabled: true
        )
        let viewModel = makeViewModel(settings: settings, feedback: feedback)

        #expect(viewModel.accessibilitySpokenValue == "0 çekildi, hedef belirlenmedi")

        viewModel.increment()
        #expect(feedback.tickCount == 1)
        viewModel.undo()
        #expect(feedback.tickCount == 2)

        viewModel.updateSettings { $0.spokenCountEnabled = false }
        #expect(viewModel.accessibilitySpokenValue == "")
        viewModel.increment()
        #expect(feedback.tickCount == 3)
        viewModel.undo()
        #expect(feedback.tickCount == 4)
    }

    @Test func tickDoesNotPlayWhenSoundEffectIsDisabled() {
        let feedback = RecordingFeedbackProvider()
        let settings = UserSettings(
            hapticIntensity: .medium,
            soundProfile: .light,
            theme: .system,
            keepScreenAwake: false,
            spokenCountEnabled: false,
            soundEffectEnabled: false
        )
        let viewModel = makeViewModel(settings: settings, feedback: feedback)

        viewModel.increment()
        viewModel.undo()

        #expect(feedback.tickCount == 0)
    }

    /// `swipeHapticEnabled` artık kaldırılan kaydırma özelliğine aitti
    /// (bkz. karar taslağı Bölüm 9); eski kayıtlı JSON'da bu anahtar
    /// olabilir, `JSONDecoder` bilinmeyen anahtarları sessizce yok
    /// sayar, decode bozulmamalı.
    @Test func legacySettingsJSONPreservesFieldsAndDefaultsSoundEffectToEnabled() throws {
        let json = """
        {
          "hapticIntensity": "strong",
          "soundProfile": "normal",
          "theme": "dark",
          "keepScreenAwake": true,
          "swipeHapticEnabled": false,
          "spokenCountEnabled": false
        }
        """.data(using: .utf8)!

        let settings = try JSONDecoder().decode(UserSettings.self, from: json)

        #expect(settings.hapticIntensity == .strong)
        #expect(settings.soundProfile == .normal)
        #expect(settings.theme == .dark)
        #expect(settings.keepScreenAwake)
        #expect(settings.spokenCountEnabled == false)
        #expect(settings.soundEffectEnabled)
        #expect(settings.fastCountModeEnabled == false)
        #expect(settings.fastCountHapticEnabled)
        #expect(settings.fastCountSoundEnabled)
        #expect(settings.fastCountAnnounceEnabled == false)
    }

    @Test func incrementFastRespectsIndependentHapticAndSoundSettings() {
        let feedback = RecordingFeedbackProvider()
        let settings = UserSettings(
            hapticIntensity: .medium,
            soundProfile: .light,
            theme: .system,
            keepScreenAwake: false,
            spokenCountEnabled: true,
            fastCountHapticEnabled: false,
            fastCountSoundEnabled: true
        )
        let viewModel = makeViewModel(settings: settings, feedback: feedback)

        viewModel.incrementFast()

        #expect(viewModel.currentCount == 1)
        #expect(feedback.incrementCount == 0)
        #expect(feedback.tickCount == 1)
    }

    @Test func incrementFastAnnouncesOnlyWhenSettingEnabledAndDebounced() async {
        let announcer = RecordingAnnouncer()
        let settings = UserSettings(
            hapticIntensity: .medium,
            soundProfile: .light,
            theme: .system,
            keepScreenAwake: false,
            spokenCountEnabled: true,
            fastCountAnnounceEnabled: true
        )
        let viewModel = makeViewModel(settings: settings, announcer: announcer)

        viewModel.incrementFast()
        viewModel.incrementFast()
        viewModel.incrementFast()

        #expect(announcer.interruptingAnnouncements.isEmpty)

        try? await Task.sleep(for: .milliseconds(700))

        #expect(announcer.interruptingAnnouncements == ["3"])
    }

    @Test func incrementFastDoesNotAnnounceWhenSettingDisabled() async {
        let announcer = RecordingAnnouncer()
        let viewModel = makeViewModel(announcer: announcer)

        viewModel.incrementFast()

        try? await Task.sleep(for: .milliseconds(700))

        #expect(announcer.interruptingAnnouncements.isEmpty)
    }

    @Test func fastCountModeAnnouncementsInterruptRatherThanQueue() {
        let announcer = RecordingAnnouncer()
        let viewModel = makeViewModel(announcer: announcer)

        viewModel.announceFastCountModeChange(isEnabled: true)
        viewModel.announceFastCountModeChange(isEnabled: false)

        #expect(announcer.announcements.isEmpty)
        #expect(announcer.interruptingAnnouncements == ["Hızlı sayım açık", "Hızlı sayım kapalı"])
    }

    @Test func fastCountStatusAnnouncementUsesCompactProgress() {
        var state = CounterState.initial
        state.target = 33
        state.currentCount = 12
        let announcer = RecordingAnnouncer()
        let viewModel = makeViewModel(counterState: state, announcer: announcer)

        viewModel.announceFastCountStatus()

        #expect(announcer.interruptingAnnouncements == ["12 / 33"])
    }

    @Test func countingSurfaceSpokenValueReflectsCurrentCountWhenEnabled() {
        let viewModel = makeViewModel()
        #expect(viewModel.accessibilitySpokenValue == "0 çekildi, hedef belirlenmedi")

        viewModel.increment()
        #expect(viewModel.accessibilitySpokenValue == "1 çekildi, hedef belirlenmedi")
    }

    @Test func incrementRecordsHistoryAndUndoReversesIt() {
        let historyRepository = InMemoryHistoryRepository()
        let history = HistoryViewModel(repository: historyRepository)
        var counterState = CounterState.initial
        counterState.target = 2
        let viewModel = makeViewModel(counterState: counterState, history: history)

        viewModel.increment()
        viewModel.increment() // hedefi tamamlar

        #expect(history.today.addedCount == 2)
        #expect(history.today.completedTargetCount == 1)

        viewModel.undo()

        #expect(history.today.addedCount == 1)
        #expect(history.today.completedTargetCount == 0)
    }

    @Test func resetAllDataClearsCounterButNotHistory() {
        let history = HistoryViewModel(repository: InMemoryHistoryRepository())
        let viewModel = makeViewModel(history: history)
        viewModel.selectDhikr(id: "subhanallah", target: 33)
        viewModel.increment()

        viewModel.resetAllData()

        #expect(viewModel.currentCount == 0)
        #expect(viewModel.selectedDhikrDisplayName == "Serbest Sayaç")
        #expect(history.today.addedCount == 1)
    }

    @Test func unifiedSnapshotPersistsCounterAndHistoryTogether() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let snapshotRepository = CounterHistoryRepository(directoryURL: directory)
        let viewModel = CounterViewModel(
            settingsRepository: InMemoryUserSettingsRepository(),
            feedback: RecordingFeedbackProvider(),
            announcer: RecordingAnnouncer(),
            snapshotRepository: snapshotRepository
        )

        await viewModel.reloadUnifiedSnapshot()
        viewModel.increment()
        try await viewModel.flushUnifiedPersistence()

        let persisted = try await snapshotRepository.load()
        #expect(persisted.counter.currentCount == 1)
        #expect(persisted.entries.count == 1)
        #expect(persisted.entries[0].addedCount == 1)
    }

    @Test func updateSettingsPersistsArbitraryFields() {
        let settingsRepository = InMemoryUserSettingsRepository()
        let viewModel = CounterViewModel(
            repository: InMemoryCounterRepository(),
            settingsRepository: settingsRepository,
            feedback: RecordingFeedbackProvider(),
            announcer: RecordingAnnouncer(),
            history: HistoryViewModel(repository: InMemoryHistoryRepository())
        )

        viewModel.updateSettings { $0.hapticIntensity = .strong }
        viewModel.updateSettings { $0.theme = .dark }
        viewModel.updateSettings { $0.soundEffectEnabled = false }

        #expect(viewModel.settings.hapticIntensity == .strong)
        #expect(viewModel.settings.theme == .dark)
        #expect(viewModel.settings.soundEffectEnabled == false)
        #expect(settingsRepository.savedSettings.last?.soundEffectEnabled == false)
    }

    @Test func soundEffectSettingReloadsInFreshViewModel() {
        let settingsRepository = InMemoryUserSettingsRepository()
        let viewModel = CounterViewModel(
            repository: InMemoryCounterRepository(),
            settingsRepository: settingsRepository,
            feedback: RecordingFeedbackProvider(),
            announcer: RecordingAnnouncer(),
            history: HistoryViewModel(repository: InMemoryHistoryRepository())
        )

        viewModel.updateSettings { $0.soundEffectEnabled = false }

        let reloadedViewModel = CounterViewModel(
            repository: InMemoryCounterRepository(),
            settingsRepository: settingsRepository,
            feedback: RecordingFeedbackProvider(),
            announcer: RecordingAnnouncer(),
            history: HistoryViewModel(repository: InMemoryHistoryRepository())
        )

        #expect(reloadedViewModel.settings.soundEffectEnabled == false)
    }
}
