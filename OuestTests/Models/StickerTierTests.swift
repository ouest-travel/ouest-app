import Testing
import Foundation
@testable import Ouest

@Suite("Sticker Tiers")
struct StickerTierTests {

    // Platinum is the metal for stickers nobody can earn. If an earnable
    // sticker became platinum, the metal would stop meaning "not earnable".
    @Test("Platinum is reserved for stickers that cannot be earned")
    func platinumIsNotEarnable() {
        for type in StickerType.allCases {
            #expect((type.tier == .platinum) == !type.isEarnable, "\(type) tier/earnable mismatch")
        }
    }

    // Each earnable tier has to exist, or the progression bronze → silver → gold
    // that the medal metals communicate has a missing rung.
    @Test("Every earnable tier has at least one sticker")
    func earnableTiersArePopulated() {
        let tiers = Set(StickerType.allCases.filter(\.isEarnable).map(\.tier))
        #expect(tiers == [.bronze, .silver, .gold])
    }

    @Test("Tiers order from bronze up to platinum")
    func tierOrdering() {
        #expect(StickerTier.bronze < StickerTier.silver)
        #expect(StickerTier.silver < StickerTier.gold)
        #expect(StickerTier.gold < StickerTier.platinum)
    }
}
