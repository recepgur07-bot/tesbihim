import Foundation

/// Geçmiş ekranının günlük agregasyon kaydı — bkz. PLAN.md Bölüm 7.3.
/// Tam bir olay/oturum log'u değil; her (gün, zikir) çifti için tek bir
/// toplama satırı tutulur (Bölüm 3'teki "aşırı mühendislik olmasın" ilkesi).
struct HistoryEntry: Codable, Equatable {
    /// Günün başlangıcı, cihazın yerel saat dilimine göre (gece yarısı
    /// sınırı) — bkz. Bölüm 7.3 "basit kural, DST karmaşasına girilmez".
    var date: Date
    var dhikrID: String
    var dhikrNameSnapshot: String
    var addedCount: Int
    var completedTargetCount: Int

    /// Eski `date` tabanlı kayıtların migrasyon öncesi kanonik gün görünümü.
    /// Kalıcı model geçişinde bu değer snapshot içine yazılır; bu köprü eski
    /// UserDefaults verisini kayıpsız okuyabilmeyi sağlar.
    var localDayKey: String { LocalDayKey.make(for: date) }

    init(date: Date, dhikrID: String, dhikrNameSnapshot: String? = nil, addedCount: Int, completedTargetCount: Int) {
        self.date = date
        self.dhikrID = dhikrID
        self.dhikrNameSnapshot = dhikrNameSnapshot ?? DhikrLibrary.definition(for: dhikrID)?.transliteration ?? dhikrID
        self.addedCount = addedCount
        self.completedTargetCount = completedTargetCount
    }
}
