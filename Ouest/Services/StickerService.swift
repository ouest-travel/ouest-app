import Foundation
import Supabase

/// Handles all sticker/achievement badge Supabase operations.
enum StickerService {

    // MARK: - Fetch

    /// Fetch all stickers for a user (unlocked only — RLS filters out others' unequipped).
    static func fetchStickers(userId: UUID) async throws -> [UserSticker] {
        try await SupabaseManager.client
            .from("user_stickers")
            .select()
            .eq("user_id", value: userId)
            .order("unlocked_at", ascending: true)
            .execute()
            .value
    }

    /// Fetch only equipped stickers for a user (for banner display).
    static func fetchEquippedStickers(userId: UUID) async throws -> [UserSticker] {
        try await SupabaseManager.client
            .from("user_stickers")
            .select()
            .eq("user_id", value: userId)
            .eq("equipped", value: true)
            .order("unlocked_at", ascending: true)
            .execute()
            .value
    }

    // MARK: - Equip / Unequip

    /// Toggle the equipped state of a sticker.
    static func setEquipped(stickerId: UUID, equipped: Bool) async throws {
        try await SupabaseManager.client
            .from("user_stickers")
            .update(["equipped": equipped])
            .eq("id", value: stickerId)
            .execute()
    }

    // MARK: - Grant Check

    /// Call the DB function to evaluate all sticker unlock criteria.
    /// Returns the number of newly granted stickers.
    @discardableResult
    static func checkAndGrant(userId: UUID) async throws -> Int {
        try await SupabaseManager.client
            .rpc("check_and_grant_stickers", params: ["p_user_id": userId.uuidString])
            .execute()
            .value
    }
}
