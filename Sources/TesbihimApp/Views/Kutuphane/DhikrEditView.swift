import SwiftUI
import UIKit

struct DhikrEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    var viewModel: DhikrLibraryViewModel
    let dhikr: ResolvedDhikr?
    private let entitlement: any EntitlementProviding
    @State private var name: String
    @State private var arabic: String
    @State private var meaning: String
    @State private var target: String
    @State private var category: DhikrCategory
    @State private var policy: CompletionPolicy
    @State private var milestone: String
    @State private var more = false
    @State private var reminderManager = ReminderManager()
    @State private var reminderEnabled: Bool
    @State private var weekdays: Set<Int>
    @State private var reminderTime: Date
    @State private var showingPermissionExplanation = false
    @State private var soundOverride: SettingOverride
    @State private var hapticOverride: SettingOverride
    @State private var feedbackCharacter: FeedbackCharacter
    @State private var showingSupporterRequirement = false

    init(viewModel: DhikrLibraryViewModel, dhikr: ResolvedDhikr?, entitlement: any EntitlementProviding = PlaceholderEntitlementProvider()) {
        self.viewModel = viewModel; self.dhikr = dhikr; self.entitlement = entitlement
        _name = State(initialValue: dhikr?.name ?? ""); _arabic = State(initialValue: dhikr?.arabicText ?? "")
        _meaning = State(initialValue: dhikr?.meaning ?? ""); _target = State(initialValue: dhikr?.defaultTarget.map(String.init) ?? "")
        _category = State(initialValue: dhikr?.category ?? .diger); _policy = State(initialValue: dhikr?.userState.completionPolicy ?? .stop)
        _milestone = State(initialValue: dhikr?.userState.milestoneInterval.map(String.init) ?? "")
        let schedules = dhikr?.userState.reminders ?? []
        _reminderEnabled = State(initialValue: !schedules.isEmpty); _weekdays = State(initialValue: Set(schedules.map(\.weekday)))
        var components = DateComponents(); components.hour = schedules.first?.hour ?? 9; components.minute = schedules.first?.minute ?? 0
        _reminderTime = State(initialValue: Calendar.current.date(from: components) ?? Date())
        _soundOverride = State(initialValue: dhikr?.userState.soundOverride ?? .inherit)
        _hapticOverride = State(initialValue: dhikr?.userState.hapticOverride ?? .inherit)
        _feedbackCharacter = State(initialValue: dhikr?.userState.feedbackCharacter ?? .system)
    }
    var body: some View {
        NavigationStack { Form {
            Section { TextField("Ad", text: $name); TextField("Hedef sayı (opsiyonel)", text: $target).keyboardType(.numberPad) }
            Section { TextField("Arapça metin (opsiyonel)", text: $arabic); TextField("Anlam (opsiyonel)", text: $meaning, axis: .vertical) }
            DisclosureGroup("Daha Fazla Seçenek", isExpanded: $more) {
                Picker("Tamamlanma davranışı", selection: $policy) { Text("Dur").tag(CompletionPolicy.stop); Text("Döngüsel devam et").tag(CompletionPolicy.cycle) }
                Picker("Kategori", selection: $category) { ForEach(DhikrCategory.allCases.filter { $0 != .serbest }) { Text($0.title).tag($0) } }
                TextField("Aşama İşareti", text: $milestone).keyboardType(.numberPad)
                Toggle("Hatırlatıcı", isOn: $reminderEnabled)
                if reminderEnabled {
                    Button("Her Gün") { weekdays = Set(1...7) }.accessibilityHint("Haftanın yedi gününü seçer.")
                    ForEach(1...7, id: \.self) { day in Button { toggle(day) } label: { HStack { Text(dayName(day)); Spacer(); if weekdays.contains(day) { Image(systemName: "checkmark") } } }.accessibilityValue(weekdays.contains(day) ? "Seçili" : "Seçili değil") }
                    DatePicker("Saat", selection: $reminderTime, displayedComponents: .hourAndMinute)
                }
                Picker("Ses", selection: $soundOverride) { Text("Global ayarı kullan").tag(SettingOverride.inherit); Text("Açık").tag(SettingOverride.on); Text("Kapalı").tag(SettingOverride.off) }
                Picker("Titreşim", selection: $hapticOverride) { Text("Global ayarı kullan").tag(SettingOverride.inherit); Text("Açık").tag(SettingOverride.on); Text("Kapalı").tag(SettingOverride.off) }
                Menu("Geri bildirim karakteri: \(feedbackCharacterTitle(feedbackCharacter))") {
                    ForEach(FeedbackCharacter.allCases, id: \.self) { character in
                        Button(characterOptionTitle(character)) { selectFeedbackCharacter(character) }
                    }
                }
                if reminderManager.settings.authorization == .denied {
                    Text("Bildirimler kapalı. Bu hatırlatıcı gönderilemez. iPhone Ayarları'nda Tesbihim bildirimlerini açabilirsiniz.").accessibilityAddTraits(.isHeader)
                    Button("Bildirim Ayarlarını Aç") { UIApplication.shared.open(URL(string: UIApplication.openNotificationSettingsURLString)!) }
                } else if reminderManager.settings.authorization == .authorized && !reminderManager.settings.soundsEnabled {
                    Text("Bildirimlere izin verildi; bildirim sesi iPhone Ayarları'nda kapalı.").foregroundStyle(.secondary)
                }
            }
            if dhikr?.origin == .bundled, dhikr?.userState.hasContentOverrides == true {
                Button("Varsayılana Sıfırla") { if var state = dhikr?.userState { state.resetContentOverrides(); viewModel.saveState(state); dismiss() } }
                    .accessibilityHint("Varsayılana Sıfırla, \(dhikr?.name ?? "zikir") orijinal metnine dönecektir.")
            }
        }.navigationTitle(dhikr == nil ? "Zikir Ekle" : "Zikri Düzenle").toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Kaydet") { if reminderEnabled && reminderManager.settings.authorization == .notDetermined { showingPermissionExplanation = true } else { save() } }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (reminderEnabled && weekdays.isEmpty)) }
        }.task { await reminderManager.refreshSettings() }
          .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await reminderManager.refreshSettings() } } }
          .alert("Bildirim İzni", isPresented: $showingPermissionExplanation) { Button("İptal", role: .cancel) {}; Button("Devam") { save() } } message: { Text("Seçtiğiniz gün ve saatte bu zikir için sakin bir hatırlatıcı gönderebilmek amacıyla bildirim izni istenecek.") }
          .alert("Destekçi Paketi Gerekli", isPresented: $showingSupporterRequirement) { Button("Tamam") {} } message: { Text("Bu ses/haptic karakteri Destekçi Paketi gerektirir.") }
        }
    }
    private func save() {
        guard FeedbackCharacterAccess.canSelect(feedbackCharacter, entitlement: entitlement) else { showingSupporterRequirement = true; return }
        let cleanTarget = Int(target).flatMap { $0 > 0 ? $0 : nil }; let cleanMilestone = Int(milestone).flatMap { $0 > 0 ? $0 : nil }
        let resolvedID = dhikr?.id ?? UUID().uuidString
        if let dhikr, dhikr.origin == .bundled {
            var state = dhikr.userState; state.name = .set(name); state.arabicText = arabic.isEmpty ? .clear : .set(arabic); state.meaning = meaning.isEmpty ? .clear : .set(meaning); state.defaultTarget = cleanTarget.map(FieldOverride.set) ?? .clear; state.category = .set(category); state.completionPolicy = policy; state.milestoneInterval = cleanMilestone; viewModel.saveState(state)
        } else {
            let date = Date()
            viewModel.saveCustomDraft(id: resolvedID, name: name, arabicText: arabic.isEmpty ? nil : arabic,
                meaning: meaning.isEmpty ? nil : meaning, defaultTarget: cleanTarget, category: category,
                completionPolicy: policy, milestoneInterval: cleanMilestone,
                existingCreatedAt: dhikr.flatMap { item in viewModel.customDhikrs.first { $0.id == item.id }?.createdAt }, now: date)
        }
        let id = resolvedID
        do {
            var state = viewModel.resolved(id: id)?.userState ?? DhikrUserState(dhikrID: id)
            state.completionPolicy = policy; state.milestoneInterval = cleanMilestone
            let hm = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
            let requested = reminderEnabled ? weekdays.sorted().map { ReminderSchedule(weekday: $0, hour: hm.hour ?? 9, minute: hm.minute ?? 0) } : []
            state.reminders = reminderEnabled && reminderManager.settings.authorization == .denied ? [] : requested
            state.soundOverride = soundOverride; state.hapticOverride = hapticOverride
            state.feedbackCharacter = feedbackCharacter
            viewModel.saveState(state)
            Task {
                let scheduled = await reminderManager.replaceReminders(dhikrID: id, name: name, schedules: state.reminders)
                if !scheduled, !state.reminders.isEmpty { var rollback = state; rollback.reminders = []; viewModel.saveState(rollback) }
            }
        }
        dismiss()
    }
    private func toggle(_ day: Int) { if weekdays.contains(day) { weekdays.remove(day) } else { weekdays.insert(day) } }
    private func dayName(_ day: Int) -> String { Calendar.current.weekdaySymbols[(day - 1) % 7] }
    private func selectFeedbackCharacter(_ character: FeedbackCharacter) {
        guard FeedbackCharacterAccess.canSelect(character, entitlement: entitlement) else { showingSupporterRequirement = true; return }
        feedbackCharacter = character
    }
    private func feedbackCharacterTitle(_ character: FeedbackCharacter) -> String {
        switch character { case .system: "Sistem"; case .wood: "Ahşap"; case .glass: "Cam"; case .soft: "Yumuşak"; case .doubleTap: "Çift vuruş" }
    }
    private func characterOptionTitle(_ character: FeedbackCharacter) -> String {
        FeedbackCharacterAccess.canSelect(character, entitlement: entitlement) ? feedbackCharacterTitle(character) : "\(feedbackCharacterTitle(character)) — Destekçi Paketi gerekli"
    }
}
