import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, @unchecked Sendable {

    // MARK: - App Lifecycle

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = NotificationDelegate.shared
        return true
    }

    // MARK: - Remote Notification Registration

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("[Push] Registered device token: \(token)")

        // Store token in Supabase via NotificationService
        Task { @MainActor in
            do {
                let userId = try await SupabaseManager.client.auth.session.user.id
                try await NotificationService.registerToken(userId: userId, token: token)
                print("[Push] Token stored successfully")
            } catch {
                print("[Push] Failed to store token: \(error.localizedDescription)")
            }
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[Push] Failed to register: \(error.localizedDescription)")
    }
}

// MARK: - Notification Delegate (separate class to avoid Sendable issues)

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = NotificationDelegate()

    /// Show banner even when the app is in the foreground.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound])
    }

    /// Handle notification tap — the app was opened from a notification.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        print("[Push] Notification tapped: \(userInfo)")

        // Future: Deep-link navigation based on notification data
        completionHandler()
    }
}
