import Foundation

/// Sayaç ekranının kalıcı durumu — bkz. PLAN.md Bölüm 3, 7.1.
///
/// `lastIncrement`, uygulama arka planda sonlandırılsa bile Geri Al'ın
/// çalışmaya devam etmesi için kalıcı tutulan son artış kaydıdır. Faz 1'de
/// her artış tek adım olduğundan delta değeri her zaman 1'dir; geri almak
/// için tek bilinmesi gereken şey o artışın bir hedefi tamamlatıp
/// tamamlatmadığıdır (bkz. Bölüm 7.1 "Hedef tamamlama davranışı").
struct CounterState: Codable, Equatable {
    var selectedDhikrID: String
    var target: Int?
    var currentCount: Int
    var completedTargetCount: Int
    var updatedAt: Date
    var lastIncrement: LastIncrement?

    struct LastIncrement: Codable, Equatable {
        var completedTarget: Bool
    }

    static let initial = CounterState(
        selectedDhikrID: "serbest",
        target: nil,
        currentCount: 0,
        completedTargetCount: 0,
        updatedAt: Date(),
        lastIncrement: nil
    )

    var canUndo: Bool { lastIncrement != nil }
    var canReset: Bool { currentCount != 0 }

    /// Sayacı bir adım artırır. Hedef doluysa yeni tur 0'dan başlar ve
    /// tamamlanan hedef sayısı bir artar. Dönüş değeri: bu artış bir hedefi
    /// tamamlattı mı (View katmanının anons metni üretmesi için).
    @discardableResult
    mutating func increment() -> Bool {
        currentCount += 1
        var didCompleteTarget = false
        if let target, currentCount == target {
            completedTargetCount += 1
            currentCount = 0
            didCompleteTarget = true
        }
        lastIncrement = LastIncrement(completedTarget: didCompleteTarget)
        updatedAt = Date()
        return didCompleteTarget
    }

    /// Son artışı geri alır. Artış bir hedefi tamamlatmışsa sayaç hedefin
    /// bir eksiğine döner ve tamamlanan hedef sayısı bir azalır.
    mutating func undoLastIncrement() {
        guard let lastIncrement else { return }
        if lastIncrement.completedTarget, let target {
            completedTargetCount = max(0, completedTargetCount - 1)
            currentCount = max(0, target - 1)
        } else {
            currentCount = max(0, currentCount - 1)
        }
        self.lastIncrement = nil
        updatedAt = Date()
    }

    /// Geçerli turu sıfırlar. Tamamlanan hedef sayısı (Geçmiş'in de
    /// kullanacağı ayrı bir kayıt) burada etkilenmez — Sıfırla yalnızca
    /// güncel sayımı temizler, geçmişi silmez (bkz. Bölüm 7.3 "Tüm
    /// Verilerimi Sil" ile karıştırılmamalı).
    mutating func reset() {
        currentCount = 0
        lastIncrement = nil
        updatedAt = Date()
    }
}
