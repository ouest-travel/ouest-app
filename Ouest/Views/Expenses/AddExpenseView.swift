import SwiftUI

struct AddExpenseView: View {
    @Bindable var viewModel: ExpensesViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var contentAppeared = false

    private var isEditing: Bool { viewModel.editingExpense != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: OuestTheme.Spacing.xl) {
                    // Details section
                    detailsSection
                        .fadeSlideIn(isVisible: contentAppeared, delay: 0)

                    // Category section
                    categorySection
                        .fadeSlideIn(isVisible: contentAppeared, delay: 0.1)

                    // Date section
                    dateSection
                        .fadeSlideIn(isVisible: contentAppeared, delay: 0.15)

                    // Split section
                    splitSection
                        .fadeSlideIn(isVisible: contentAppeared, delay: 0.2)

                    // Member selection
                    if viewModel.splitType != .full {
                        memberSection
                            .fadeSlideIn(isVisible: contentAppeared, delay: 0.25)
                    }

                    // Custom split amounts
                    if viewModel.splitType == .custom && !viewModel.selectedMembers.isEmpty {
                        customSplitSection
                            .fadeSlideIn(isVisible: contentAppeared, delay: 0.3)
                    }
                }
                .padding(.horizontal, OuestTheme.Spacing.lg)
                .padding(.vertical, OuestTheme.Spacing.md)
            }
            .navigationTitle(isEditing ? "Edit Expense" : "Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Update" : "Add") {
                        Task {
                            if await viewModel.saveExpense() {
                                dismiss()
                            }
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(!viewModel.isFormValid || viewModel.isSaving)
                }
            }
            .onAppear {
                withAnimation(OuestTheme.Anim.smooth) {
                    contentAppeared = true
                }
            }
        }
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.md) {
            Text("Details")
                .font(OuestTheme.Typography.sectionTitle)

            VStack(spacing: OuestTheme.Spacing.md) {
                // Title
                TextField("What was this expense for?", text: $viewModel.expenseTitle)
                    .font(.body)
                    .padding(OuestTheme.Spacing.md)
                    .background(OuestTheme.Colors.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))

                // Amount
                HStack {
                    Text(currencySymbol)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(OuestTheme.Colors.textSecondary)

                    TextField("0.00", text: $viewModel.expenseAmountText)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .keyboardType(.decimalPad)
                }
                .padding(OuestTheme.Spacing.md)
                .background(OuestTheme.Colors.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))

                // Description (optional)
                TextField("Description (optional)", text: $viewModel.expenseDescription, axis: .vertical)
                    .font(.body)
                    .lineLimit(3...6)
                    .padding(OuestTheme.Spacing.md)
                    .background(OuestTheme.Colors.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
            }
        }
    }

    // MARK: - Category Section

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.md) {
            Text("Category")
                .font(OuestTheme.Typography.sectionTitle)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: OuestTheme.Spacing.sm), count: 4), spacing: OuestTheme.Spacing.sm) {
                ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                    Button {
                        HapticFeedback.selection()
                        viewModel.expenseCategory = cat
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: cat.icon)
                                .font(.body)
                            Text(cat.label)
                                .font(OuestTheme.Typography.micro)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, OuestTheme.Spacing.sm)
                        .background(
                            viewModel.expenseCategory == cat
                                ? cat.color.opacity(0.15)
                                : OuestTheme.Colors.surfaceSecondary
                        )
                        .foregroundStyle(
                            viewModel.expenseCategory == cat
                                ? cat.color
                                : OuestTheme.Colors.textSecondary
                        )
                        .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: OuestTheme.Radius.sm)
                                .stroke(viewModel.expenseCategory == cat ? cat.color : .clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Date Section

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.md) {
            Text("Date")
                .font(OuestTheme.Typography.sectionTitle)

            DatePicker("", selection: $viewModel.expenseDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .padding(OuestTheme.Spacing.md)
                .background(OuestTheme.Colors.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
        }
    }

    // MARK: - Split Section

    private var splitSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.md) {
            Text("Split Type")
                .font(OuestTheme.Typography.sectionTitle)

            HStack(spacing: OuestTheme.Spacing.sm) {
                ForEach(SplitType.allCases, id: \.self) { type in
                    Button {
                        HapticFeedback.selection()
                        viewModel.splitType = type
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: type.icon)
                                .font(.body)
                            Text(type.label)
                                .font(OuestTheme.Typography.micro)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, OuestTheme.Spacing.md)
                        .background(
                            viewModel.splitType == type
                                ? OuestTheme.Colors.brand.opacity(0.15)
                                : OuestTheme.Colors.surfaceSecondary
                        )
                        .foregroundStyle(
                            viewModel.splitType == type
                                ? OuestTheme.Colors.brand
                                : OuestTheme.Colors.textSecondary
                        )
                        .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: OuestTheme.Radius.md)
                                .stroke(viewModel.splitType == type ? OuestTheme.Colors.brand : .clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Member Section

    private var memberSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.md) {
            HStack {
                Text("Split Between")
                    .font(OuestTheme.Typography.sectionTitle)
                Spacer()
                Text("\(viewModel.selectedMembers.count) selected")
                    .font(OuestTheme.Typography.caption)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
            }

            VStack(spacing: OuestTheme.Spacing.sm) {
                ForEach(viewModel.members) { member in
                    let isSelected = viewModel.selectedMembers.contains(member.userId)

                    Button {
                        HapticFeedback.selection()
                        if isSelected {
                            viewModel.selectedMembers.remove(member.userId)
                        } else {
                            viewModel.selectedMembers.insert(member.userId)
                        }
                    } label: {
                        HStack(spacing: OuestTheme.Spacing.md) {
                            AvatarView(url: member.profile?.avatarUrl, size: 36)

                            Text(member.profile?.fullName ?? "Unknown")
                                .font(.body)
                                .foregroundStyle(OuestTheme.Colors.textPrimary)

                            if member.role == .owner {
                                Image(systemName: "crown.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }

                            Spacer()

                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(isSelected ? OuestTheme.Colors.brand : OuestTheme.Colors.textSecondary)
                        }
                        .padding(OuestTheme.Spacing.md)
                        .background(
                            isSelected
                                ? OuestTheme.Colors.brand.opacity(0.06)
                                : OuestTheme.Colors.surfaceSecondary
                        )
                        .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Custom Split Section

    private var customSplitSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.md) {
            HStack {
                Text("Custom Amounts")
                    .font(OuestTheme.Typography.sectionTitle)
                Spacer()
                let total = viewModel.selectedMembers.reduce(0.0) { sum, uid in
                    sum + (Double(viewModel.customSplits[uid] ?? "0") ?? 0)
                }
                let expenseAmount = Double(viewModel.expenseAmountText) ?? 0
                let remaining = expenseAmount - total
                Text(remaining > 0.01 ? "\(formatAmount(remaining)) remaining" : "Balanced")
                    .font(OuestTheme.Typography.caption)
                    .foregroundStyle(remaining > 0.01 ? OuestTheme.Colors.warning : OuestTheme.Colors.success)
            }

            VStack(spacing: OuestTheme.Spacing.sm) {
                ForEach(viewModel.members.filter({ viewModel.selectedMembers.contains($0.userId) })) { member in
                    HStack(spacing: OuestTheme.Spacing.md) {
                        AvatarView(url: member.profile?.avatarUrl, size: 32)

                        Text(member.profile?.fullName?.components(separatedBy: " ").first ?? "?")
                            .font(.body)
                            .frame(width: 60, alignment: .leading)

                        HStack {
                            Text(currencySymbol)
                                .font(.body)
                                .foregroundStyle(OuestTheme.Colors.textSecondary)

                            TextField("0.00", text: Binding(
                                get: { viewModel.customSplits[member.userId] ?? "" },
                                set: { viewModel.customSplits[member.userId] = $0 }
                            ))
                            .keyboardType(.decimalPad)
                            .font(.body)
                        }
                        .padding(OuestTheme.Spacing.sm)
                        .background(OuestTheme.Colors.surfaceSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.sm))
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var currencySymbol: String {
        let code = viewModel.trip.currency ?? "USD"
        let locale = Locale.availableIdentifiers
            .map { Locale(identifier: $0) }
            .first { $0.currency?.identifier == code }
        return locale?.currencySymbol ?? "$"
    }

    private func formatAmount(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = viewModel.trip.currency ?? "USD"
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }
}

#Preview {
    AddExpenseView(viewModel: ExpensesViewModel(trip: Trip(
        id: UUID(), createdBy: UUID(),
        title: "Test Trip", destination: "Barcelona",
        status: .planning, isPublic: false,
        createdAt: Date(), updatedAt: Date()
    )))
}
