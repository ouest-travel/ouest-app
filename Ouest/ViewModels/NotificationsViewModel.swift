import Foundation
import UIKit
import UserNotifications

@MainActor @Observable
final class NotificationsViewModel {

    // MARK: - State

    var notifications: [AppNotification] = []
    var isLoading = false
    var errorMessage: String?
    var unreadCount = 0

    // MARK: - Internal

    private var currentUserId: UUID?

    // MARK: - Load

    func loadNotifications() async {
        isLoading = notifications.isEmpty
        errorMessage = nil

        do {
            let userId = try await SupabaseManager.client.auth.session.user.id
            currentUserId = userId

            async let fetchedNotifications = NotificationService.fetchNotifications(userId: userId)
            async let fetchedCount = NotificationService.unreadCount(userId: userId)

            notifications = try await fetchedNotifications
            unreadCount = try await fetchedCount
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Refresh just the unread count (lightweight, for badge updates).
    func refreshUnreadCount() async {
        guard let userId = currentUserId else { return }
        do {
            unreadCount = try await NotificationService.unreadCount(userId: userId)
        } catch {
            // Silent failure — badge is non-critical
        }
    }

    // MARK: - Actions

    func markAsRead(_ notification: AppNotification) async {
        guard !notification.isRead else { return }

        // Optimistic update
        if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
            notifications[index].isRead = true
            unreadCount = max(0, unreadCount - 1)
        }

        do {
            try await NotificationService.markAsRead(id: notification.id)
        } catch {
            // Revert on failure
            if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
                notifications[index].isRead = false
                unreadCount += 1
            }
        }
    }

    func markAllAsRead() async {
        guard let userId = currentUserId else { return }

        // Optimistic update
        let previousNotifications = notifications
        let previousCount = unreadCount
        for i in notifications.indices {
            notifications[i].isRead = true
        }
        unreadCount = 0

        do {
            try await NotificationService.markAllAsRead(userId: userId)
        } catch {
            // Revert on failure
            notifications = previousNotifications
            unreadCount = previousCount
        }
    }

    // MARK: - Permission

    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            return granted
        } catch {
            print("[Push] Permission request failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Check current notification authorization status.
    func checkPermissionStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }
}
