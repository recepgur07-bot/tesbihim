import Foundation
import Testing
@testable import TesbihimApp

@MainActor
struct DhikrManagementTests {
    @Test @MainActor func libraryManagerTreatsBundledAndCustomDhikrsUniformly() {
        let customRepo = MemoryCustomRepository([.sample(id: "custom")])
        let stateRepo = MemoryStateRepository([])
        let manager = DhikrLibraryViewModel(customRepository: customRepo, stateRepository: stateRepo)
        #expect(manager.activeDhikrs.contains { $0.id == "subhanallah" && $0.origin == .bundled })
        #expect(manager.activeDhikrs.contains { $0.id == "custom" && $0.origin == .custom })
    }

    @Test @MainActor func removingAndRestoringDhikrMovesItBetweenLists() {
        let customRepo = MemoryCustomRepository([.sample(id: "custom")])
        let stateRepo = MemoryStateRepository([])
        let manager = DhikrLibraryViewModel(customRepository: customRepo, stateRepository: stateRepo,
                                            now: { Date(timeIntervalSince1970: 50) })
        manager.remove(id: "custom")
        #expect(!manager.activeDhikrs.contains { $0.id == "custom" })
        #expect(manager.removedDhikrs.contains { $0.id == "custom" })
        manager.restore(id: "custom")
        #expect(manager.activeDhikrs.contains { $0.id == "custom" })
    }

    @Test @MainActor func permanentlyDeletingBundledDhikrIsRejected() {
        let customRepo = MemoryCustomRepository([])
        let stateRepo = MemoryStateRepository([])
        let manager = DhikrLibraryViewModel(customRepository: customRepo, stateRepository: stateRepo)
        #expect(manager.permanentlyDelete(id: "subhanallah") == false)
        manager.remove(id: "subhanallah")
        manager.resetAndRestore(id: "subhanallah")
        #expect(manager.resolved(id: "subhanallah")?.userState.hasContentOverrides == false)
    }
    @Test func fieldOverrideDistinguishesInheritanceSetAndClear() throws {
        let values: [FieldOverride<String>] = [.inherit, .set("Yeni"), .clear]
        let data = try JSONEncoder().encode(values)
        #expect(try JSONDecoder().decode([FieldOverride<String>].self, from: data) == values)
    }

    @Test func bundledUpdateChangesOnlyInheritedFields() {
        let original = BundledDhikrDefinition.sample(name: "Eski", meaning: "Eski anlam", contentVersion: 1)
        var state = DhikrUserState(dhikrID: original.id)
        state.name = .set("Kullanıcı adı")
        state.meaning = .clear
        let updated = BundledDhikrDefinition.sample(name: "Yeni", meaning: "Yeni anlam", contentVersion: 2)

        let resolved = ResolvedDhikr.resolve(updated, state: state)

        #expect(resolved.name == "Kullanıcı adı")
        #expect(resolved.meaning == nil)
        #expect(resolved.contentVersion == 2)
    }

    @Test func resetContentOverridesKeepsReminderAndFeedbackPreferences() {
        var state = DhikrUserState(dhikrID: "subhanallah")
        state.name = .set("Özel ad")
        state.reminders = [ReminderSchedule(weekday: 2, hour: 9, minute: 30)]
        state.soundOverride = .off
        state.resetContentOverrides()

        #expect(state.name == .inherit)
        #expect(state.reminders.first?.hour == 9)
        #expect(state.soundOverride == .off)
    }

    @Test func purgeDeletesOnlyCustomDhikrRemovedAtLeastThirtyDaysAgo() {
        let now = Date(timeIntervalSince1970: 4_000_000)
        let old = CustomDhikr.sample(id: "old")
        let recent = CustomDhikr.sample(id: "recent")
        let repository = MemoryCustomRepository([old, recent])
        let stateRepository = MemoryStateRepository([
            DhikrUserState(dhikrID: "old", removedAt: now.addingTimeInterval(-31 * 86_400)),
            DhikrUserState(dhikrID: "recent", removedAt: now.addingTimeInterval(-29 * 86_400)),
            DhikrUserState(dhikrID: "subhanallah", removedAt: now.addingTimeInterval(-60 * 86_400))
        ])
        let manager = DhikrLibraryViewModel(customRepository: repository, stateRepository: stateRepository, now: { now })

        #expect(manager.removedDhikrs.map(\.id).contains("old") == false)
        #expect(manager.removedDhikrs.map(\.id).contains("recent"))
        #expect(manager.removedDhikrs.map(\.id).contains("subhanallah"))
    }

    @Test func creatingCustomDhikrUsesOneStableIDAndPersistsPolicyAndMilestone() {
        var existing = CustomDhikr.sample(id: "existing-same-name"); existing.name = "Aynı ad"
        let repository = MemoryCustomRepository([existing]); let states = MemoryStateRepository([])
        let manager = DhikrLibraryViewModel(customRepository: repository, stateRepository: states)
        let id = "generated-once"
        manager.saveCustomDraft(id: id, name: "Aynı ad", arabicText: nil, meaning: nil,
                                defaultTarget: 33, category: .diger, completionPolicy: .cycle,
                                milestoneInterval: 11, existingCreatedAt: nil, now: .distantFuture)
        #expect(repository.values.contains { $0.id == id && $0.name == "Aynı ad" })
        #expect(repository.values.contains { $0.id == "existing-same-name" })
        #expect(states.values.single()?.dhikrID == id)
        #expect(states.values.single()?.completionPolicy == .cycle)
        #expect(states.values.single()?.milestoneInterval == 11)
    }

    @Test func premiumFeedbackCharacterRequiresEntitlement() {
        #expect(FeedbackCharacterAccess.canSelect(.system, entitlement: LockedEntitlement()))
        #expect(!FeedbackCharacterAccess.canSelect(.wood, entitlement: LockedEntitlement()))
        #expect(FeedbackCharacterAccess.canSelect(.wood, entitlement: UnlockedEntitlement()))
    }

    @Test func libraryRowPresentationMarksSelectedDhikrVisuallyAndAccessibly() {
        let selected = DhikrLibraryRowPresentation(dhikrID: "a", selectedDhikrID: "a")
        let other = DhikrLibraryRowPresentation(dhikrID: "b", selectedDhikrID: "a")
        #expect(selected.showsSelectionIndicator)
        #expect(selected.accessibilityValue == "Seçili")
        #expect(!other.showsSelectionIndicator)
        #expect(other.accessibilityValue.isEmpty)
    }
}

private struct LockedEntitlement: EntitlementProviding { let isSupporterUnlocked = false }
private struct UnlockedEntitlement: EntitlementProviding { let isSupporterUnlocked = true }

private extension Array {
    func single() -> Element? { count == 1 ? first : nil }
}

private extension BundledDhikrDefinition {
    static func sample(name: String, meaning: String, contentVersion: Int) -> Self {
        .init(id: "sample", category: .tesbihat, arabicText: "", transliteration: name, meaning: meaning, defaultTarget: 33, source: "", contentVersion: contentVersion)
    }
}

private extension CustomDhikr {
    static func sample(id: String) -> Self {
        .init(id: id, name: id, arabicText: nil, meaning: nil, defaultTarget: nil, category: .diger, createdAt: .distantPast, updatedAt: .distantPast)
    }
}

private final class MemoryCustomRepository: CustomDhikrRepository {
    var values: [CustomDhikr]
    init(_ values: [CustomDhikr]) { self.values = values }
    func load() -> [CustomDhikr] { values }
    func save(_ values: [CustomDhikr]) { self.values = values }
}

private final class MemoryStateRepository: DhikrUserStateRepository {
    var values: [DhikrUserState]
    init(_ values: [DhikrUserState]) { self.values = values }
    func load() -> [DhikrUserState] { values }
    func save(_ values: [DhikrUserState]) { self.values = values }
}
