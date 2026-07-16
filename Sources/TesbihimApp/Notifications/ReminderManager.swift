import Foundation
import Observation
import UserNotifications

enum NotificationDestination: Equatable { case counter(String), library }
enum NotificationDeepLinkRouter {
    static func destination(dhikrID: String?, activeIDs: Set<String>) -> NotificationDestination {
        guard let dhikrID, activeIDs.contains(dhikrID) else { return .library }
        return .counter(dhikrID)
    }
}

extension Notification.Name { static let tesbihimReminderOpened = Notification.Name("tesbihimReminderOpened") }

enum NotificationAuthorization: Equatable { case notDetermined, authorized, denied }
struct NotificationSettingsSnapshot: Equatable {
    var authorization: NotificationAuthorization
    var alertsEnabled: Bool
    var soundsEnabled: Bool
}
struct ReminderRequest: Equatable {
    var identifier: String; var weekday: Int; var hour: Int; var minute: Int
    var title: String; var body: String; var threadIdentifier: String; var userInfo: [String: String]
}

@MainActor protocol NotificationCenterProviding: AnyObject {
    func currentSettings() async -> NotificationSettingsSnapshot
    func requestAuthorization() async -> Bool
    func replaceRequests(removingPrefix: String, with: [ReminderRequest]) async
}

@MainActor @Observable final class ReminderManager {
    private let center: NotificationCenterProviding
    private(set) var settings = NotificationSettingsSnapshot(authorization: .notDetermined, alertsEnabled: false, soundsEnabled: false)
    init(center: NotificationCenterProviding = SystemNotificationCenter()) { self.center = center }
    func refreshSettings() async { settings = await center.currentSettings() }
    func requestPermissionIfNeeded() async -> Bool {
        if settings.authorization == .notDetermined { _ = await center.requestAuthorization(); await refreshSettings() }
        return settings.authorization == .authorized && settings.alertsEnabled
    }
    @discardableResult func replaceReminders(dhikrID: String, name: String, schedules: [ReminderSchedule]) async -> Bool {
        await refreshSettings(); guard await requestPermissionIfNeeded() else { return false }
        let requests = schedules.sorted { ($0.weekday, $0.hour, $0.minute) < ($1.weekday, $1.hour, $1.minute) }.map {
            ReminderRequest(identifier: $0.requestIdentifier(dhikrID: dhikrID), weekday: $0.weekday, hour: $0.hour, minute: $0.minute,
                title: "Tesbihim", body: "\(name) için ayarladığınız hatırlatıcı", threadIdentifier: "tesbihim_hatirlaticilar", userInfo: ["dhikrID": dhikrID])
        }
        await center.replaceRequests(removingPrefix: "\(dhikrID)_", with: requests); return true
    }
    func removeReminders(dhikrID: String) async { await center.replaceRequests(removingPrefix: "\(dhikrID)_", with: []) }
    /// "Tüm Verilerimi Sil" — bkz. PLAN.md Bölüm 7.3. Boş önek her
    /// bekleyen isteğin `hasPrefix` eşleşmesini sağlar, tüm hatırlatıcılar
    /// kaldırılır.
    func removeAllReminders() async { await center.replaceRequests(removingPrefix: "", with: []) }
}

@MainActor final class SystemNotificationCenter: NotificationCenterProviding {
    private let center = UNUserNotificationCenter.current()
    func currentSettings() async -> NotificationSettingsSnapshot {
        let value = await center.notificationSettings()
        let auth: NotificationAuthorization = switch value.authorizationStatus { case .notDetermined: .notDetermined; case .denied: .denied; default: .authorized }
        return .init(authorization: auth, alertsEnabled: value.alertSetting == .enabled, soundsEnabled: value.soundSetting == .enabled)
    }
    func requestAuthorization() async -> Bool { (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false }
    func replaceRequests(removingPrefix prefix: String, with requests: [ReminderRequest]) async {
        let pending = await center.pendingNotificationRequests(); center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(prefix) })
        for request in requests {
            let content = UNMutableNotificationContent(); content.title = request.title; content.body = request.body; content.sound = .default; content.threadIdentifier = request.threadIdentifier; content.userInfo = request.userInfo
            let components = DateComponents(hour: request.hour, minute: request.minute, weekday: request.weekday)
            try? await center.add(UNNotificationRequest(identifier: request.identifier, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)))
        }
    }
}
