import SwiftUI

struct ExpensesView: View {
    let trip: Trip
    @State private var viewModel: ExpensesViewModel
    @State private var contentAppeared = false

    init(trip: Trip) {
        self.trip = trip
        self._viewModel = State(initialValue: ExpensesViewModel(trip: trip))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                skeletonView
            } else if let error = viewModel.errorMessage {
                ErrorView(message: error) {
                    Task { await viewModel.loadExpenses() }
                }
            } else if viewModel.expenses.isEmpty {
                emptyStateView
            } else {
                expenseListView
            }
        }
        .navigationTitle("Expenses")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: OuestTheme.Spacing.md) {
                    // Balance summary button
                    if !viewModel.expenses.isEmpty {
                        Button {
                            HapticFeedback.light()
                            viewModel.showBalanceSummary = true
                        } label: {
                            Image(systemName: "chart.pie")
                                .foregroundStyle(OuestTheme.Colors.brand)
                        }
                    }

                    // Add expense button
                    Button {
                        HapticFeedback.light()
                        viewModel.resetForm()
                        viewModel.preselectAllMembers()
                        viewModel.showAddExpense = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                            .foregroundStyle(OuestTheme.Colors.brand)
                    }
                }
            }
        }
        .task {
            await viewModel.loadExpenses()
            withAnimation(OuestTheme.Anim.smooth) {
                contentAppeared = true
            }
        }
        .refreshable {
            contentAppeared = false
            await viewModel.loadExpenses()
            withAnimation(OuestTheme.Anim.smooth) {
                contentAppeared = true
            }
        }
        .sheet(isPresented: $viewModel.showAddExpense) {
            AddExpenseView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showBalanceSummary) {
            BalanceSummaryView(viewModel: viewModel)
        }
    }

    // MARK: - Expense List

    private var expenseListView: some View {
        ScrollView {
            LazyVStack(spacing: OuestTheme.Spacing.lg) {
                // Budget bar (if trip has budget)
                if let progress = viewModel.budgetProgress {
                    budgetBar(progress: progress)
                        .fadeSlideIn(isVisible: contentAppeared, delay: 0)
                }

                // Total spent summary
                totalSpentBar
                    .fadeSlideIn(isVisible: contentAppeared, delay: 0.05)

                // Expense cards
                ForEach(Array(viewModel.expenses.enumerated()), id: \.element.id) { index, expense in
                    ExpenseCardView(expense: expense, viewModel: viewModel)
                        .fadeSlideIn(isVisible: contentAppeared, delay: Double(index) * 0.06 + 0.1)
                        .contextMenu {
                            Button {
                                viewModel.populateFormFromExpense(expense)
                                viewModel.showAddExpense = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                Task { await viewModel.deleteExpense(expense) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .padding(.horizontal, OuestTheme.Spacing.lg)
            .padding(.top, OuestTheme.Spacing.sm)
            .padding(.bottom, OuestTheme.Spacing.xxxl)
        }
    }

    // MARK: - Budget Bar

    private func budgetBar(progress: Double) -> some View {
        VStack(spacing: OuestTheme.Spacing.sm) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(budgetColor(progress))
                Text("Budget")
                    .font(OuestTheme.Typography.caption)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
                Spacer()

                if let remaining = viewModel.budgetRemaining {
                    let formatter = NumberFormatter()
                    let _ = formatter.numberStyle = .currency
                    let _ = formatter.currencyCode = trip.currency ?? "USD"
                    Text("\(formatter.string(from: NSNumber(value: abs(remaining))) ?? "$0") \(remaining >= 0 ? "left" : "over")")
                        .font(OuestTheme.Typography.cardTitle)
                        .foregroundStyle(budgetColor(progress))
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(budgetColor(progress))
                        .frame(width: min(geo.size.width * progress, geo.size.width))
                }
            }
            .frame(height: 8)
        }
        .padding(OuestTheme.Spacing.md)
        .background(budgetColor(progress).opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
    }

    private func budgetColor(_ progress: Double) -> Color {
        if progress > 1.0 { return OuestTheme.Colors.error }
        if progress > 0.8 { return OuestTheme.Colors.warning }
        return OuestTheme.Colors.success
    }

    // MARK: - Total Spent Bar

    private var totalSpentBar: some View {
        HStack {
            Image(systemName: "creditcard.fill")
                .foregroundStyle(OuestTheme.Colors.brand)
            Text("Total Spent")
                .font(OuestTheme.Typography.caption)
                .foregroundStyle(OuestTheme.Colors.textSecondary)
            Spacer()
            Text(viewModel.formattedTotalSpent)
                .font(OuestTheme.Typography.cardTitle)
                .foregroundStyle(OuestTheme.Colors.textPrimary)
        }
        .padding(OuestTheme.Spacing.md)
        .background(OuestTheme.Colors.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: OuestTheme.Spacing.xxl) {
            Spacer()

            VStack(spacing: OuestTheme.Spacing.md) {
                Image(systemName: "creditcard")
                    .font(.system(size: 48))
                    .foregroundStyle(OuestTheme.Colors.brandGradient)
                    .bouncyAppear(isVisible: contentAppeared, delay: 0)

                Text("Track expenses")
                    .font(OuestTheme.Typography.screenTitle)
                    .fadeSlideIn(isVisible: contentAppeared, delay: 0.15)

                Text("Add shared expenses and split\ncosts with your travel group")
                    .font(.subheadline)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fadeSlideIn(isVisible: contentAppeared, delay: 0.25)
            }

            OuestButton(title: "Add First Expense") {
                viewModel.resetForm()
                viewModel.preselectAllMembers()
                viewModel.showAddExpense = true
            }
            .frame(width: 220)
            .fadeSlideIn(isVisible: contentAppeared, delay: 0.35)

            Spacer()
        }
        .padding(OuestTheme.Spacing.xxxl)
    }

    // MARK: - Skeleton Loading

    private var skeletonView: some View {
        ScrollView {
            VStack(spacing: OuestTheme.Spacing.lg) {
                // Budget bar skeleton
                SkeletonView(height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))

                // Expense card skeletons
                ForEach(0..<4, id: \.self) { _ in
                    HStack(spacing: OuestTheme.Spacing.md) {
                        SkeletonView(height: 40, radius: OuestTheme.Radius.md)
                            .frame(width: 40)
                        VStack(alignment: .leading, spacing: OuestTheme.Spacing.sm) {
                            SkeletonView(width: 140, height: 14)
                            SkeletonView(width: 80, height: 12)
                        }
                        Spacer()
                        SkeletonView(width: 60, height: 16)
                    }
                    .padding(OuestTheme.Spacing.md)
                    .background(OuestTheme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.lg))
                    .shadow(OuestTheme.Shadow.md)
                }
            }
            .padding(.horizontal, OuestTheme.Spacing.lg)
            .padding(.top, OuestTheme.Spacing.sm)
        }
    }
}

#Preview {
    NavigationStack {
        ExpensesView(trip: Trip(
            id: UUID(), createdBy: UUID(),
            title: "Summer in Barcelona", destination: "Barcelona, Spain",
            startDate: Date(), endDate: Date().addingTimeInterval(7 * 86400),
            status: .planning, isPublic: false, budget: 3000, currency: "EUR",
            createdAt: Date(), updatedAt: Date()
        ))
    }
}
