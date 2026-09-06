import Foundation
import Observation

/// Manages sticker state: loading, equipping, and grant checking.
@MainActor @Observable
final class StickersViewModel {

    // MARK: - State

    var allStickers: [UserSticker] = []
    var isLoading = false

    var failure: OuestError?

    var failureDetail: String?

    // MARK: - Private

    private let userId: UUID

    init(userId: UUID) {
        self.userId = userId
    }

    // MARK: - Computed

    var equippedStickers: [UserSticker] {
        allStickers.filter(\.equipped)
    }

    var equippedCount: Int {
        equippedStickers.count
    }

    var unlockedCount: Int {
        allStickers.count
    }

    var totalCount: Int {
        StickerType.allCases.count
    }

    func isUnlocked(_ type: StickerType) -> Bool {
        allStickers.contains { $0.stickerId == type.databaseId }
    }

    func userSticker(for type: StickerType) -> UserSticker? {
        allStickers.first { $0.stickerId == type.databaseId }
    }

    // MARK: - Load

    func loadStickers() async {
        isLoading = true

        failure = nil

        failureDetail = nil

        do {
            allStickers = try await StickerService.fetchStickers(userId: userId)
        } catch {

            failure = OuestError(error)

            failureDetail = error.localizedDescription
            #if DEBUG
            print("[Stickers] loadStickers failed: \(error)")
            #endif
        }

        isLoading = false
    }

    // MARK: - Equip / Unequip

    /// Toggle a sticker's equipped state with optimistic update.
    func toggleEquip(_ sticker: UserSticker) {
        let newEquipped = !sticker.equipped

        // Enforce max 4 equipped
        if newEquipped && equippedCount >= 4 {
            HapticFeedback.error()
            return
        }

        // Optimistic update
        if let idx = allStickers.firstIndex(where: { $0.id == sticker.id }) {
            allStickers[idx].equipped = newEquipped
        }
        HapticFeedback.light()

        Task {
            do {
                try await StickerService.setEquipped(stickerId: sticker.id, equipped: newEquipped)
            } catch {
                // Revert on failure
                if let idx = allStickers.firstIndex(where: { $0.id == sticker.id }) {
                    allStickers[idx].equipped = !newEquipped
                }
                HapticFeedback.error()
                #if DEBUG
                print("[Stickers] toggleEquip failed: \(error)")
                #endif
            }
        }
    }

    // MARK: - Grant Check

    /// Evaluate all sticker unlock criteria and refresh.
    func refreshGrants() async {
        do {
            let newCount = try await StickerService.checkAndGrant(userId: userId)
            if newCount > 0 {
                // Reload to pick up newly granted stickers
                allStickers = try await StickerService.fetchStickers(userId: userId)
            }
        } catch {
            #if DEBUG
            print("[Stickers] refreshGrants failed: \(error)")
            #endif
        }
    }
}
