import Foundation

// MARK: - Notification Service

enum NotificationService {

    // MARK: - Device Token Management

    /// Register (upsert) a device token for push notifications.
    static func registerToken(userId: UUID, token: String) async throws {
        let payload = DeviceTokenPayload(userId: userId, token: token, platform: "ios")
        try await SupabaseManager.client
            .from("device_tokens")
            .upsert(payload, onConflict: "user_id,token")
            .execute()
    }

    /// Remove a specific device token (e.g., on sign out).
    static func removeToken(userId: UUID, token: String) async throws {
        try await SupabaseManager.client
            .from("device_tokens")
            .delete()
            .eq("user_id", value: userId)
            .eq("token", value: token)
            .execute()
    }

    /// Remove all device tokens for a user (e.g., on account deletion).
    static func removeAllTokens(userId: UUID) async throws {
        try await SupabaseManager.client
            .from("device_tokens")
            .delete()
            .eq("user_id", value: userId)
            .execute()
    }

    // MARK: - Notifications CRUD

    /// Fetch notifications for the current user, newest first.
    static func fetchNotifications(userId: UUID, limit: Int = 50, offset: Int = 0) async throws -> [AppNotification] {
        try await SupabaseManager.client
            .from("notifications")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value
    }

    /// Get the count of unread notifications.
    static func unreadCount(userId: UUID) async throws -> Int {
        let rows: [NotificationIdRow] = try await SupabaseManager.client
            .from("notifications")
            .select("id")
            .eq("user_id", value: userId)
            .eq("is_read", value: false)
            .execute()
            .value
        return rows.count
    }

    /// Mark a single notification as read.
    static func markAsRead(id: UUID) async throws {
        try await SupabaseManager.client
            .from("notifications")
            .update(["is_read": true])
            .eq("id", value: id)
            .execute()
    }

    /// Mark all notifications as read for a user.
    static func markAllAsRead(userId: UUID) async throws {
        try await SupabaseManager.client
            .from("notifications")
            .update(["is_read": true])
            .eq("user_id", value: userId)
            .eq("is_read", value: false)
            .execute()
    }

    // MARK: - Notification Preferences

    /// Fetch notification preferences for a user. Returns nil if none exist.
    static func fetchPreferences(userId: UUID) async throws -> NotificationPreference? {
        let rows: [NotificationPreference] = try await SupabaseManager.client
            .from("notification_preferences")
            .select()
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    /// Upsert notification preferences.
    static func updatePreferences(_ preferences: NotificationPreference) async throws {
        try await SupabaseManager.client
            .from("notification_preferences")
            .upsert(preferences, onConflict: "user_id")
            .execute()
    }

    // MARK: - Push Trigger (Edge Function)

    /// Invoke the push-notification Edge Function to send APNs pushes.
    /// This is best-effort — the in-app notifications are already stored by DB triggers.
    static func triggerPush(userIds: [UUID], title: String, body: String, data: [String: String] = [:]) async {
        let payload = PushTriggerPayload(userIds: userIds, title: title, body: body, data: data)

        do {
            try await SupabaseManager.client.functions.invoke(
                "push-notification",
                options: .init(body: payload)
            )
        } catch {
            // Push delivery is best-effort — don't propagate errors
            print("[Push] Edge function call failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Internal Helpers

/// Minimal struct for counting notification rows by ID.
private struct NotificationIdRow: Decodable {
    let id: UUID
}
