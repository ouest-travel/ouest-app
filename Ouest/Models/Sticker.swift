import Foundation
import SwiftUI

// MARK: - Sticker Type

enum StickerType: String, Codable, CaseIterable, Sendable {
    case dev
    case og
    case globeTrotter
    case firstTrip
    case streak
    case shutterbug
    case socialButterfly
    case jetSetter
    case storyteller
    case decisionMaker
    case crewChief
    case luxuryExplorer

    /// The snake_case identifier stored in the database.
    var databaseId: String {
        switch self {
        case .dev: return "dev"
        case .og: return "og"
        case .globeTrotter: return "globe_trotter"
        case .firstTrip: return "first_trip"
        case .streak: return "streak"
        case .shutterbug: return "shutterbug"
        case .socialButterfly: return "social_butterfly"
        case .jetSetter: return "jet_setter"
        case .storyteller: return "storyteller"
        case .decisionMaker: return "decision_maker"
        case .crewChief: return "crew_chief"
        case .luxuryExplorer: return "luxury_explorer"
        }
    }

    /// Resolve from a database sticker_id string.
    static func from(databaseId: String) -> StickerType? {
        allCases.first { $0.databaseId == databaseId }
    }

    var displayName: String {
        switch self {
        case .dev: return "Dev"
        case .og: return "OG"
        case .globeTrotter: return "Globe Trotter"
        case .firstTrip: return "First Trip"
        case .streak: return "Streak"
        case .shutterbug: return "Shutterbug"
        case .socialButterfly: return "Social Butterfly"
        case .jetSetter: return "Jet Setter"
        case .storyteller: return "Storyteller"
        case .decisionMaker: return "Decision Maker"
        case .crewChief: return "Crew Chief"
        case .luxuryExplorer: return "Luxury Explorer"
        }
    }

    /// SF Symbol name for the sticker icon.
    var icon: String {
        switch self {
        case .dev: return "chevron.left.forwardslash.chevron.right"
        case .og: return "star.fill"
        case .globeTrotter: return "globe.americas.fill"
        case .firstTrip: return "doc.text.fill"
        case .streak: return "flame.fill"
        case .shutterbug: return "camera.fill"
        case .socialButterfly: return "heart.circle.fill"
        case .jetSetter: return "paperplane.fill"
        case .storyteller: return "book.fill"
        case .decisionMaker: return "checklist"
        case .crewChief: return "person.3.fill"
        case .luxuryExplorer: return "diamond.fill"
        }
    }

    /// Primary foil color.
    var foilColor: Color {
        switch self {
        case .dev: return Color(hex: 0x10B981)
        case .og: return Color(hex: 0xF59E0B)
        case .globeTrotter: return Color(hex: 0x2563EB)
        case .firstTrip: return Color(hex: 0x14B8A6)
        case .streak: return Color(hex: 0xF97316)
        case .shutterbug: return Color(hex: 0xEC4899)
        case .socialButterfly: return Color(hex: 0xA855F7)
        case .jetSetter: return Color(hex: 0x38BDF8)
        case .storyteller: return Color(hex: 0x6366F1)
        case .decisionMaker: return Color(hex: 0x06B6D4)
        case .crewChief: return Color(hex: 0xD97706)
        case .luxuryExplorer: return Color(hex: 0x8B5CF6)
        }
    }

    /// Lighter foil variant.
    var foilAltColor: Color {
        switch self {
        case .dev: return Color(hex: 0x34D399)
        case .og: return Color(hex: 0xFBBF24)
        case .globeTrotter: return Color(hex: 0x3B82F6)
        case .firstTrip: return Color(hex: 0x2DD4BF)
        case .streak: return Color(hex: 0xFB923C)
        case .shutterbug: return Color(hex: 0xF472B6)
        case .socialButterfly: return Color(hex: 0xC084FC)
        case .jetSetter: return Color(hex: 0x7DD3FC)
        case .storyteller: return Color(hex: 0x818CF8)
        case .decisionMaker: return Color(hex: 0x22D3EE)
        case .crewChief: return Color(hex: 0xF59E0B)
        case .luxuryExplorer: return Color(hex: 0xA78BFA)
        }
    }

    /// Darker foil variant for depth.
    var foilDeepColor: Color {
        switch self {
        case .dev: return Color(hex: 0x059669)
        case .og: return Color(hex: 0xD97706)
        case .globeTrotter: return Color(hex: 0x1D4ED8)
        case .firstTrip: return Color(hex: 0x0D9488)
        case .streak: return Color(hex: 0xEA580C)
        case .shutterbug: return Color(hex: 0xDB2777)
        case .socialButterfly: return Color(hex: 0x9333EA)
        case .jetSetter: return Color(hex: 0x0284C7)
        case .storyteller: return Color(hex: 0x4F46E5)
        case .decisionMaker: return Color(hex: 0x0891B2)
        case .crewChief: return Color(hex: 0xB45309)
        case .luxuryExplorer: return Color(hex: 0x7C3AED)
        }
    }

    /// User-facing unlock criteria description.
    var unlockCriteria: String {
        switch self {
        case .dev: return "Granted to developers"
        case .og: return "Signed up during early testing"
        case .globeTrotter: return "Visit 5+ destinations"
        case .firstTrip: return "Create your first trip"
        case .streak: return "Create 3+ trips"
        case .shutterbug: return "Upload 10+ photos"
        case .socialButterfly: return "Gain 20+ followers"
        case .jetSetter: return "Visit 10+ destinations"
        case .storyteller: return "Write 5+ journal entries"
        case .decisionMaker: return "Create 10+ polls"
        case .crewChief: return "Invite 10+ trip members"
        case .luxuryExplorer: return "Plan a $5,000+ trip"
        }
    }

    /// Long description for the detail view.
    var description: String {
        switch self {
        case .dev: return "You helped build Ouest. This badge marks you as part of the team behind the app."
        case .og: return "You believed in Ouest from the start. This badge is reserved for early testers who helped shape the app."
        case .globeTrotter: return "Five destinations and counting. You're building an impressive travel portfolio."
        case .firstTrip: return "Every journey begins with a single trip. You've taken that first step."
        case .streak: return "Three trips planned means you've caught the travel bug. Keep the streak alive."
        case .shutterbug: return "Your gallery is growing. Ten photos captured — each one a memory preserved."
        case .socialButterfly: return "Twenty followers and growing. Your travel stories are inspiring others."
        case .jetSetter: return "Ten destinations explored. You're a seasoned traveler with stories to tell."
        case .storyteller: return "Five journal entries written. You're documenting your adventures beautifully."
        case .decisionMaker: return "Ten polls created. You bring democracy to travel planning."
        case .crewChief: return "Ten invites sent. You're the one who brings the crew together."
        case .luxuryExplorer: return "A five-thousand dollar trip planned. You appreciate the finer things in travel."
        }
    }
}

// MARK: - User Sticker (DB row)

struct UserSticker: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let userId: UUID
    let stickerId: String
    let unlockedAt: Date
    var equipped: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case stickerId = "sticker_id"
        case unlockedAt = "unlocked_at"
        case equipped
    }

    /// Resolved sticker type from the database ID.
    var type: StickerType? {
        StickerType.from(databaseId: stickerId)
    }
}
