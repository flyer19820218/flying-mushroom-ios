import Foundation
import UserNotifications

/// Owns the iPhone notification used by route playback.  This is deliberately
/// local-only: reaching 99% does not need the Mac, Mail, Wi-Fi, or a server.
final class RouteCompletionNotifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = RouteCompletionNotifier()

    private override init() {
        super.init()
    }

    func configure() {
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                LogManager.shared.addErrorLog("Route notification authorization failed: \(error.localizedDescription)")
            } else {
                LogManager.shared.addInfoLog("Route notification authorization granted: \(granted)")
            }
        }
    }

    func notifyRouteAt99Percent(name: String) {
        let content = UNMutableNotificationContent()
        content.title = "路線即將完成 · 99%"
        content.body = name.isEmpty ? "TLocation 路線已接近終點。" : "「\(name)」已接近終點。"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "route-99-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                LogManager.shared.addErrorLog("Route 99% notification failed: \(error.localizedDescription)")
            } else {
                LogManager.shared.addInfoLog("Route 99% notification sent")
            }
        }
    }

    // Also show the banner while TLocation itself is in the foreground.  During
    // normal use the user is usually in the game, where iOS presents it anyway.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
