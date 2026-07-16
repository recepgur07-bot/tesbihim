import Accessibility
import Charts
import SwiftUI

/// Bölüm 7.3 "Bu Haftanın Seyri" çubuk grafiği. Aynı veri hem görsel çubuk
/// hem `accessibilityChartDescriptor` ile VoiceOver'ın gezebileceği bir
/// veri serisi olarak sunulur — grafik tek bilgi kaynağı değildir, aynı
/// sayılar "Gün gün incele" alt ekranında tam metin olarak da bulunur.
struct HistoryDailyBarChart: View {
    let points: [HistoryDailyPoint]
    let calculator: HistoryStatisticsCalculator

    var body: some View {
        Chart(points, id: \.localDayKey) { point in
            BarMark(
                x: .value("Gün", shortDayTitle(for: point.localDayKey)),
                y: .value("Tekrar", point.addedCount)
            )
        }
        .frame(height: 160)
        .accessibilityChartDescriptor(
            HistoryChartDescriptorBuilder(points: points, calculator: calculator)
        )
    }

    private func shortDayTitle(for key: String) -> String {
        guard let date = calculator.date(forLocalDayKey: key) else { return key }
        return date.formatted(.dateTime.weekday(.abbreviated))
    }
}

private struct HistoryChartDescriptorBuilder: AXChartDescriptorRepresentable {
    let points: [HistoryDailyPoint]
    let calculator: HistoryStatisticsCalculator

    func makeChartDescriptor() -> AXChartDescriptor {
        let categories = points.map(fullDayTitle)
        let maxCount = points.map(\.addedCount).max() ?? 0

        let xAxis = AXCategoricalDataAxisDescriptor(title: "Gün", categoryOrder: categories)
        let yAxis = AXNumericDataAxisDescriptor(
            title: "Tekrar",
            range: 0...Double(max(maxCount, 1)),
            gridlinePositions: []
        ) { value in "\(Int(value.rounded())) tekrar" }

        let series = AXDataSeriesDescriptor(
            name: "Günlük tekrar",
            isContinuous: false,
            dataPoints: points.map { point in
                AXDataPoint(x: fullDayTitle(for: point), y: Double(point.addedCount))
            }
        )

        return AXChartDescriptor(
            title: "Günlük tekrar dağılımı",
            summary: nil,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }

    private func fullDayTitle(for point: HistoryDailyPoint) -> String { fullDayTitle(for: point.localDayKey) }

    private func fullDayTitle(for key: String) -> String {
        guard let date = calculator.date(forLocalDayKey: key) else { return key }
        return date.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }
}
