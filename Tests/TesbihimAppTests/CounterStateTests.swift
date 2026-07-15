import Testing
@testable import TesbihimApp

struct CounterStateTests {
    @Test func initialStateIsFreeCounterWithNoTarget() {
        let state = CounterState.initial
        #expect(state.selectedDhikrID == "serbest")
        #expect(state.target == nil)
        #expect(state.currentCount == 0)
    }
}
