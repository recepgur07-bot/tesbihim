import UIKit

/// VoiceOver anonslarını soyutlar — bkz. PLAN.md Bölüm 7.1 "Anons
/// güvenilirliği": hedef tamamlama anonsu düz `String` yerine
/// `NSAttributedString` + `UIAccessibilitySpeechAttributeQueueAnnouncement`
/// özniteliğiyle gönderilir, böylece mevcut konuşmayı kesmeden kuyruğa girer.
protocol AccessibilityAnnouncing {
    func announceQueued(_ message: String)
    /// Kuyruklamaz — mevcut konuşmayı keser, hemen okur. Hızlı Sayım'ın
    /// debounce'lı sayı duyurusu gibi "sadece en güncel değer önemli"
    /// durumlar için (bkz. CounterViewModel.incrementFast).
    func announceInterrupting(_ message: String)
}

struct SystemAccessibilityAnnouncer: AccessibilityAnnouncing {
    func announceQueued(_ message: String) {
        let attributed = NSMutableAttributedString(string: message)
        attributed.addAttribute(
            .accessibilitySpeechQueueAnnouncement,
            value: true,
            range: NSRange(location: 0, length: attributed.length)
        )
        UIAccessibility.post(notification: .announcement, argument: attributed)
    }

    func announceInterrupting(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}
