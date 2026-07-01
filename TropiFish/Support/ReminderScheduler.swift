import Foundation
import UserNotifications

/// Local water-change reminders (brief §4.6, build-order step 7). On-device
/// only — no server, matching v1's no-backend constraint (§7). Each tank gets at
/// most one pending reminder, identified by the tank's stable `id`, so
/// rescheduling simply replaces it.
enum ReminderScheduler {
    private static let center = UNUserNotificationCenter.current()

    private static func identifier(for tank: Tank) -> String {
        "water-change-\(tank.id.uuidString)"
    }

    /// Ask for permission the first time a reminder is actually needed.
    @discardableResult
    static func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Schedule (or replace) the next reminder for a tank based on its cadence,
    /// measured from its most recent water change (or now if none). A `nil`
    /// cadence means reminders are off, so any pending one is cleared.
    ///
    /// `requestingPermission` should be `true` only when driven by an explicit
    /// user action (adding/editing a tank with reminders on) — so we never cold
    /// prompt for notifications on launch before the user has done anything.
    static func reschedule(for tank: Tank, requestingPermission: Bool = false) {
        let id = identifier(for: tank)
        center.removePendingNotificationRequests(withIdentifiers: [id])

        guard let interval = tank.reminderIntervalDays, interval > 0 else { return }

        let anchor = tank.lastWaterChange?.timestamp ?? Date()
        guard let fireDate = Calendar.current.date(byAdding: .day, value: interval, to: anchor) else { return }
        // If the computed date is already past, fire a day out so we still nudge.
        let effectiveDate = max(fireDate, Date().addingTimeInterval(24 * 60 * 60))

        let content = UNMutableNotificationContent()
        content.title = "Water change due"
        content.body = "\(tank.name) is due for a water change. Log it once you're done."
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: effectiveDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        Task {
            let status = await center.notificationSettings().authorizationStatus
            switch status {
            case .authorized, .provisional, .ephemeral:
                try? await center.add(request)
            case .notDetermined where requestingPermission:
                if await requestAuthorization() { try? await center.add(request) }
            default:
                break   // denied, or launch-time reschedule before permission — skip silently
            }
        }
    }

    /// Cancel a tank's pending reminder (e.g. on tank deletion).
    static func cancel(for tank: Tank) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier(for: tank)])
    }
}
