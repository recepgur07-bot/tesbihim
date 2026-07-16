import Foundation

protocol CustomDhikrRepository: AnyObject {
    func load() -> [CustomDhikr]
    func save(_ items: [CustomDhikr])
}

protocol DhikrUserStateRepository: AnyObject {
    func load() -> [DhikrUserState]
    func save(_ items: [DhikrUserState])
}

final class UserDefaultsCustomDhikrRepository: CustomDhikrRepository {
    private let defaults: UserDefaults; private let key: String
    init(defaults: UserDefaults = .standard, key: String = "customDhikrs") { self.defaults = defaults; self.key = key }
    func load() -> [CustomDhikr] { defaults.data(forKey: key).flatMap { try? JSONDecoder().decode([CustomDhikr].self, from: $0) } ?? [] }
    func save(_ items: [CustomDhikr]) { defaults.set(try? JSONEncoder().encode(items), forKey: key) }
}

final class UserDefaultsDhikrUserStateRepository: DhikrUserStateRepository {
    private let defaults: UserDefaults; private let key: String
    init(defaults: UserDefaults = .standard, key: String = "dhikrUserStates") { self.defaults = defaults; self.key = key }
    func load() -> [DhikrUserState] { defaults.data(forKey: key).flatMap { try? JSONDecoder().decode([DhikrUserState].self, from: $0) } ?? [] }
    func save(_ items: [DhikrUserState]) { defaults.set(try? JSONEncoder().encode(items), forKey: key) }
}

struct DhikrRemovalService {
    let customRepository: CustomDhikrRepository
    let stateRepository: DhikrUserStateRepository
    var now: () -> Date = Date.init

    func purgeExpiredCustomDhikrs() {
        let cutoff = now().addingTimeInterval(-30 * 86_400)
        var customs = customRepository.load()
        var states = stateRepository.load()
        let customIDs = Set(customs.map(\.id))
        let expired = Set(states.compactMap { state in
            state.removedAt.map { $0 <= cutoff && customIDs.contains(state.dhikrID) ? state.dhikrID : nil } ?? nil
        })
        guard !expired.isEmpty else { return }
        customs.removeAll { expired.contains($0.id) }
        states.removeAll { expired.contains($0.dhikrID) }
        customRepository.save(customs); stateRepository.save(states)
    }
}
