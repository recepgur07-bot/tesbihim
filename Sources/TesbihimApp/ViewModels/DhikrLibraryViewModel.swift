import Foundation
import Observation

@MainActor
@Observable
final class DhikrLibraryViewModel {
    private(set) var customDhikrs: [CustomDhikr]
    private(set) var states: [DhikrUserState]
    private let customRepository: CustomDhikrRepository
    private let stateRepository: DhikrUserStateRepository
    private let now: () -> Date
    private let reminderManager: ReminderManager

    init(customRepository: CustomDhikrRepository = UserDefaultsCustomDhikrRepository(),
         stateRepository: DhikrUserStateRepository = UserDefaultsDhikrUserStateRepository(),
         reminderManager: ReminderManager = ReminderManager(),
         now: @escaping () -> Date = Date.init) {
        self.customRepository = customRepository; self.stateRepository = stateRepository; self.reminderManager = reminderManager; self.now = now
        DhikrRemovalService(customRepository: customRepository, stateRepository: stateRepository, now: now).purgeExpiredCustomDhikrs()
        customDhikrs = customRepository.load(); states = stateRepository.load()
    }

    var allDhikrs: [ResolvedDhikr] {
        DhikrLibrary.all.map { ResolvedDhikr.resolve($0, state: state(for: $0.id)) } +
        customDhikrs.map { ResolvedDhikr.resolve($0, state: state(for: $0.id)) }
    }
    var activeDhikrs: [ResolvedDhikr] { allDhikrs.filter { $0.userState.removedAt == nil } }
    var removedDhikrs: [ResolvedDhikr] { allDhikrs.filter { $0.userState.removedAt != nil } }
    func resolved(id: String) -> ResolvedDhikr? { allDhikrs.first { $0.id == id } }

    func saveCustom(_ item: CustomDhikr) {
        if let index = customDhikrs.firstIndex(where: { $0.id == item.id }) { customDhikrs[index] = item } else { customDhikrs.append(item) }
        customRepository.save(customDhikrs)
    }
    func saveCustomDraft(id: String, name: String, arabicText: String?, meaning: String?,
                         defaultTarget: Int?, category: DhikrCategory,
                         completionPolicy: CompletionPolicy, milestoneInterval: Int?,
                         existingCreatedAt: Date?, now: Date) {
        saveCustom(CustomDhikr(id: id, name: name, arabicText: arabicText, meaning: meaning,
                               defaultTarget: defaultTarget, category: category,
                               createdAt: existingCreatedAt ?? now, updatedAt: now))
        var userState = state(for: id) ?? DhikrUserState(dhikrID: id)
        userState.completionPolicy = completionPolicy
        userState.milestoneInterval = milestoneInterval
        saveState(userState)
    }
    func saveState(_ state: DhikrUserState) { upsert(state); persistStates() }
    func remove(id: String) { var value = state(for: id) ?? DhikrUserState(dhikrID: id); value.removedAt = now(); saveState(value); Task { await reminderManager.removeReminders(dhikrID: id) } }
    func restore(id: String) { var value = state(for: id) ?? DhikrUserState(dhikrID: id); value.removedAt = nil; saveState(value) }
    func resetAndRestore(id: String) { var value = state(for: id) ?? DhikrUserState(dhikrID: id); value.resetContentOverrides(); value.removedAt = nil; saveState(value) }
    @discardableResult func permanentlyDelete(id: String) -> Bool {
        guard customDhikrs.contains(where: { $0.id == id }) else { return false }
        customDhikrs.removeAll { $0.id == id }; states.removeAll { $0.dhikrID == id }
        customRepository.save(customDhikrs); persistStates(); Task { await reminderManager.removeReminders(dhikrID: id) }; return true
    }
    /// "Tüm Verilerimi Sil" — bkz. PLAN.md Bölüm 7.3. Özel zikirleri, hazır
    /// zikir override'larını (kaldırma/düzenleme durumu dahil) ve tüm
    /// hatırlatıcıları kalıcı olarak siler. Hazır zikir kütüphanesinin
    /// kaynak tanımına dokunmaz — o zaten değişmez.
    func eraseAllUserData() async {
        customDhikrs = []
        states = []
        customRepository.save(customDhikrs)
        stateRepository.save(states)
        await reminderManager.removeAllReminders()
    }

    func remainingDays(for dhikr: ResolvedDhikr) -> Int? {
        guard dhikr.origin == .custom, let removedAt = dhikr.userState.removedAt else { return nil }
        return max(0, Int(ceil(removedAt.addingTimeInterval(30 * 86_400).timeIntervalSince(now()) / 86_400)))
    }
    private func state(for id: String) -> DhikrUserState? { states.first { $0.dhikrID == id } }
    private func upsert(_ state: DhikrUserState) { if let i = states.firstIndex(where: { $0.dhikrID == state.dhikrID }) { states[i] = state } else { states.append(state) } }
    private func persistStates() { stateRepository.save(states) }
}
