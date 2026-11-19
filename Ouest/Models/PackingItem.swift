import Foundation
import SwiftUI

// MARK: - Packing Category

enum PackingCategory: String, Codable, CaseIterable, Sendable {
    case essentials
    case clothing
    case toiletries
    case tech
    case documents
    case other

    var label: String {
        switch self {
        case .essentials: "Essentials"
        case .clothing: "Clothing"
        case .toiletries: "Toiletries"
        case .tech: "Tech"
        case .documents: "Documents"
        case .other: "Other"
        }
    }

    var icon: String {
        switch self {
        case .essentials: "star"
        case .clothing: "tshirt"
        case .toiletries: "drop"
        case .tech: "powerplug"
        case .documents: "doc.text"
        case .other: "shippingbox"
        }
    }
}

// MARK: - Packing Item

struct PackingItem: Codable, Identifiable, Sendable, Equatable {
    let id: UUID
    let tripId: UUID
    var title: String
    var category: PackingCategory
    var assignedTo: UUID?
    var isPacked: Bool
    let createdBy: UUID
    let createdAt: Date?
    var updatedAt: Date?

    /// Joined from Supabase (`assignee:profiles!packing_items_assigned_to_fkey`).
    var assignee: Profile?

    enum CodingKeys: String, CodingKey {
        case id, title, category, assignee
        case tripId = "trip_id"
        case assignedTo = "assigned_to"
        case isPacked = "is_packed"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    static func == (lhs: PackingItem, rhs: PackingItem) -> Bool {
        lhs.id == rhs.id
            && lhs.title == rhs.title
            && lhs.category == rhs.category
            && lhs.assignedTo == rhs.assignedTo
            && lhs.isPacked == rhs.isPacked
    }
}

// MARK: - Payloads

struct CreatePackingItemPayload: Codable, Sendable {
    let tripId: UUID
    let title: String
    let category: PackingCategory
    let assignedTo: UUID?
    let createdBy: UUID

    enum CodingKeys: String, CodingKey {
        case title, category
        case tripId = "trip_id"
        case assignedTo = "assigned_to"
        case createdBy = "created_by"
    }
}

/// Partial update. Only the fields set are sent; `assignedTo` uses
/// `nullFields` semantics via `clearAssignee` so "unassign" encodes as
/// an explicit null rather than being omitted.
struct UpdatePackingItemPayload: Encodable, Sendable {
    var title: String? = nil
    var category: PackingCategory? = nil
    var assignedTo: UUID? = nil
    var clearAssignee = false
    var isPacked: Bool? = nil

    enum CodingKeys: String, CodingKey {
        case title, category
        case assignedTo = "assigned_to"
        case isPacked = "is_packed"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(title, forKey: .title)
        try c.encodeIfPresent(category, forKey: .category)
        try c.encodeIfPresent(isPacked, forKey: .isPacked)
        if clearAssignee {
            try c.encodeNil(forKey: .assignedTo)
        } else {
            try c.encodeIfPresent(assignedTo, forKey: .assignedTo)
        }
    }
}

// MARK: - Starter list

extension PackingItem {
    /// A sensible first list for an empty trip, so the group starts from
    /// something rather than a blank screen. Kept destination-agnostic.
    static let starterItems: [(title: String, category: PackingCategory)] = [
        ("Passport or ID", .documents),
        ("Tickets and bookings", .documents),
        ("Phone charger", .tech),
        ("Power adapter", .tech),
        ("Headphones", .tech),
        ("Toothbrush and toothpaste", .toiletries),
        ("Sunscreen", .toiletries),
        ("Medication", .essentials),
        ("Wallet and cards", .essentials),
        ("Reusable water bottle", .essentials),
        ("Comfortable shoes", .clothing),
        ("Jacket", .clothing),
    ]
}
