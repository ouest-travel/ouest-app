import Testing
import Foundation
@testable import Ouest

@Suite("ExpensesViewModel")
struct ExpensesViewModelTests {

    private func makeTrip(budget: Double? = nil, currency: String? = nil) -> Trip {
        Trip(
            id: UUID(),
            createdBy: UUID(),
            title: "Test Trip",
            destination: "Barcelona, Spain",
            startDate: Date(),
            endDate: Date().addingTimeInterval(7 * 86400),
            status: .planning,
            isPublic: false,
            budget: budget,
            currency: currency,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    private func makeMember(userId: UUID, name: String = "Test User") -> TripMember {
        // We can't easily create TripMember without decoder, so we'll test ViewModel logic
        // that doesn't depend on members directly
        fatalError("Use ViewModel methods that don't require TripMember creation")
    }

    @Test("Initial state is empty and not loading")
    @MainActor
    func initialState() {
        let vm = ExpensesViewModel(trip: makeTrip())
        #expect(vm.expenses.isEmpty)
        #expect(vm.members.isEmpty)
        #expect(vm.isLoading == false)
        #expect(vm.isSaving == false)
        #expect(vm.errorMessage == nil)
        #expect(vm.editingExpense == nil)
        #expect(vm.showAddExpense == false)
        #expect(vm.showBalanceSummary == false)
    }

    @Test("resetForm clears all form fields")
    @MainActor
    func resetForm() {
        let vm = ExpensesViewModel(trip: makeTrip())
        // Set some values
        vm.expenseTitle = "Test"
        vm.expenseDescription = "Desc"
        vm.expenseAmountText = "50"
        vm.expenseCategory = .food
        vm.splitType = .custom
        vm.selectedMembers = [UUID(), UUID()]
        vm.customSplits = [UUID(): "25"]
        vm.editingExpense = Expense(tripId: UUID(), paidBy: UUID(), title: "Edit", amount: 10)

        vm.resetForm()

        #expect(vm.expenseTitle == "")
        #expect(vm.expenseDescription == "")
        #expect(vm.expenseAmountText == "")
        #expect(vm.expenseCategory == .other)
        #expect(vm.splitType == .equal)
        #expect(vm.selectedMembers.isEmpty)
        #expect(vm.customSplits.isEmpty)
        #expect(vm.editingExpense == nil)
    }

    @Test("isFormValid requires non-empty title and valid amount")
    @MainActor
    func formValidation() {
        let vm = ExpensesViewModel(trip: makeTrip())
        vm.selectedMembers = [UUID()]

        #expect(vm.isFormValid == false) // empty title, empty amount

        vm.expenseTitle = "Dinner"
        #expect(vm.isFormValid == false) // no amount

        vm.expenseAmountText = "0"
        #expect(vm.isFormValid == false) // zero amount

        vm.expenseAmountText = "-5"
        #expect(vm.isFormValid == false) // negative amount

        vm.expenseAmountText = "25.50"
        #expect(vm.isFormValid == true) // valid

        vm.expenseTitle = "   "
        #expect(vm.isFormValid == false) // whitespace-only title
    }

    @Test("isFormValid requires selected members for non-full splits")
    @MainActor
    func formValidationMembers() {
        let vm = ExpensesViewModel(trip: makeTrip())
        vm.expenseTitle = "Dinner"
        vm.expenseAmountText = "25"

        // Equal split with no members selected
        vm.splitType = .equal
        vm.selectedMembers = []
        #expect(vm.isFormValid == false)

        vm.selectedMembers = [UUID()]
        #expect(vm.isFormValid == true)

        // Full split doesn't need members
        vm.splitType = .full
        vm.selectedMembers = []
        #expect(vm.isFormValid == true)
    }

    @Test("totalSpent sums all expense amounts")
    @MainActor
    func totalSpent() {
        let vm = ExpensesViewModel(trip: makeTrip())
        let tripId = UUID()
        let userId = UUID()
        vm.expenses = [
            Expense(tripId: tripId, paidBy: userId, title: "A", amount: 25),
            Expense(tripId: tripId, paidBy: userId, title: "B", amount: 30.50),
            Expense(tripId: tripId, paidBy: userId, title: "C", amount: 44.50),
        ]
        #expect(vm.totalSpent == 100.0)
    }

    @Test("budgetRemaining returns nil when no budget")
    @MainActor
    func budgetRemainingNoBudget() {
        let vm = ExpensesViewModel(trip: makeTrip())
        #expect(vm.budgetRemaining == nil)
        #expect(vm.budgetProgress == nil)
    }

    @Test("budgetRemaining computes correctly with budget")
    @MainActor
    func budgetRemainingWithBudget() {
        let vm = ExpensesViewModel(trip: makeTrip(budget: 1000, currency: "USD"))
        let tripId = UUID()
        let userId = UUID()
        vm.expenses = [
            Expense(tripId: tripId, paidBy: userId, title: "A", amount: 300),
            Expense(tripId: tripId, paidBy: userId, title: "B", amount: 200),
        ]
        #expect(vm.budgetRemaining == 500.0)
        #expect(vm.budgetProgress! == 0.5)
    }

    @Test("budgetProgress exceeds 1 when over budget")
    @MainActor
    func budgetOverspent() {
        let vm = ExpensesViewModel(trip: makeTrip(budget: 100))
        vm.expenses = [
            Expense(tripId: UUID(), paidBy: UUID(), title: "A", amount: 150),
        ]
        #expect(vm.budgetRemaining! == -50.0)
        #expect(vm.budgetProgress! == 1.5)
    }

    @Test("memberBalances computes net balance from expenses and splits")
    @MainActor
    func memberBalances() {
        let vm = ExpensesViewModel(trip: makeTrip())
        let tripId = UUID()
        let alice = UUID()
        let bob = UUID()

        // Alice paid $100, split equally between Alice and Bob ($50 each)
        vm.expenses = [
            Expense(
                tripId: tripId, paidBy: alice, title: "Dinner", amount: 100,
                splitType: .equal,
                splits: [
                    ExpenseSplit(expenseId: UUID(), userId: alice, amount: 50),
                    ExpenseSplit(expenseId: UUID(), userId: bob, amount: 50),
                ]
            ),
        ]

        // We need members for name resolution
        // Since we can't easily create TripMembers, the balances will show "Unknown"
        let balances = vm.memberBalances
        #expect(balances.count == 2)

        // Alice: paid 100, owes 50, net = +50
        let aliceBalance = balances.first(where: { $0.userId == alice })
        #expect(aliceBalance?.totalPaid == 100)
        #expect(aliceBalance?.totalOwed == 50)
        #expect(aliceBalance?.netBalance == 50)

        // Bob: paid 0, owes 50, net = -50
        let bobBalance = balances.first(where: { $0.userId == bob })
        #expect(bobBalance?.totalPaid == 0)
        #expect(bobBalance?.totalOwed == 50)
        #expect(bobBalance?.netBalance == -50)
    }

    @Test("settlements minimizes payments correctly")
    @MainActor
    func settlements() {
        let vm = ExpensesViewModel(trip: makeTrip())
        let tripId = UUID()
        let alice = UUID()
        let bob = UUID()
        let charlie = UUID()

        // Alice paid $120, split equally 3 ways ($40 each)
        // Bob paid $60, split equally 3 ways ($20 each)
        vm.expenses = [
            Expense(
                tripId: tripId, paidBy: alice, title: "Dinner", amount: 120,
                splitType: .equal,
                splits: [
                    ExpenseSplit(expenseId: UUID(), userId: alice, amount: 40),
                    ExpenseSplit(expenseId: UUID(), userId: bob, amount: 40),
                    ExpenseSplit(expenseId: UUID(), userId: charlie, amount: 40),
                ]
            ),
            Expense(
                tripId: tripId, paidBy: bob, title: "Taxi", amount: 60,
                splitType: .equal,
                splits: [
                    ExpenseSplit(expenseId: UUID(), userId: alice, amount: 20),
                    ExpenseSplit(expenseId: UUID(), userId: bob, amount: 20),
                    ExpenseSplit(expenseId: UUID(), userId: charlie, amount: 20),
                ]
            ),
        ]

        // Alice: paid 120, owes 60 (40+20), net = +60
        // Bob: paid 60, owes 60 (40+20), net = 0
        // Charlie: paid 0, owes 60 (40+20), net = -60
        let balances = vm.memberBalances
        let aliceBalance = balances.first(where: { $0.userId == alice })
        let bobBalance = balances.first(where: { $0.userId == bob })
        let charlieBalance = balances.first(where: { $0.userId == charlie })

        #expect(aliceBalance?.netBalance == 60)
        #expect(bobBalance?.netBalance == 0)
        #expect(charlieBalance?.netBalance == -60)

        // Settlement: Charlie pays Alice $60
        let settlements = vm.settlements
        #expect(settlements.count == 1)
        #expect(settlements[0].amount == 60)
        #expect(settlements[0].from.userId == charlie)
        #expect(settlements[0].to.userId == alice)
    }

    @Test("populateFormFromExpense sets all form fields")
    @MainActor
    func populateForm() {
        let vm = ExpensesViewModel(trip: makeTrip())
        let userId1 = UUID()
        let userId2 = UUID()
        let expenseId = UUID()

        let expense = Expense(
            tripId: UUID(), paidBy: UUID(), title: "Hotel",
            description: "2 nights", amount: 250, currency: "EUR",
            category: .accommodation, date: Date(),
            splitType: .custom,
            splits: [
                ExpenseSplit(expenseId: expenseId, userId: userId1, amount: 150),
                ExpenseSplit(expenseId: expenseId, userId: userId2, amount: 100),
            ]
        )

        vm.populateFormFromExpense(expense)

        #expect(vm.expenseTitle == "Hotel")
        #expect(vm.expenseDescription == "2 nights")
        #expect(vm.expenseAmountText == "250.00")
        #expect(vm.expenseCategory == .accommodation)
        #expect(vm.splitType == .custom)
        #expect(vm.selectedMembers.count == 2)
        #expect(vm.selectedMembers.contains(userId1))
        #expect(vm.selectedMembers.contains(userId2))
        #expect(vm.editingExpense != nil)
    }
}
