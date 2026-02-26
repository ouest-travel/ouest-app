import Foundation
import SwiftUI

// MARK: - Expense Category

enum ExpenseCategory: String, Codable, CaseIterable, Sendable {
    case food
    case transport
    case accommodation
    case activity
    case shopping
    case entertainment
    case other

    var label: String {
        switch self {
        case .food: "Food"
        case .transport: "Transport"
        case .accommodation: "Accommodation"
        case .activity: "Activity"
        case .shopping: "Shopping"
        case .entertainment: "Entertainment"
        case .other: "Other"
        }
    }

    var icon: String {
        switch self {
        case .food: "fork.knife"
        case .transport: "car.fill"
        case .accommodation: "bed.double.fill"
        case .activity: "figure.walk"
        case .shopping: "bag.fill"
        case .entertainment: "theatermasks.fill"
        case .other: "ellipsis.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .food: .orange
        case .transport: .blue
        case .accommodation: .purple
        case .activity: .green
        case .shopping: .pink
        case .entertainment: .indigo
        case .other: .gray
        }
    }
}

// MARK: - Split Type

enum SplitType: String, Codable, CaseIterable, Sendable {
    case equal
    case custom
    case full

    var label: String {
        switch self {
        case .equal: "Split Equally"
        case .custom: "Custom Split"
        case .full: "Full Amount"
        }
    }

    var icon: String {
        switch self {
        case .equal: "equal.circle.fill"
        case .custom: "slider.horizontal.3"
        case .full: "person.fill"
        }
    }
}

// MARK: - Expense

struct Expense: Codable, Identifiable, Sendable {
    let id: UUID
    let tripId: UUID
    let paidBy: UUID
    var title: String
    var description: String?
    var amount: Double
    var currency: String?
    var category: ExpenseCategory
    var date: Date?
    var splitType: SplitType
    let createdAt: Date?
    var updatedAt: Date?

    /// Nested splits (populated via Supabase join)
    var splits: [ExpenseSplit]?
    /// Nested profile of payer (populated via Supabase join)
    var paidByProfile: Profile?

    enum CodingKeys: String, CodingKey {
        case id, title, description, amount, currency, category, date, splits
        case tripId = "trip_id"
        case paidBy = "paid_by"
        case splitType = "split_type"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case paidByProfile = "paid_by_profile"
    }

    // MARK: - Memberwise init (tests + previews)

    init(
        id: UUID = UUID(), tripId: UUID, paidBy: UUID, title: String,
        description: String? = nil, amount: Double, currency: String? = nil,
        category: ExpenseCategory = .other, date: Date? = nil,
        splitType: SplitType = .equal, createdAt: Date? = nil, updatedAt: Date? = nil,
        splits: [ExpenseSplit]? = nil, paidByProfile: Profile? = nil
    ) {
        self.id = id; self.tripId = tripId; self.paidBy = paidBy
        self.title = title; self.description = description
        self.amount = amount; self.currency = currency
        self.category = category; self.date = date
        self.splitType = splitType; self.createdAt = createdAt
        self.updatedAt = updatedAt; self.splits = splits
        self.paidByProfile = paidByProfile
    }

    // MARK: - Custom decoder for optional nested arrays

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        tripId = try container.decode(UUID.self, forKey: .tripId)
        paidBy = try container.decode(UUID.self, forKey: .paidBy)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        amount = try container.decode(Double.self, forKey: .amount)
        currency = try container.decodeIfPresent(String.self, forKey: .currency)
        category = try container.decode(ExpenseCategory.self, forKey: .category)
        date = try container.decodeIfPresent(Date.self, forKey: .date)
        splitType = try container.decode(SplitType.self, forKey: .splitType)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        splits = try? container.decode([ExpenseSplit].self, forKey: .splits)
        paidByProfile = try? container.decode(Profile.self, forKey: .paidByProfile)
    }

    // MARK: - Computed Properties

    /// Formatted amount: "$25.00"
    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency ?? "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }

    /// Formatted date: "Mar 15, 2025"
    var formattedDate: String? {
        guard let date else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    /// Name of the person who paid
    var paidByName: String {
        paidByProfile?.fullName ?? "Unknown"
    }

    /// Description of the split: "Split 3 ways" or "Paid in full"
    var splitDescription: String {
        switch splitType {
        case .full:
            return "Paid in full"
        case .equal, .custom:
            let count = splits?.count ?? 0
            return count > 0 ? "Split \(count) way\(count == 1 ? "" : "s")" : "Not split"
        }
    }
}

// MARK: - Expense Split

struct ExpenseSplit: Codable, Identifiable, Sendable {
    let id: UUID
    let expenseId: UUID
    let userId: UUID
    var amount: Double
    var isSettled: Bool
    var settledAt: Date?
    let createdAt: Date?

    /// Nested profile data (populated via Supabase join)
    var profile: Profile?

    enum CodingKeys: String, CodingKey {
        case id, amount, profile
        case expenseId = "expense_id"
        case userId = "user_id"
        case isSettled = "is_settled"
        case settledAt = "settled_at"
        case createdAt = "created_at"
    }

    init(
        id: UUID = UUID(), expenseId: UUID, userId: UUID, amount: Double,
        isSettled: Bool = false, settledAt: Date? = nil,
        createdAt: Date? = nil, profile: Profile? = nil
    ) {
        self.id = id; self.expenseId = expenseId; self.userId = userId
        self.amount = amount; self.isSettled = isSettled
        self.settledAt = settledAt; self.createdAt = createdAt
        self.profile = profile
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        expenseId = try container.decode(UUID.self, forKey: .expenseId)
        userId = try container.decode(UUID.self, forKey: .userId)
        amount = try container.decode(Double.self, forKey: .amount)
        isSettled = try container.decode(Bool.self, forKey: .isSettled)
        settledAt = try container.decodeIfPresent(Date.self, forKey: .settledAt)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        profile = try? container.decode(Profile.self, forKey: .profile)
    }

    /// Formatted split amount
    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }

    /// Display name from profile
    var displayName: String {
        profile?.fullName ?? "Unknown"
    }
}

// MARK: - Balance & Settlement Types

struct MemberBalance: Identifiable, Sendable {
    let userId: UUID
    let name: String
    let avatarUrl: String?
    var totalPaid: Double
    var totalOwed: Double

    var id: UUID { userId }

    var netBalance: Double { totalPaid - totalOwed }

    /// Positive = others owe them, negative = they owe others
    var formattedBalance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        let abs = Swift.abs(netBalance)
        let formatted = formatter.string(from: NSNumber(value: abs)) ?? "$\(abs)"
        if netBalance > 0.01 { return "+\(formatted)" }
        if netBalance < -0.01 { return "-\(formatted)" }
        return formatted
    }

    var isSettled: Bool { abs(netBalance) < 0.01 }
}

struct Settlement: Identifiable, Sendable {
    let from: MemberBalance
    let to: MemberBalance
    let amount: Double

    var id: String { "\(from.userId)-\(to.userId)" }

    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

// MARK: - Create Expense Payload

struct CreateExpensePayload: Codable, Sendable {
    let tripId: UUID
    let paidBy: UUID
    let title: String
    let description: String?
    let amount: Double
    let currency: String?
    let category: ExpenseCategory
    let date: Date?
    let splitType: SplitType

    enum CodingKeys: String, CodingKey {
        case title, description, amount, currency, category, date
        case tripId = "trip_id"
        case paidBy = "paid_by"
        case splitType = "split_type"
    }
}

// MARK: - Update Expense Payload

struct UpdateExpensePayload: Codable, Sendable {
    var title: String?
    var description: String?
    var amount: Double?
    var currency: String?
    var category: ExpenseCategory?
    var date: Date?
    var splitType: SplitType?

    enum CodingKeys: String, CodingKey {
        case title, description, amount, currency, category, date
        case splitType = "split_type"
    }
}

// MARK: - Create Split Payload

struct CreateSplitPayload: Codable, Sendable {
    let expenseId: UUID
    let userId: UUID
    let amount: Double

    enum CodingKeys: String, CodingKey {
        case amount
        case expenseId = "expense_id"
        case userId = "user_id"
    }
}
