import Foundation

struct FastCountTouchGate {
    typealias TouchID = UUID

    private var candidate: TouchID?
    private var invalid = false
    private var invalidTouches: Set<TouchID> = []

    mutating func begin(activeTouches: Set<TouchID>) {
        guard candidate == nil else {
            if activeTouches.count > 1 {
                invalid = true
            }
            return
        }

        guard activeTouches.count == 1, let touch = activeTouches.first else {
            invalid = true
            invalidTouches = activeTouches
            return
        }

        candidate = touch
    }

    mutating func end(touch: TouchID) -> Bool {
        guard candidate == touch else {
            recoverFromInitialMultiTouchIfNeeded(ending: touch)
            return false
        }
        defer { reset() }
        return !invalid
    }

    mutating func moved() {
        invalid = true
    }

    mutating func cancel() {
        reset()
    }

    mutating func reset() {
        candidate = nil
        invalid = false
        invalidTouches = []
    }

    private mutating func recoverFromInitialMultiTouchIfNeeded(ending touch: TouchID) {
        guard candidate == nil, invalid else { return }

        invalidTouches.remove(touch)
        if invalidTouches.isEmpty {
            reset()
        }
    }
}
