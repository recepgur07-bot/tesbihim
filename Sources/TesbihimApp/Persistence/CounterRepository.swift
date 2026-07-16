import Foundation

/// `CounterState`'in kalıcı saklanmasını soyutlar — bkz. PLAN.md Bölüm 3.
/// ViewModel'ler `UserDefaults`/dosya yolunu doğrudan bilmez, bu sayede
/// testlerde sahte bir uygulama enjekte edilebilir ve saklama biçimi
/// (ör. Faz 2'de CloudKit) ViewModel'i etkilemeden değiştirilebilir.
protocol CounterRepository {
    func load() -> CounterState
    func save(_ state: CounterState)
}

final class UserDefaultsCounterRepository: CounterRepository {
    private let defaults: UserDefaults
    private let key = "tesbihim.counterState"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> CounterState {
        guard
            let data = defaults.data(forKey: key),
            let state = try? JSONDecoder().decode(CounterState.self, from: data)
        else {
            return .initial
        }
        return state
    }

    func save(_ state: CounterState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: key)
    }
}
