import SwiftUI
import UIKit

/// VoiceOver'ın doğrudan etkileşim alanı. Yalnızca tamamlanan tek parmak
/// dokunuşlarını sayar; çoklu parmak, hareket ve iptal dizileri sayım üretmez.
struct HizliSayimYuzeyi: UIViewRepresentable {
    let onCount: () -> Void
    let onExit: () -> Void
    let onStatus: () -> Void

    func makeUIView(context: Context) -> FastCountDirectTouchView {
        FastCountDirectTouchView(onCount: onCount, onExit: onExit, onStatus: onStatus)
    }

    func updateUIView(_ uiView: FastCountDirectTouchView, context: Context) {}

    static func dismantleUIView(_ uiView: FastCountDirectTouchView, coordinator: ()) {
        uiView.disableAndReset()
    }
}

@MainActor
final class FastCountDirectTouchView: UIView {
    enum TestEvent {
        case began(Set<FastCountTouchGate.TouchID>)
        case ended(FastCountTouchGate.TouchID)
        case moved
        case cancelled
    }

    private var gate = FastCountTouchGate()
    private var touchIDs: [ObjectIdentifier: FastCountTouchGate.TouchID] = [:]
    private let onCount: () -> Void
    private let onExit: () -> Void
    private let onStatus: () -> Void
    private var hasExited = false

    init(onCount: @escaping () -> Void, onExit: @escaping () -> Void = {}, onStatus: @escaping () -> Void = {}) {
        self.onCount = onCount
        self.onExit = onExit
        self.onStatus = onStatus
        super.init(frame: .zero)
        isAccessibilityElement = true
        accessibilityTraits.insert(.allowsDirectInteraction)
        backgroundColor = .clear
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.8
        longPress.cancelsTouchesInView = true
        addGestureRecognizer(longPress)
        let upwardSwipe = UISwipeGestureRecognizer(target: self, action: #selector(handleUpwardSwipe(_:)))
        upwardSwipe.direction = .up
        addGestureRecognizer(upwardSwipe)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            touchIDs[ObjectIdentifier(touch)] = touchIDs[ObjectIdentifier(touch)] ?? UUID()
        }
        if touchIDs.count > 1 {
            exitWithoutCounting()
            return
        }
        process(.began(Set(touchIDs.values)))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        process(.moved)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let key = ObjectIdentifier(touch)
            if let touchID = touchIDs[key] {
                process(.ended(touchID))
            }
            touchIDs.removeValue(forKey: key)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchIDs.removeAll()
        process(.cancelled)
    }

    func processForTesting(_ event: TestEvent) {
        process(event)
    }

    func triggerLongPressForTesting() {
        exitWithoutCounting()
    }

    func disableAndReset() {
        touchIDs.removeAll()
        hasExited = false
        gate.reset()
    }

    private func process(_ event: TestEvent) {
        switch event {
        case let .began(touches):
            if touches.count > 1 {
                exitWithoutCounting()
                return
            }
            gate.begin(activeTouches: touches)
        case let .ended(touch):
            if gate.end(touch: touch) {
                onCount()
            }
        case .moved:
            gate.moved()
        case .cancelled:
            gate.cancel()
        }
    }

    private func exitWithoutCounting() {
        guard !hasExited else { return }
        hasExited = true
        touchIDs.removeAll()
        gate.reset()
        onExit()
    }

    @objc private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else { return }
        exitWithoutCounting()
    }

    @objc private func handleUpwardSwipe(_ recognizer: UISwipeGestureRecognizer) {
        guard recognizer.state == .ended, !hasExited else { return }
        gate.cancel()
        touchIDs.removeAll()
        onStatus()
    }
}
