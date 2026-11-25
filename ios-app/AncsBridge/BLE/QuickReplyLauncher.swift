import UIKit
import UserNotifications
import os.log

/// Hands a quick reply from the watch to the "WearBridge Reply" shortcut.
///
/// iOS only lets an app open a URL while it is in the foreground, and a reply sent from the
/// watch usually arrives with the iPhone in a pocket. Then the reply becomes a notification,
/// and tapping it runs the shortcut.
final class QuickReplyLauncher: NSObject, UNUserNotificationCenterDelegate {

    static let shared = QuickReplyLauncher()

    private let logger = Logger(subsystem: "com.wearos.ancsbridge", category: "QuickReply")
    private static let urlKey = "wearbridgeShortcutURL"

    private override init() {
        super.init()
    }

    /// Installs the notification delegate. Called at launch, so a tap that relaunches the app
    /// still runs the shortcut.
    func activate() {
        UNUserNotificationCenter.current().delegate = self
    }

    /// Asks for notification permission once (iOS remembers the answer). Call from the foreground.
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [logger] granted, error in
            if let error {
                logger.error("Notification permission request failed: \(error.localizedDescription)")
            } else if !granted {
                logger.info("Notifications not allowed: quick replies only work with the app open")
            }
        }
    }

    /// `shortcuts://` URL running "WearBridge Reply" with the watch's `callerName|replyText` payload.
    /// `&`, `=` and `+` are encoded too, so a name like "Mom & Dad" doesn't split the query.
    static func shortcutURL(for payload: String) -> URL? {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=+?#")
        guard let text = payload.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        return URL(string: "shortcuts://run-shortcut?name=WearBridge%20Reply&input=text&text=\(text)")
    }

    /// Runs the shortcut now when the app is in the foreground, otherwise posts a notification
    /// that runs it when tapped. Main thread.
    func deliver(_ payload: String) {
        guard let url = Self.shortcutURL(for: payload) else {
            logger.error("Quick reply could not be encoded")
            return
        }
        guard UIApplication.shared.applicationState == .active else {
            notify(payload, url: url)
            return
        }
        UIApplication.shared.open(url) { [logger] success in
            if success {
                logger.info("Opened WearBridge Reply shortcut")
            } else {
                logger.error("Failed to open Shortcuts — is the 'WearBridge Reply' shortcut created?")
            }
        }
    }

    private func notify(_ payload: String, url: URL) {
        let parts = payload.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
        let content = UNMutableNotificationContent()
        if parts.count == 2, !parts[0].isEmpty {
            content.title = "Reply to \(parts[0])"
            content.body = "\(parts[1])\nTap to send."
        } else {
            content.title = "Quick reply from your watch"
            content.body = "\(payload)\nTap to send."
        }
        content.sound = .default
        content.userInfo = [Self.urlKey: url.absoluteString]
        let request = UNNotificationRequest(identifier: "wearbridge.quickReply.\(UUID().uuidString)",
                                            content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { [logger] error in
            if let error {
                logger.error("Quick reply notification failed: \(error.localizedDescription)")
            } else {
                logger.info("Quick reply waiting for a tap (app in background)")
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        defer { completionHandler() }
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier,
              let string = response.notification.request.content.userInfo[Self.urlKey] as? String,
              let url = URL(string: string) else { return }
        DispatchQueue.main.async {
            UIApplication.shared.open(url)
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }
}
