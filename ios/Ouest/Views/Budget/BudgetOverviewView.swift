import SwiftUI

struct BudgetOverviewView: View {
    let trip: Trip

    @EnvironmentObject var demoModeManager: DemoModeManager

    @State private var expenses: [Expense] = []
    @State private var members: [TripMember] = []
    @State private var isLoading = true
    @State private var showAddExpense = false

    var body: some View {
        ZStack {
            OuestTheme.Colors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: OuestTheme.Spacing.lg) {
                    // Budget Summary Card
                    budgetSummaryCard

                    // Expenses Section
                    expensesSectionView
                }
                .padding(.horizontal, OuestTheme.Spacing.md)
                .padding(.bottom, 100)
            }

            // FAB
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    OuestFAB(icon: "plus") {
                        showAddExpense = true
                    }
                    .padding(.trailing, OuestTheme.Spacing.md)
                    .padding(.bottom, OuestTheme.Spacing.md)
                }
            }
        }
        .navigationTitle(trip.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: ChatView(trip: trip)) {
                    Image(systemName: "bubble.left.fill")
                        .foregroundColor(OuestTheme.Colors.primary)
                }
            }
        }
        .sheet(isPresented: $showAddExpense) {
            AddExpenseSheet(trip: trip)
        }
        .onAppear {
            loadData()
        }
    }

    // MARK: - Budget Summary

    private var budgetSummaryCard: some View {
        OuestGradientCard {
            VStack(spacing: OuestTheme.Spacing.md) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Budget")
                            .font(OuestTheme.Fonts.caption)
                            .foregroundColor(.white.opacity(0.8))

                        if let budget = trip.budget {
                            Text(CurrencyFormatter.format(amount: budget, currency: trip.currency))
                                .font(OuestTheme.Fonts.title)
                                .foregroundColor(.white)
                        } else {
                            Text("Not set")
                                .font(OuestTheme.Fonts.title2)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }

                    Spacer()

                    Text(trip.destinationEmoji)
                        .font(.system(size: 40))
                }

                Divider()
                    .background(Color.white.opacity(0.3))

                // Spent / Remaining
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Spent")
                            .font(OuestTheme.Fonts.caption)
                            .foregroundColor(.white.opacity(0.8))

                        Text(CurrencyFormatter.format(amount: totalSpent, currency: trip.currency))
                            .font(OuestTheme.Fonts.headline)
                            .foregroundColor(.white)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Remaining")
                            .font(OuestTheme.Fonts.caption)
                            .foregroundColor(.white.opacity(0.8))

                        Text(CurrencyFormatter.format(amount: remaining, currency: trip.currency))
                            .font(OuestTheme.Fonts.headline)
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }

    // MARK: - Expenses Section

    private var expensesSectionView: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.sm) {
            Text("Expenses")
                .font(OuestTheme.Fonts.headline)
                .foregroundColor(OuestTheme.Colors.text)

            if isLoading {
                loadingView
            } else if expenses.isEmpty {
                emptyStateView
            } else {
                expensesListView
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: OuestTheme.Spacing.sm) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: OuestTheme.CornerRadius.medium)
                    .fill(OuestTheme.Colors.inputBackground)
                    .frame(height: 72)
                    .shimmer()
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: OuestTheme.Spacing.sm) {
            Image(systemName: "receipt")
                .font(.system(size: 40))
                .foregroundColor(OuestTheme.Colors.textTertiary)

            Text("No expenses yet")
                .font(OuestTheme.Fonts.body)
                .foregroundColor(OuestTheme.Colors.textSecondary)

            Text("Tap + to add your first expense")
                .font(OuestTheme.Fonts.caption)
                .foregroundColor(OuestTheme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, OuestTheme.Spacing.xl)
    }

    private var expensesListView: some View {
        LazyVStack(spacing: OuestTheme.Spacing.sm) {
            ForEach(expenses) { expense in
                ExpenseRow(expense: expense)
            }
        }
    }

    // MARK: - Computed Properties

    private var totalSpent: Decimal {
        expenses.reduce(0) { $0 + $1.amount }
    }

    private var remaining: Decimal {
        (trip.budget ?? 0) - totalSpent
    }

    // MARK: - Data Loading

    private func loadData() {
        if demoModeManager.isDemoMode {
            expenses = DemoModeManager.demoExpenses.filter { $0.tripId == trip.id }
            isLoading = false
            return
        }

        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            expenses = []
            isLoading = false
        }
    }
}

// MARK: - Expense Row

struct ExpenseRow: View {
    let expense: Expense

    var body: some View {
        HStack(spacing: OuestTheme.Spacing.sm) {
            // Category Icon
            ZStack {
                Circle()
                    .fill(expense.category.color.opacity(0.15))
                    .frame(width: 44, height: 44)

                Text(expense.category.emoji)
                    .font(.system(size: 20))
            }

            // Details
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.title)
                    .font(OuestTheme.Fonts.body)
                    .foregroundColor(OuestTheme.Colors.text)

                Text(expense.category.displayName)
                    .font(OuestTheme.Fonts.caption)
                    .foregroundColor(OuestTheme.Colors.textSecondary)
            }

            Spacer()

            // Amount
            Text(expense.formattedAmount)
                .font(OuestTheme.Fonts.headline)
                .foregroundColor(OuestTheme.Colors.text)
        }
        .padding(OuestTheme.Spacing.sm)
        .background(OuestTheme.Colors.cardBackground)
        .cornerRadius(OuestTheme.CornerRadius.medium)
    }
}

// MARK: - Add Expense Sheet

struct AddExpenseSheet: View {
    let trip: Trip
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Text("Add Expense - Coming Soon")
                .navigationTitle("Add Expense")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
        }
    }
}

#Preview {
    NavigationStack {
        BudgetOverviewView(trip: DemoModeManager.demoTrips[0])
            .environmentObject(AuthManager())
            .environmentObject(DemoModeManager())
            .environmentObject(ThemeManager())
    }
}
