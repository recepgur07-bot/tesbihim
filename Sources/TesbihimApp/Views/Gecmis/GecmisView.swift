import SwiftUI
import UIKit

/// Geçmiş ekranı — dönemsel özetler ve ayrıntı yolları.
struct GecmisView: View {
    var counterViewModel: CounterViewModel
    var libraryViewModel: DhikrLibraryViewModel
    @State private var selectedPeriod: DisplayPeriod = .today
    @State private var referenceDate = Date()
    @State private var showingClearHistoryConfirmation = false
    @State private var showingClearAllConfirmation = false

    private var historyViewModel: HistoryViewModel { counterViewModel.historyViewModel }
    private var calculator: HistoryStatisticsCalculator { HistoryStatisticsCalculator(referenceDate: referenceDate) }
    private var summary: HistoryPeriodSummary { calculator.summary(for: selectedPeriod.period, entries: historyViewModel.entries) }

    var body: some View {
        NavigationStack {
            List {
                if let warning = counterViewModel.dataRecoveryWarning {
                    Section {
                        Text(warning)
                            .accessibilityLabel(warning)
                    }
                }

                Section("Dönem") {
                    Picker("Gösterilen dönem", selection: $selectedPeriod) {
                        ForEach(DisplayPeriod.allCases) { period in
                            Text(period.title).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Gösterilen dönem")
                    .accessibilityValue(selectedPeriod.title)
                    .onChange(of: selectedPeriod) { _, _ in referenceDate = Date() }

                    if selectedPeriod.supportsNavigation {
                        periodNavigation
                    }
                }

                Section(summary.rangeTitle) {
                    if summary.addedCount == 0 {
                        ContentUnavailableView(
                            "Bu dönemde henüz zikir kaydı yok.",
                            systemImage: "clock",
                            description: Text("Sayım yaptıkça buradaki özet güncellenecek.")
                        )
                    } else {
                        Text(summary.naturalLanguageSummary)
                            .accessibilityLabel(summary.naturalLanguageSummary)

                        if let comparisonText = summary.comparisonText {
                            Text(comparisonText)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Günlük dağılım") {
                    if selectedPeriod == .week || selectedPeriod == .month {
                        HistoryDailyBarChart(points: summary.dailyPoints, calculator: calculator)
                            .listRowInsets(EdgeInsets())
                            .padding()
                    }
                    NavigationLink("Gün gün incele") {
                        HistoryDailyDetailView(
                            title: summary.rangeTitle,
                            points: summary.dailyPoints,
                            calculator: calculator
                        )
                    }
                    .accessibilityHint("Seçili dönemin her günündeki tekrar ve hedef sayısını açar.")
                }

                Section("Zikirler") {
                    if summary.dhikrBreakdown.isEmpty {
                        Text("Bu dönemde zikir dökümü yok.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(summary.dhikrBreakdown, id: \.dhikrID) { item in
                            NavigationLink {
                                HistoryDhikrDetailView(
                                    counterViewModel: counterViewModel,
                                    statistic: item,
                                    allEntries: historyViewModel.entries,
                                    period: selectedPeriod.period,
                                    referenceDate: referenceDate
                                )
                            } label: {
                                HistoryDhikrRow(statistic: item)
                            }
                            .accessibilityHint("Bu zikrin seçili dönemdeki gün gün geçmişini açar.")
                        }
                    }
                }

                Section("Veri yönetimi") {
                    Button("Geçmişi Sil", role: .destructive) {
                        showingClearHistoryConfirmation = true
                    }
                    Button("Tüm Verilerimi Sil", role: .destructive) {
                        showingClearAllConfirmation = true
                    }
                }
            }
            .navigationTitle("Geçmiş")
            .alert("Geçmiş Silinsin mi?", isPresented: $showingClearHistoryConfirmation) {
                Button("İptal", role: .cancel) {}
                Button("Sil", role: .destructive) { counterViewModel.clearHistory() }
            } message: {
                Text("Geçmiş kayıtları silinir. Güncel zikir sayacınız etkilenmez. Bu işlem geri alınamaz.")
            }
            .alert("Tüm Veriler Silinsin mi?", isPresented: $showingClearAllConfirmation) {
                Button("İptal", role: .cancel) {}
                Button("Sil", role: .destructive) {
                    Task {
                        counterViewModel.clearHistory()
                        counterViewModel.resetAllData()
                        counterViewModel.resetSettingsToDefault()
                        await libraryViewModel.eraseAllUserData()
                        UIAccessibility.post(notification: .screenChanged, argument: nil)
                    }
                }
            } message: {
                Text("Geçmiş kayıtları, güncel zikir sayaç durumu, özel zikirleriniz, zikir ayarlarınız, hatırlatıcılarınız ve tercihleriniz tamamen silinir. Bu işlem geri alınamaz.")
            }
        }
    }

    private var periodNavigation: some View {
        HStack {
            Button {
                referenceDate = selectedPeriod.moving(referenceDate, by: -1)
            } label: {
                Label(selectedPeriod.previousTitle(from: referenceDate), systemImage: "chevron.left")
                    .labelStyle(.iconOnly)
            }
            .accessibilityLabel(selectedPeriod.previousTitle(from: referenceDate))

            Spacer()
            Text(summary.rangeTitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            Spacer()

            Button {
                referenceDate = selectedPeriod.moving(referenceDate, by: 1)
            } label: {
                Label(selectedPeriod.nextTitle(from: referenceDate), systemImage: "chevron.right")
                    .labelStyle(.iconOnly)
            }
            .accessibilityLabel(selectedPeriod.nextTitle(from: referenceDate))
            .disabled(!selectedPeriod.canMoveForward(from: referenceDate))
        }
    }
}

private enum DisplayPeriod: CaseIterable, Identifiable {
    case today, week, month, all

    var id: Self { self }
    var period: HistoryPeriod {
        switch self { case .today: .today; case .week: .week; case .month: .month; case .all: .all }
    }
    var title: String {
        switch self { case .today: "Bugün"; case .week: "Hafta"; case .month: "Ay"; case .all: "Tümü" }
    }
    var supportsNavigation: Bool { self == .week || self == .month }

    func moving(_ date: Date, by amount: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar.date(byAdding: self == .week ? .weekOfYear : .month, value: amount, to: date) ?? date
    }

    func canMoveForward(from date: Date) -> Bool {
        moving(date, by: 1) <= Date()
    }

    func previousTitle(from date: Date) -> String { "Önceki \(title.lowercased()): \(shortTitle(for: moving(date, by: -1)))" }
    func nextTitle(from date: Date) -> String { "Sonraki \(title.lowercased()): \(shortTitle(for: moving(date, by: 1)))" }

    private func shortTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

#Preview {
    GecmisView(counterViewModel: CounterViewModel(), libraryViewModel: DhikrLibraryViewModel())
}
