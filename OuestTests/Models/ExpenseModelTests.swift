import Testing
import Foundation
@testable import Ouest

@Suite("Expense Models")
struct ExpenseModelTests {

    // MARK: - ExpenseCategory

    @Test("All categories have non-empty labels and icons")
    func categoryProperties() {
        for cat in ExpenseCategory.allCases {
            #expect(!cat.label.isEmpty)
            #expect(!cat.icon.isEmpty)
        }
    }

    @Test("Category count is 7")
    func categoryCount() {
        #expect(ExpenseCategory.allCases.count == 7)
    }

    @Test("Category raw values match database values")
    func categoryRawValues() {
        #expect(ExpenseCategory.food.rawValue == "food")
        #expect(ExpenseCategory.transport.rawValue == "transport")
        #expect(ExpenseCategory.accommodation.rawValue == "accommodation")
        #expect(ExpenseCategory.activity.rawValue == "activity")
        #expect(ExpenseCategory.shopping.rawValue == "shopping")
        #expect(ExpenseCategory.entertainment.rawValue == "entertainment")
        #expect(ExpenseCategory.other.rawValue == "other")
    }

    // MARK: - SplitType

    @Test("All split types have labels and icons")
    func splitTypeProperties() {
        for st in SplitType.allCases {
            #expect(!st.label.isEmpty)
            #expect(!st.icon.isEmpty)
        }
    }

    @Test("Split type count is 3")
    func splitTypeCount() {
        #expect(SplitType.allCases.count == 3)
    }

    // MARK: - Expense

    @Test("Expense formattedAmount uses currency code")
    func formattedAmount() {
        let expense = Expense(tripId: UUID(), paidBy: UUID(), title: "Dinner", amount: 42.50, currency: "EUR")
        let formatted = expense.formattedAmount
        #expect(formatted.contains("42"))
    }

    @Test("Expense formattedAmount defaults to USD")
    func formattedAmountDefault() {
        let expense = Expense(tripId: UUID(), paidBy: UUID(), title: "Lunch", amount: 15.00)
        let formatted = expense.formattedAmount
        #expect(formatted.contains("15"))
    }

    @Test("Expense formattedDate returns nil when no date")
    func formattedDateNil() {
        let expense = Expense(tripId: UUID(), paidBy: UUID(), title: "Test", amount: 10)
        #expect(expense.formattedDate == nil)
    }

    @Test("Expense formattedDate returns string when date present")
    func formattedDatePresent() {
        let expense = Expense(tripId: UUID(), paidBy: UUID(), title: "Test", amount: 10, date: Date())
        #expect(expense.formattedDate != nil)
    }

    @Test("Expense paidByName uses profile name or Unknown")
    func paidByName() {
        let withProfile = Expense(
            tripId: UUID(), paidBy: UUID(), title: "Test", amount: 10,
            paidByProfile: Profile(id: UUID(), email: "a@b.com", fullName: "Alice", createdAt: nil)
        )
        #expect(withProfile.paidByName == "Alice")

        let withoutProfile = Expense(tripId: UUID(), paidBy: UUID(), title: "Test", amount: 10)
        #expect(withoutProfile.paidByName == "Unknown")
    }

    @Test("Expense splitDescription for different split types")
    func splitDescription() {
        let full = Expense(tripId: UUID(), paidBy: UUID(), title: "A", amount: 10, splitType: .full)
        #expect(full.splitDescription == "Paid in full")

        let equalWith3 = Expense(
            tripId: UUID(), paidBy: UUID(), title: "B", amount: 30, splitType: .equal,
            splits: [
                ExpenseSplit(expenseId: UUID(), userId: UUID(), amount: 10),
                ExpenseSplit(expenseId: UUID(), userId: UUID(), amount: 10),
                ExpenseSplit(expenseId: UUID(), userId: UUID(), amount: 10),
            ]
        )
        #expect(equalWith3.splitDescription == "Split 3 ways")

        let noSplits = Expense(tripId: UUID(), paidBy: UUID(), title: "C", amount: 10, splitType: .equal)
        #expect(noSplits.splitDescription == "Not split")
    }

    // MARK: - ExpenseSplit

    @Test("ExpenseSplit displayName uses profile or Unknown")
    func splitDisplayName() {
        let withProfile = ExpenseSplit(
            expenseId: UUID(), userId: UUID(), amount: 15,
            profile: Profile(id: UUID(), email: "b@c.com", fullName: "Bob", createdAt: nil)
        )
        #expect(withProfile.displayName == "Bob")

        let without = ExpenseSplit(expenseId: UUID(), userId: UUID(), amount: 15)
        #expect(without.displayName == "Unknown")
    }

    // MARK: - MemberBalance

    @Test("MemberBalance netBalance computes correctly")
    func netBalance() {
        let positive = MemberBalance(userId: UUID(), name: "A", avatarUrl: nil, totalPaid: 100, totalOwed: 30)
        #expect(positive.netBalance == 70)
        #expect(!positive.isSettled)

        let negative = MemberBalance(userId: UUID(), name: "B", avatarUrl: nil, totalPaid: 20, totalOwed: 80)
        #expect(negative.netBalance == -60)
        #expect(!negative.isSettled)

        let settled = MemberBalance(userId: UUID(), name: "C", avatarUrl: nil, totalPaid: 50, totalOwed: 50)
        #expect(settled.netBalance == 0)
        #expect(settled.isSettled)
    }

    @Test("MemberBalance formattedBalance shows +/- correctly")
    func formattedBalance() {
        let positive = MemberBalance(userId: UUID(), name: "A", avatarUrl: nil, totalPaid: 100, totalOwed: 30)
        #expect(positive.formattedBalance.hasPrefix("+"))

        let negative = MemberBalance(userId: UUID(), name: "B", avatarUrl: nil, totalPaid: 20, totalOwed: 80)
        #expect(negative.formattedBalance.hasPrefix("-"))
    }

    // MARK: - Payloads

    @Test("CreateExpensePayload encodes required fields")
    func createPayloadEncodes() throws {
        let payload = CreateExpensePayload(
            tripId: UUID(), paidBy: UUID(), title: "Test Expense",
            description: nil, amount: 50.0, currency: "USD",
            category: .food, date: nil, splitType: .equal
        )
        let encoder = JSONEncoder()
        let data = try encoder.encode(payload)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["title"] as? String == "Test Expense")
        #expect(json?["amount"] as? Double == 50.0)
        #expect(json?["split_type"] as? String == "equal")
        #expect(json?["trip_id"] != nil)
        #expect(json?["paid_by"] != nil)
    }

    @Test("CreateSplitPayload encodes correctly")
    func splitPayloadEncodes() throws {
        let payload = CreateSplitPayload(expenseId: UUID(), userId: UUID(), amount: 25.0)
        let encoder = JSONEncoder()
        let data = try encoder.encode(payload)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["expense_id"] != nil)
        #expect(json?["user_id"] != nil)
        #expect(json?["amount"] as? Double == 25.0)
    }
}
