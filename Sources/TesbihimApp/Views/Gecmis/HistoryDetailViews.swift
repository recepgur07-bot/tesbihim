import SwiftUI
import UIKit

struct HistoryDailyDetailView: View {
    let title: String
    let points: [HistoryDailyPoint]
    let calculator: HistoryStatisticsCalculator

    var body: some View {
        List(points.reversed(), id: \.localDayKey) { point in
            VStack(alignment: .leading, spacing: 4) {
                Text(dayTitle(for: point.localDayKey)).font(.headline)
                Text(point.detailText).foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(dayTitle(for: point.localDayKey)): \(point.detailText)")
        }
        .navigationTitle("Gün Gün İncele")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityLabel("\(title) gün gün ayrıntısı")
    }

    private func dayTitle(for key: String) -> String {
        guard let date = calculator.date(forLocalDayKey: key) else { return key }
        return date.formatted(.dateTime.weekday(.wide).day().month(.wide).year())
    }
}

struct HistoryDhikrDetailView: View {
    var counterViewModel: CounterViewModel
    let statistic: HistoryDhikrStatistic
    let allEntries: [HistoryEntry]
    let period: HistoryPeriod
    let referenceDate: Date

    @Environment(\.dismiss) private var dismiss
    @State private var showingClearConfirmation = false

    private var calculator: HistoryStatisticsCalculator { HistoryStatisticsCalculator(referenceDate: referenceDate) }
    private var summary: HistoryPeriodSummary {
        calculator.summary(for: period, entries: allEntries.filter { $0.dhikrID == statistic.dhikrID })
    }

    var body: some View {
        List {
            Section("Özet") {
                Text("\(statistic.addedCount.localizedNumber) tekrar, \(statistic.completedTargetCount.localizedNumber) hedef tamamlandı.")
                Text("\(summary.activeDayCount.localizedNumber) gün zikir yapıldı.")
                    .foregroundStyle(.secondary)
            }
            Section("Günlük dağılım") {
                ForEach(summary.dailyPoints.reversed(), id: \.localDayKey) { point in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dayTitle(for: point.localDayKey)).font(.headline)
                        Text(point.detailText).foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(dayTitle(for: point.localDayKey)): \(point.detailText)")
                }
            }
            Section("Veri yönetimi") {
                Button("Bu Zikrin Geçmişini Sil", role: .destructive) {
                    showingClearConfirmation = true
                }
            }
        }
        .navigationTitle(statistic.name)
        .navigationBarTitleDisplayMode(.inline)
        .alert("\(statistic.name) Geçmişi Silinsin mi?", isPresented: $showingClearConfirmation) {
            Button("İptal", role: .cancel) {}
            Button("Sil", role: .destructive) {
                counterViewModel.clearHistory(forDhikrID: statistic.dhikrID)
                UIAccessibility.post(notification: .screenChanged, argument: nil)
                dismiss()
            }
        } message: {
            Text("Yalnız \(statistic.name) zikrine ait geçmiş kayıtları silinir. Diğer zikirler ve güncel sayacınız etkilenmez. Bu işlem geri alınamaz.")
        }
    }

    private func dayTitle(for key: String) -> String {
        guard let date = calculator.date(forLocalDayKey: key) else { return key }
        return date.formatted(.dateTime.weekday(.wide).day().month(.wide).year())
    }
}

struct HistoryDhikrRow: View {
    let statistic: HistoryDhikrStatistic

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(statistic.name)
            Text("\(statistic.addedCount.localizedNumber) tekrar, \(statistic.completedTargetCount.localizedNumber) hedef tamamlandı")
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(statistic.name): \(statistic.addedCount.localizedNumber) tekrar, \(statistic.completedTargetCount.localizedNumber) hedef tamamlandı")
    }
}

extension HistoryPeriodSummary {
    var rangeTitle: String {
        let calculator = HistoryStatisticsCalculator(referenceDate: .now)
        guard let start = calculator.date(forLocalDayKey: range.startDayKey), let end = calculator.date(forLocalDayKey: range.endDayKey) else { return "Dönem" }
        if range.startDayKey == range.endDayKey { return start.formatted(.dateTime.day().month(.wide).year()) }
        return "\(start.formatted(.dateTime.day().month(.abbreviated))) – \(end.formatted(.dateTime.day().month(.abbreviated).year()))"
    }

    var naturalLanguageSummary: String {
        var parts = ["\(addedCount.localizedNumber) tekrar", "\(completedTargetCount.localizedNumber) hedef tamamlandı", "\(activeDayCount.localizedNumber) gün zikir yapıldı"]
        if let averageAddedCount { parts.append("günlük ortalama \(averageAddedCount.localizedNumber) tekrar") }
        if let mostPerformedDhikr { parts.append("en çok \(mostPerformedDhikr.name) yapıldı") }
        if let busiestDay { parts.append("en yoğun gün \(busiestDay.localDayKey), \(busiestDay.addedCount.localizedNumber) tekrar") }
        return parts.joined(separator: ". ") + "."
    }

    var comparisonText: String? {
        guard let comparison else { return nil }
        guard comparison.previousPeriodHadRecords else { return "Önceki eşdeğer dönemde kayıt yoktu." }
        if comparison.difference == 0 { return "Önceki eşdeğer dönemle aynı." }
        return "Önceki eşdeğer dönemden \(abs(comparison.difference).localizedNumber) tekrar \(comparison.difference > 0 ? "fazla" : "az")."
    }
}

private extension HistoryDailyPoint {
    var detailText: String { "\(addedCount.localizedNumber) tekrar, \(completedTargetCount.localizedNumber) hedef tamamlandı" }
}

private extension BinaryInteger {
    var localizedNumber: String { Int(self).formatted(.number.grouping(.automatic)) }
}

private extension BinaryFloatingPoint {
    var localizedNumber: String { Double(self).formatted(.number.precision(.fractionLength(0...1)).grouping(.automatic)) }
}
