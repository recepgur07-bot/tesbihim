import Testing
@testable import TesbihimApp

@MainActor struct ReminderManagerTests {
    @Test func deniedPermissionNeverSchedules() async {
        let center = FakeNotificationCenter(settings: .init(authorization: .denied, alertsEnabled: false, soundsEnabled: false))
        let manager = ReminderManager(center: center)
        await manager.refreshSettings()
        let result = await manager.replaceReminders(dhikrID: "x", name: "Zikir", schedules: [.init(weekday: 2, hour: 9, minute: 0)])
        #expect(result == false); #expect(center.scheduled.isEmpty)
    }

    @Test func replacingRemindersRemovesOldStableIdentifiersAndSchedulesEachDay() async {
        let center = FakeNotificationCenter(settings: .init(authorization: .authorized, alertsEnabled: true, soundsEnabled: true))
        let manager = ReminderManager(center: center)
        let schedules = [ReminderSchedule(weekday: 2, hour: 9, minute: 0), .init(weekday: 3, hour: 9, minute: 0)]
        #expect(await manager.replaceReminders(dhikrID: "x", name: "Zikir", schedules: schedules))
        #expect(center.removedPrefixes == ["x_"])
        #expect(center.scheduled.map(\.identifier) == ["x_2_9_0", "x_3_9_0"])
        #expect(center.scheduled.allSatisfy { $0.threadIdentifier == "tesbihim_hatirlaticilar" && $0.userInfo == ["dhikrID": "x"] })
    }
    @Test func deepLinkFallsBackToLibraryForRemovedOrUnknownDhikr() {
        #expect(NotificationDeepLinkRouter.destination(dhikrID: "active", activeIDs: ["active"]) == .counter("active"))
        #expect(NotificationDeepLinkRouter.destination(dhikrID: "removed", activeIDs: ["active"]) == .library)
        #expect(NotificationDeepLinkRouter.destination(dhikrID: nil, activeIDs: ["active"]) == .library)
    }
}

@MainActor private final class FakeNotificationCenter: NotificationCenterProviding {
    var settings: NotificationSettingsSnapshot; var scheduled: [ReminderRequest] = []; var removedPrefixes: [String] = []
    init(settings: NotificationSettingsSnapshot) { self.settings = settings }
    func currentSettings() async -> NotificationSettingsSnapshot { settings }
    func requestAuthorization() async -> Bool { settings.authorization == .authorized }
    func replaceRequests(removingPrefix prefix: String, with requests: [ReminderRequest]) async { removedPrefixes.append(prefix); scheduled = requests }
}
