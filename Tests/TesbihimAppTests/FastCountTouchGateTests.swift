import Foundation
import Testing
import UIKit
@testable import TesbihimApp

struct FastCountTouchGateTests {
    @Test func completedSingleFingerTouchProducesOneCount() {
        var gate = FastCountTouchGate()
        let touch = UUID()

        gate.begin(activeTouches: [touch])

        let didCount = gate.end(touch: touch)
        #expect(didCount)
    }

    @Test func initialMultiTouchNeverProducesCount() {
        var gate = FastCountTouchGate()
        let first = UUID()
        let second = UUID()

        gate.begin(activeTouches: [first, second])

        let didCount = gate.end(touch: first)
        #expect(didCount == false)
    }

    @Test func singleTouchCountsAfterInitialMultiTouchSequenceEnds() {
        var gate = FastCountTouchGate()
        let first = UUID()
        let second = UUID()
        let freshTouch = UUID()

        gate.begin(activeTouches: [first, second])
        #expect(gate.end(touch: first) == false)
        #expect(gate.end(touch: second) == false)

        gate.begin(activeTouches: [freshTouch])
        let didCount = gate.end(touch: freshTouch)
        #expect(didCount)
    }

    @Test func addedSecondTouchInvalidatesCandidate() {
        var gate = FastCountTouchGate()
        let first = UUID()
        let second = UUID()

        gate.begin(activeTouches: [first])
        gate.begin(activeTouches: [first, second])

        let didCount = gate.end(touch: first)
        #expect(didCount == false)
    }

    @Test func movedTouchNeverProducesCount() {
        var gate = FastCountTouchGate()
        let touch = UUID()

        gate.begin(activeTouches: [touch])
        gate.moved()

        let didCount = gate.end(touch: touch)
        #expect(didCount == false)
    }

    @Test func cancelledTouchNeverProducesCount() {
        var gate = FastCountTouchGate()
        let touch = UUID()

        gate.begin(activeTouches: [touch])
        gate.cancel()

        let didCount = gate.end(touch: touch)
        #expect(didCount == false)
    }

    @Test func unrelatedTouchEndingBeforeCandidateNeverProducesCount() {
        var gate = FastCountTouchGate()
        let candidate = UUID()
        let unrelated = UUID()

        gate.begin(activeTouches: [candidate])

        let didCountUnrelatedTouch = gate.end(touch: unrelated)
        let didCountCandidate = gate.end(touch: candidate)

        #expect(didCountUnrelatedTouch == false)
        #expect(didCountCandidate)
    }

    @Test @MainActor func surfaceAllowsDirectInteractionAndCanBeDisabled() {
        var counts = 0
        let candidateTouch = UUID()
        let surface = FastCountDirectTouchView(onCount: { counts += 1 })

        #expect(surface.accessibilityTraits.contains(.allowsDirectInteraction))
        surface.processForTesting(.began([candidateTouch]))
        surface.processForTesting(.ended(candidateTouch))
        #expect(counts == 1)

        surface.processForTesting(.began([candidateTouch]))
        surface.disableAndReset()
        surface.processForTesting(.ended(candidateTouch))
        #expect(counts == 1)
    }

    @Test @MainActor func surfaceRejectsMultiTouchMovedAndCancelledSequences() {
        var counts = 0
        let first = UUID()
        let second = UUID()
        let surface = FastCountDirectTouchView(onCount: { counts += 1 })

        surface.processForTesting(.began([first, second]))
        surface.processForTesting(.ended(first))

        let invalidSurface = FastCountDirectTouchView(onCount: { counts += 1 })

        invalidSurface.processForTesting(.began([first]))
        invalidSurface.processForTesting(.began([first, second]))
        invalidSurface.processForTesting(.ended(first))

        invalidSurface.processForTesting(.began([first]))
        invalidSurface.processForTesting(.moved)
        invalidSurface.processForTesting(.ended(first))

        invalidSurface.processForTesting(.began([first]))
        invalidSurface.processForTesting(.cancelled)
        invalidSurface.processForTesting(.ended(first))

        #expect(counts == 0)
    }

    @Test @MainActor func simultaneousTwoFingerTouchExitsWithoutCounting() {
        var counts = 0
        var exits = 0
        let first = UUID()
        let second = UUID()
        let surface = FastCountDirectTouchView(
            onCount: { counts += 1 },
            onExit: { exits += 1 }
        )

        surface.processForTesting(.began([first, second]))
        surface.processForTesting(.ended(first))
        surface.processForTesting(.ended(second))

        #expect(exits == 1)
        #expect(counts == 0)
    }

    @Test @MainActor func longPressExitsWithoutCounting() {
        var counts = 0
        var exits = 0
        let surface = FastCountDirectTouchView(
            onCount: { counts += 1 },
            onExit: { exits += 1 }
        )

        surface.triggerLongPressForTesting()

        #expect(exits == 1)
        #expect(counts == 0)
    }
}
