import AudioToolbox
import CoreHaptics
import UIKit

/// Sayma sırasındaki ses/titreşim geri bildirimini soyutlar — bkz. PLAN.md
/// Bölüm 3, 5. ViewModel bu arayüz arkasında çalıştığı için birim
/// testlerinde gerçek haptic/ses motoru tetiklenmeden davranış doğrulanabilir.
@MainActor
protocol FeedbackProviding {
    func countIncremented()
    func targetCompleted()
    /// `soundEffectEnabled` açıkken çalınan, konuşma içermeyen isteğe bağlı
    /// kısa ses efekti.
    func countTick()
    func countFeedback(playsSound: Bool)
    /// Hızlı Sayım için: titreşim ve ses birbirinden bağımsız açılıp
    /// kapatılabilir (bkz. `CounterViewModel.incrementFast`) — normal
    /// `countFeedback(playsSound:)` her zaman titreşim verir, bu yeterli
    /// değil.
    func countFeedback(hapticEnabled: Bool, soundEnabled: Bool)
    func milestoneReached()
}

extension FeedbackProviding {
    func milestoneReached() {}
    func countFeedback(playsSound: Bool) { countFeedback(hapticEnabled: true, soundEnabled: playsSound) }
    func countFeedback(hapticEnabled: Bool, soundEnabled: Bool) {
        if hapticEnabled { countIncremented() }
        if soundEnabled { countTick() }
    }
}

/// Faz 1 varsayılanı: sakin/hafif haptic (bkz. Bölüm 6 "varsayılan
/// sakin/hafif" kuralı). Haptic yoğunluğu ve ses profili ayarları
/// (Bölüm 7.4) Ayarlar ekranı kurulduğunda buraya bağlanacak.
///
/// Üreteçler her çağrıda yeniden oluşturulmuyor: Taptic Engine her yeni
/// `UIImpactFeedbackGenerator` örneğinde ısınma gecikmesi yaşar, bu da
/// hızlı art arda sayımda titreşim/sesin geriden gelmesine yol açar.
/// Tek örnek tutup her ateşlemeden sonra yeniden `prepare()` çağırmak
/// bu gecikmeyi ortadan kaldırır (bkz. Apple `UIFeedbackGenerator.prepare()`).
@MainActor
final class SystemFeedbackProvider: FeedbackProviding {
    private let impactGenerator = UIImpactFeedbackGenerator(style: .light)
    private let notificationGenerator = UINotificationFeedbackGenerator()

    private var lastFeedbackTime: CFAbsoluteTime = 0
    private let minimumFeedbackInterval: CFAbsoluteTime = 0.10
    private var hapticEngine: CHHapticEngine?

    init() {
        impactGenerator.prepare()
        notificationGenerator.prepare()
        if CHHapticEngine.capabilitiesForHardware().supportsHaptics {
            hapticEngine = try? CHHapticEngine()
            hapticEngine?.stoppedHandler = { [weak self] _ in self?.hapticEngine = nil }
            hapticEngine?.resetHandler = { [weak self] in
                do { try self?.hapticEngine?.start() }
                catch { DispatchQueue.main.async { UIImpactFeedbackGenerator(style: .medium).impactOccurred() } }
            }
        }
    }

    func countIncremented() {
        impactGenerator.impactOccurred()
        impactGenerator.prepare()
    }

    func targetCompleted() {
        notificationGenerator.notificationOccurred(.success)
        notificationGenerator.prepare()
    }

    func countTick() {
        AudioServicesPlaySystemSound(1104)
    }
    func milestoneReached() {
        guard let engine = hapticEngine else { UIImpactFeedbackGenerator(style: .medium).impactOccurred(); return }
        do {
            try engine.start()
            let events = [CHHapticEvent(eventType: .hapticTransient, parameters: [.init(parameterID: .hapticIntensity, value: 0.8)], relativeTime: 0), CHHapticEvent(eventType: .hapticTransient, parameters: [], relativeTime: 0.12)]
            try engine.makePlayer(with: CHHapticPattern(events: events, parameters: [])).start(atTime: 0)
            AudioServicesPlaySystemSound(1105)
        } catch { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    }
    func countFeedback(playsSound: Bool) { countFeedback(hapticEnabled: true, soundEnabled: playsSound) }
    func countFeedback(hapticEnabled: Bool, soundEnabled: Bool) {
        guard hapticEnabled || soundEnabled else { return }
        guard acceptsFeedback() else { return }
        if hapticEnabled {
            impactGenerator.impactOccurred()
            impactGenerator.prepare()
        }
        if soundEnabled {
            AudioServicesPlaySystemSound(1104)
        }
    }

    private func acceptsFeedback() -> Bool {
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastFeedbackTime >= minimumFeedbackInterval else { return false }
        lastFeedbackTime = now
        return true
    }
}
