import Foundation

/// Sayaç ekranının kalıcı durumu — bkz. PLAN.md Bölüm 3, 7.1.
///
/// `lastDelta`, uygulama arka planda sonlandırılsa bile Geri Al'ın
/// çalışmaya devam etmesi için kalıcı tutulan son artış kaydıdır.
struct CounterState: Codable, Equatable {
    var selectedDhikrID: String
    var target: Int?
    var currentCount: Int
    var completedTargetCount: Int
    var updatedAt: Date
    var lastDelta: Int?

    static let initial = CounterState(
        selectedDhikrID: "serbest",
        target: nil,
        currentCount: 0,
        completedTargetCount: 0,
        updatedAt: Date(),
        lastDelta: nil
    )
}
