import Foundation
import Realtime
import Supabase
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
    private var realtimeChannel: RealtimeChannelV2?
    private var listeningTask: Task<Void, Never>?

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

    // MARK: - Realtime

    /// Subscribe to new notifications via Supabase Realtime.
    func startListening(userId: UUID) async {
        currentUserId = userId

        // Avoid duplicate subscriptions
        guard realtimeChannel == nil else { return }

        let channel = SupabaseManager.client.realtimeV2.channel(
            "user-notifications-\(userId.uuidString.prefix(8))"
        )

        let insertions = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "notifications",
            filter: .eq("user_id", value: userId)
        )

        self.realtimeChannel = channel

        try? await channel.subscribeWithError()

        listeningTask = Task { [weak self] in
            for await insertion in insertions {
                guard let self, !Task.isCancelled else { break }
                // Try to decode the full notification
                if let notification = try? insertion.decodeRecord(
                    as: AppNotification.self,
                    decoder: SupabaseManager.postgrestDecoder
                ) {
                    self.notifications.insert(notification, at: 0)
                    self.unreadCount += 1
                } else {
                    // Fallback: just bump the count — full list refreshes on view appear
                    self.unreadCount += 1
                }
            }
        }
    }

    /// Unsubscribe from realtime updates.
    func stopListening() async {
        listeningTask?.cancel()
        listeningTask = nil
        await realtimeChannel?.unsubscribe()
        realtimeChannel = nil
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

    /// Optimistically delete a notification.
    func deleteNotification(_ notification: AppNotification) async {
        let wasUnread = !notification.isRead
        notifications.removeAll { $0.id == notification.id }
        if wasUnread { unreadCount = max(0, unreadCount - 1) }

        do {
            try await NotificationService.deleteNotification(id: notification.id)
        } catch {
            // Revert: reload the full list
            await loadNotifications()
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
