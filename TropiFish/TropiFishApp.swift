import SwiftUI
import SwiftData
import UserNotifications

/// App entry point (brief §7). Builds the on-device SwiftData store through the
/// single `TropiFishSchema` factory and injects it into the environment.
@main
struct TropiFishApp: App {
    let container: ModelContainer
    private let notificationDelegate = NotificationDelegate()

    init() {
        do {
            container = try TropiFishSchema.makeContainer()
        } catch {
            // A store that won't open is unrecoverable; fail loudly in dev.
            fatalError("Failed to create ModelContainer: \(error)")
        }
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    var body: some Scene {
        WindowGroup {
            TankListView()
        }
        .modelContainer(container)
    }
}

/// Presents water-change reminders even while the app is in the foreground, so a
/// reminder isn't silently swallowed if the user happens to have the app open.
private final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
