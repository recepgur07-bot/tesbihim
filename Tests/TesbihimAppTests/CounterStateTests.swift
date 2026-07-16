import Testing
@testable import TesbihimApp

struct CounterStateTests {
    @Test func initialStateIsFreeCounterWithNoTarget() {
        let state = CounterState.initial
        #expect(state.selectedDhikrID == "serbest")
        #expect(state.target == nil)
        #expect(state.currentCount == 0)
        #expect(state.canUndo == false)
        #expect(state.canReset == false)
    }

    @Test func incrementWithoutTargetJustCounts() {
        var state = CounterState.initial
        let didComplete = state.increment()
        #expect(didComplete == false)
        #expect(state.currentCount == 1)
        #expect(state.completedTargetCount == 0)
        #expect(state.canUndo)
        #expect(state.canReset)
    }

    @Test func reachingTargetStartsNewRoundAndCountsCompletion() {
        var state = CounterState.initial
        state.target = 3
        state.increment()
        state.increment()
        let didComplete = state.increment()
        #expect(didComplete)
        #expect(state.currentCount == 0)
        #expect(state.completedTargetCount == 1)
    }

    @Test func undoAfterPlainIncrementJustDecrements() {
        var state = CounterState.initial
        state.increment()
        state.increment()
        state.undoLastIncrement()
        #expect(state.currentCount == 1)
        #expect(state.canUndo == false)
    }

    @Test func undoAfterTargetCompletionRestoresPreviousRound() {
        var state = CounterState.initial
        state.target = 3
        state.increment()
        state.increment()
        state.increment() // 33/33 eşdeğeri: hedefi tamamlar, tur 0'a döner
        state.undoLastIncrement()
        #expect(state.currentCount == 2)
        #expect(state.completedTargetCount == 0)
    }

    @Test func resetClearsCurrentRoundButNotCompletedTargetCount() {
        var state = CounterState.initial
        state.target = 3
        state.increment()
        state.increment()
        state.increment()
        state.increment() // yeni turda 1
        state.reset()
        #expect(state.currentCount == 0)
        #expect(state.completedTargetCount == 1)
        #expect(state.canUndo == false)
        #expect(state.canReset == false)
    }
}
