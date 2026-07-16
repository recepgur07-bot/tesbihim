protocol EntitlementProviding {
    var isSupporterUnlocked: Bool { get }
}

struct PlaceholderEntitlementProvider: EntitlementProviding {
    let isSupporterUnlocked = false
}

enum FeedbackCharacterAccess {
    static func canSelect(_ character: FeedbackCharacter, entitlement: any EntitlementProviding) -> Bool {
        character == .system || entitlement.isSupporterUnlocked
    }
}
