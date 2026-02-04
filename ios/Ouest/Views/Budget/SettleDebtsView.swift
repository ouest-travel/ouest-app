import SwiftUI

// MARK: - Settle Debts View

struct SettleDebtsView: View {
    @Environment(\.dismiss) var dismiss

    let debts: [Debt]
    let trip: Trip
    let onSettle: (Debt) async -> Void

    @State private var selectedDebt: Debt?
    @State private var showConfirmation = false
    @State private var isSettling = false

    var body: some View {
        NavigationStack {
            ZStack {
                OuestTheme.Colors.background
                    .ignoresSafeArea()

                if debts.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        VStack(spacing: OuestTheme.Spacing.lg) {
                            // Summary Card
                            summaryCard

                            // Debts List
                            debtsListSection
                        }
                        .padding(OuestTheme.Spacing.md)
                    }
                }
            }
            .navigationTitle("Settle Up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Settle Debt",
                isPresented: $showConfirmation,
                titleVisibility: .visible
            ) {
                Button("Mark as Settled") {
                    if let debt = selectedDebt {
                        Task {
                            isSettling = true
                            await onSettle(debt)
                            isSettling = false
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                if let debt = selectedDebt {
                    Text("\(debt.fromProfile?.displayNameOrEmail ?? "Someone") will pay \(CurrencyFormatter.format(amount: debt.amount, currency: debt.currency)) to \(debt.toProfile?.displayNameOrEmail ?? "someone")")
                }
            }
        }
    }

    // MARK: - Subviews

    private var emptyStateView: some View {
        VStack(spacing: OuestTheme.Spacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(OuestTheme.Colors.success)

            Text("All Settled!")
                .font(OuestTheme.Fonts.title2)
                .foregroundColor(OuestTheme.Colors.text)

            Text("Everyone is even. No debts to settle.")
                .font(OuestTheme.Fonts.body)
                .foregroundColor(OuestTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(OuestTheme.Spacing.xl)
    }

    private var summaryCard: some View {
        OuestGradientCard {
            VStack(spacing: OuestTheme.Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total to Settle")
                            .font(OuestTheme.Fonts.caption)
                            .foregroundColor(.white.opacity(0.8))

                        Text(CurrencyFormatter.format(amount: totalDebt, currency: trip.currency))
                            .font(OuestTheme.Fonts.title)
                            .foregroundColor(.white)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Transactions")
                            .font(OuestTheme.Fonts.caption)
                            .foregroundColor(.white.opacity(0.8))

                        Text("\(debts.count)")
                            .font(OuestTheme.Fonts.title2)
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }

    private var debtsListSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.sm) {
            Text("Payments Needed")
                .font(OuestTheme.Fonts.headline)
                .foregroundColor(OuestTheme.Colors.text)

            ForEach(debts) { debt in
                DebtSettleRow(debt: debt) {
                    selectedDebt = debt
                    showConfirmation = true
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var totalDebt: Decimal {
        debts.reduce(0) { $0 + $1.amount }
    }
}

// MARK: - Debt Settle Row

struct DebtSettleRow: View {
    let debt: Debt
    let onSettle: () -> Void

    var body: some View {
        HStack(spacing: OuestTheme.Spacing.sm) {
            // From avatar
            VStack(spacing: 4) {
                OuestAvatar(debt.fromProfile, size: .medium)
                Text(debt.fromProfile?.displayNameOrEmail ?? "Unknown")
                    .font(OuestTheme.Fonts.caption)
                    .foregroundColor(OuestTheme.Colors.textSecondary)
                    .lineLimit(1)
            }
            .frame(width: 70)

            // Arrow with amount
            VStack(spacing: 4) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(OuestTheme.Colors.primary)

                Text(CurrencyFormatter.format(amount: debt.amount, currency: debt.currency))
                    .font(OuestTheme.Fonts.headline)
                    .foregroundColor(OuestTheme.Colors.text)
            }
            .frame(maxWidth: .infinity)

            // To avatar
            VStack(spacing: 4) {
                OuestAvatar(debt.toProfile, size: .medium)
                Text(debt.toProfile?.displayNameOrEmail ?? "Unknown")
                    .font(OuestTheme.Fonts.caption)
                    .foregroundColor(OuestTheme.Colors.textSecondary)
                    .lineLimit(1)
            }
            .frame(width: 70)

            // Settle button
            Button(action: onSettle) {
                Text("Settle")
                    .font(OuestTheme.Fonts.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, OuestTheme.Spacing.md)
                    .padding(.vertical, OuestTheme.Spacing.sm)
                    .background(OuestTheme.Gradients.primary)
                    .cornerRadius(OuestTheme.CornerRadius.pill)
            }
        }
        .padding(OuestTheme.Spacing.md)
        .background(OuestTheme.Colors.cardBackground)
        .cornerRadius(OuestTheme.CornerRadius.medium)
    }
}

// MARK: - Expense Detail View

struct ExpenseDetailView: View {
    @Environment(\.dismiss) var dismiss

    let expense: Expense
    let members: [TripMember]
    let onDelete: () async -> Void

    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                OuestTheme.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: OuestTheme.Spacing.lg) {
                        // Header
                        headerCard

                        // Details
                        detailsSection

                        // Split details
                        splitSection

                        // Delete button
                        deleteButton
                    }
                    .padding(OuestTheme.Spacing.md)
                }
            }
            .navigationTitle("Expense Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .confirmationDialog(
                "Delete Expense",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    Task {
                        await onDelete()
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this expense? This action cannot be undone.")
            }
        }
    }

    private var headerCard: some View {
        OuestCard {
            VStack(spacing: OuestTheme.Spacing.md) {
                // Category icon
                ZStack {
                    Circle()
                        .fill(expense.category.color.opacity(0.15))
                        .frame(width: 64, height: 64)

                    Text(expense.category.emoji)
                        .font(.system(size: 32))
                }

                // Title
                Text(expense.title)
                    .font(OuestTheme.Fonts.title2)
                    .foregroundColor(OuestTheme.Colors.text)

                // Amount
                Text(expense.formattedAmount)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(OuestTheme.Colors.text)

                // Category
                Text(expense.category.displayName)
                    .font(OuestTheme.Fonts.subheadline)
                    .foregroundColor(OuestTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var detailsSection: some View {
        OuestCard {
            VStack(spacing: OuestTheme.Spacing.md) {
                DetailRow(label: "Date", value: expense.date.formatted(date: .abbreviated, time: .omitted))
                DetailRow(label: "Category", value: expense.category.displayName)
                DetailRow(label: "Paid by", value: paidByName)
            }
        }
    }

    private var splitSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.sm) {
            Text("Split Among (\(expense.splitAmong.count) people)")
                .font(OuestTheme.Fonts.headline)
                .foregroundColor(OuestTheme.Colors.text)

            let splitAmount = expense.amount / Decimal(expense.splitAmong.count)

            OuestCard {
                VStack(spacing: OuestTheme.Spacing.sm) {
                    ForEach(expense.splitAmong, id: \.self) { userId in
                        let member = members.first(where: { $0.userId == userId })
                        HStack {
                            OuestAvatar(member?.profile, size: .small)

                            Text(member?.profile?.displayNameOrEmail ?? userId)
                                .font(OuestTheme.Fonts.body)
                                .foregroundColor(OuestTheme.Colors.text)

                            Spacer()

                            Text(CurrencyFormatter.format(amount: splitAmount, currency: expense.currency))
                                .font(OuestTheme.Fonts.headline)
                                .foregroundColor(OuestTheme.Colors.text)
                        }
                    }
                }
            }
        }
    }

    private var deleteButton: some View {
        Button {
            showDeleteConfirm = true
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("Delete Expense")
            }
            .font(OuestTheme.Fonts.body)
            .foregroundColor(OuestTheme.Colors.error)
            .frame(maxWidth: .infinity)
            .padding(OuestTheme.Spacing.md)
            .background(OuestTheme.Colors.error.opacity(0.1))
            .cornerRadius(OuestTheme.CornerRadius.medium)
        }
    }

    private var paidByName: String {
        members.first(where: { $0.userId == expense.paidBy })?.profile?.displayNameOrEmail ?? expense.paidBy
    }
}

// MARK: - Detail Row

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(OuestTheme.Fonts.body)
                .foregroundColor(OuestTheme.Colors.textSecondary)

            Spacer()

            Text(value)
                .font(OuestTheme.Fonts.body)
                .foregroundColor(OuestTheme.Colors.text)
        }
    }
}

// MARK: - Preview

#Preview("Settle Debts") {
    let debts = [
        Debt(
            fromUserId: "demo-user-1",
            toUserId: "demo-user-2",
            amount: 125.50,
            currency: "CAD",
            fromProfile: DemoModeManager.demoMembers[0],
            toProfile: DemoModeManager.demoMembers[1]
        ),
        Debt(
            fromUserId: "demo-user-3",
            toUserId: "demo-user-1",
            amount: 45.00,
            currency: "CAD",
            fromProfile: DemoModeManager.demoMembers[2],
            toProfile: DemoModeManager.demoMembers[0]
        )
    ]

    SettleDebtsView(
        debts: debts,
        trip: DemoModeManager.demoTrips[0]
    ) { _ in }
}

#Preview("Expense Detail") {
    ExpenseDetailView(
        expense: DemoModeManager.demoExpenses[0],
        members: [
            TripMember(id: "1", tripId: "demo-trip-1", userId: "demo-user-1", role: .owner, createdAt: Date(), profile: DemoModeManager.demoMembers[0]),
            TripMember(id: "2", tripId: "demo-trip-1", userId: "demo-user-2", role: .member, createdAt: Date(), profile: DemoModeManager.demoMembers[1])
        ]
    ) { }
}
