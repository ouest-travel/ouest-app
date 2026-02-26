import SwiftUI

struct ExpenseCardView: View {
    let expense: Expense
    let viewModel: ExpensesViewModel

    var body: some View {
        HStack(spacing: OuestTheme.Spacing.md) {
            // Category icon
            Image(systemName: expense.category.icon)
                .font(.title3)
                .frame(width: 40, height: 40)
                .background(expense.category.color.opacity(0.12))
                .foregroundStyle(expense.category.color)
                .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.sm))

            // Details
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.title)
                    .font(OuestTheme.Typography.cardTitle)
                    .lineLimit(1)

                HStack(spacing: OuestTheme.Spacing.xs) {
                    Text("Paid by \(expense.paidByName)")
                        .font(OuestTheme.Typography.caption)
                        .foregroundStyle(OuestTheme.Colors.textSecondary)

                    if let date = expense.formattedDate {
                        Text("·")
                            .font(OuestTheme.Typography.caption)
                            .foregroundStyle(OuestTheme.Colors.textSecondary)
                        Text(date)
                            .font(OuestTheme.Typography.caption)
                            .foregroundStyle(OuestTheme.Colors.textSecondary)
                    }
                }

                Text(expense.splitDescription)
                    .font(OuestTheme.Typography.micro)
                    .foregroundStyle(expense.category.color)
            }

            Spacer()

            // Amount
            Text(expense.formattedAmount)
                .font(OuestTheme.Typography.cardTitle)
                .fontWeight(.semibold)
                .foregroundStyle(OuestTheme.Colors.textPrimary)
        }
        .padding(OuestTheme.Spacing.md)
        .background(OuestTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.lg))
        .shadow(OuestTheme.Shadow.md)
    }
}

#Preview {
    VStack(spacing: 12) {
        ExpenseCardView(
            expense: Expense(
                tripId: UUID(), paidBy: UUID(),
                title: "Dinner at La Boqueria",
                amount: 85.50, currency: "EUR",
                category: .food, date: Date(),
                splitType: .equal,
                splits: [
                    ExpenseSplit(expenseId: UUID(), userId: UUID(), amount: 28.50),
                    ExpenseSplit(expenseId: UUID(), userId: UUID(), amount: 28.50),
                    ExpenseSplit(expenseId: UUID(), userId: UUID(), amount: 28.50),
                ],
                paidByProfile: Profile(id: UUID(), email: "test@test.com", fullName: "Alex", createdAt: nil)
            ),
            viewModel: ExpensesViewModel(trip: Trip(
                id: UUID(), createdBy: UUID(),
                title: "Test", destination: "Test",
                status: .planning, isPublic: false,
                createdAt: Date(), updatedAt: Date()
            ))
        )
    }
    .padding()
}
