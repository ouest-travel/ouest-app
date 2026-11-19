import Foundation

// MARK: - Moderation Service

/// Report + block, required by App Store Guideline 1.2 for any app with
/// user-generated content. Backed by `reports` and `blocked_users`
/// (migration 00033).
enum ModerationService {

    // MARK: - Reports

    static func report(
        _ target: ReportTarget,
        reason: ReportReason,
        reporterId: UUID
    ) async throws {
        let payload = ReportPayload(
            reporterId: reporterId,
            targetType: target.kind.rawValue,
            targetId: target.id,
            reason: reason.rawValue
        )
        try await SupabaseManager.client
            .from("reports")
            .insert(payload)
            .execute()
    }

    // MARK: - Blocks

    static func block(userId: UUID, by blockerId: UUID) async throws {
        let payload = BlockPayload(blockerId: blockerId, blockedId: userId)
        try await SupabaseManager.client
            .from("blocked_users")
            .upsert(payload, onConflict: "blocker_id,blocked_id")
            .execute()
    }

    static func unblock(userId: UUID, by blockerId: UUID) async throws {
        try await SupabaseManager.client
            .from("blocked_users")
            .delete()
            .eq("blocker_id", value: blockerId)
            .eq("blocked_id", value: userId)
            .execute()
    }

    /// Ids of everyone `userId` has blocked. Callers filter feed, comments
    /// and people search against this set.
    static func fetchBlockedIds(for userId: UUID) async throws -> Set<UUID> {
        let rows: [BlockedIdRow] = try await SupabaseManager.client
            .from("blocked_users")
            .select("blocked_id")
            .eq("blocker_id", value: userId)
            .execute()
            .value
        return Set(rows.map(\.blockedId))
    }
}

// MARK: - Internal Payloads

private struct ReportPayload: Encodable {
    let reporterId: UUID
    let targetType: String
    let targetId: UUID
    let reason: String

    enum CodingKeys: String, CodingKey {
        case reporterId = "reporter_id"
        case targetType = "target_type"
        case targetId = "target_id"
        case reason
    }
}

private struct BlockPayload: Encodable {
    let blockerId: UUID
    let blockedId: UUID

    enum CodingKeys: String, CodingKey {
        case blockerId = "blocker_id"
        case blockedId = "blocked_id"
    }
}

private struct BlockedIdRow: Decodable {
    let blockedId: UUID

    enum CodingKeys: String, CodingKey {
        case blockedId = "blocked_id"
    }
}
