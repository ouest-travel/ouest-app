import Foundation
import SwiftUI

enum ExpenseCategory: String, Codable, CaseIterable {
    case food
    case transport
    case stay
    case activities
    case other

    var displayName: String {
        switch self {
        case .food: return "Food"
        case .transport: return "Transport"
        case .stay: return "Stay"
        case .activities: return "Activities"
        case .other: return "Other"
        }
    }

    var emoji: String {
        switch self {
        case .food: return "🍽️"
        case .transport: return "🚗"
        case .stay: return "🏨"
        case .activities: return "🎯"
        case .other: return "📦"
        }
    }

    var color: Color {
        switch self {
        case .food: return OuestTheme.Colors.Category.food
        case .transport: return OuestTheme.Colors.Category.transport
        case .stay: return OuestTheme.Colors.Category.stay
        case .activities: return OuestTheme.Colors.Category.activities
        case .other: return OuestTheme.Colors.Category.other
        }
    }
}

struct Expense: Codable, Identifiable, Equatable {
    let id: String
    let tripId: String
    let title: String
    let amount: Decimal
    let currency: String
    let category: ExpenseCategory
    let paidBy: String
    let splitAmong: [String]
    let date: Date
    let hasChat: Bool
    let createdAt: Date

    // Optional joined data
    var paidByProfile: Profile?

    enum CodingKeys: String, CodingKey {
        case id
        case tripId = "trip_id"
        case title
        case amount
        case currency
        case category
        case paidBy = "paid_by"
        case splitAmong = "split_among"
        case date
        case hasChat = "has_chat"
        case createdAt = "created_at"
        case paidByProfile = "profiles"
    }

    static func == (lhs: Expense, rhs: Expense) -> Bool {
        lhs.id == rhs.id
    }

    // Computed properties
    var formattedAmount: String {
        CurrencyFormatter.format(amount: amount, currency: currency)
    }

    var splitAmount: Decimal {
        guard !splitAmong.isEmpty else { return amount }
        return amount / Decimal(splitAmong.count)
    }

    var formattedSplitAmount: String {
        CurrencyFormatter.format(amount: splitAmount, currency: currency)
    }
}

// MARK: - Expense Creation

struct CreateExpenseRequest: Codable {
    let tripId: String
    let title: String
    let amount: Decimal
    let currency: String
    let category: ExpenseCategory
    let paidBy: String
    let splitAmong: [String]
    let date: Date
    let hasChat: Bool

    enum CodingKeys: String, CodingKey {
        case tripId = "trip_id"
        case title
        case amount
        case currency
        case category
        case paidBy = "paid_by"
        case splitAmong = "split_among"
        case date
        case hasChat = "has_chat"
    }
}

// MARK: - Debt Calculation

struct Debt: Identifiable, Equatable {
    let id = UUID()
    let from: Profile
    let to: Profile
    let amount: Decimal
    let currency: String

    var formattedAmount: String {
        CurrencyFormatter.format(amount: amount, currency: currency)
    }
}
