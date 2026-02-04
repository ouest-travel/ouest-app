import SwiftUI

// MARK: - Add Expense View

struct AddExpenseView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    let trip: Trip
    let members: [TripMember]
    let onAdd: (CreateExpenseRequest) async -> Void

    @State private var title = ""
    @State private var amount: Decimal?
    @State private var category: ExpenseCategory = .other
    @State private var paidBy: String = ""
    @State private var splitType: SplitType = .equal
    @State private var selectedMembers: Set<String> = []
    @State private var customSplits: [String: Decimal] = [:]
    @State private var note = ""
    @State private var date = Date()
    @State private var isSaving = false
    @State private var showCategoryPicker = false

    init(trip: Trip, members: [TripMember], onAdd: @escaping (CreateExpenseRequest) async -> Void) {
        self.trip = trip
        self.members = members
        self.onAdd = onAdd

        // Initialize with all members selected
        let memberIds = Set(members.map { $0.userId })
        _selectedMembers = State(initialValue: memberIds)

        // Default payer is first member (or current user)
        _paidBy = State(initialValue: members.first?.userId ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                OuestTheme.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: OuestTheme.Spacing.lg) {
                        // Amount Input
                        amountSection

                        // Title Input
                        titleSection

                        // Category Picker
                        categorySection

                        // Date Picker
                        dateSection

                        // Paid By
                        paidBySection

                        // Split Among
                        splitSection

                        // Note (optional)
                        noteSection
                    }
                    .padding(OuestTheme.Spacing.md)
                }
            }
            .navigationTitle("Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task { await addExpense() }
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid || isSaving)
                }
            }
            .sheet(isPresented: $showCategoryPicker) {
                CategoryPickerSheet(selectedCategory: $category)
            }
        }
    }

    // MARK: - Computed Properties

    private var isValid: Bool {
        !title.isEmpty && amount != nil && amount! > 0 && !paidBy.isEmpty && !selectedMembers.isEmpty
    }

    private var splitAmount: Decimal {
        guard let amount = amount, !selectedMembers.isEmpty else { return 0 }
        return amount / Decimal(selectedMembers.count)
    }

    // MARK: - Sections

    private var amountSection: some View {
        VStack(spacing: OuestTheme.Spacing.sm) {
            Text(trip.currency)
                .font(OuestTheme.Fonts.caption)
                .foregroundColor(OuestTheme.Colors.textSecondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(CurrencyFormatter.symbol(for: trip.currency))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(OuestTheme.Colors.text)

                TextField("0.00", value: $amount, format: .number.precision(.fractionLength(2)))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(OuestTheme.Colors.text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .frame(minWidth: 100)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, OuestTheme.Spacing.lg)
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.xs) {
            Text("What's this for?")
                .font(OuestTheme.Fonts.subheadline)
                .foregroundColor(OuestTheme.Colors.textSecondary)

            TextField("e.g., Dinner at restaurant", text: $title)
                .font(OuestTheme.Fonts.body)
                .padding(OuestTheme.Spacing.md)
                .background(OuestTheme.Colors.cardBackground)
                .cornerRadius(OuestTheme.CornerRadius.medium)
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.xs) {
            Text("Category")
                .font(OuestTheme.Fonts.subheadline)
                .foregroundColor(OuestTheme.Colors.textSecondary)

            Button {
                showCategoryPicker = true
            } label: {
                HStack {
                    Text(category.emoji)
                        .font(.system(size: 24))

                    Text(category.displayName)
                        .font(OuestTheme.Fonts.body)
                        .foregroundColor(OuestTheme.Colors.text)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(OuestTheme.Colors.textTertiary)
                }
                .padding(OuestTheme.Spacing.md)
                .background(OuestTheme.Colors.cardBackground)
                .cornerRadius(OuestTheme.CornerRadius.medium)
            }
        }
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.xs) {
            Text("Date")
                .font(OuestTheme.Fonts.subheadline)
                .foregroundColor(OuestTheme.Colors.textSecondary)

            DatePicker("", selection: $date, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .padding(OuestTheme.Spacing.md)
                .background(OuestTheme.Colors.cardBackground)
                .cornerRadius(OuestTheme.CornerRadius.medium)
        }
    }

    private var paidBySection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.xs) {
            Text("Paid by")
                .font(OuestTheme.Fonts.subheadline)
                .foregroundColor(OuestTheme.Colors.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: OuestTheme.Spacing.sm) {
                    ForEach(members) { member in
                        MemberChip(
                            profile: member.profile,
                            isSelected: paidBy == member.userId
                        ) {
                            paidBy = member.userId
                        }
                    }
                }
            }
        }
    }

    private var splitSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.sm) {
            HStack {
                Text("Split among")
                    .font(OuestTheme.Fonts.subheadline)
                    .foregroundColor(OuestTheme.Colors.textSecondary)

                Spacer()

                if !selectedMembers.isEmpty && amount != nil {
                    Text("\(CurrencyFormatter.format(amount: splitAmount, currency: trip.currency)) each")
                        .font(OuestTheme.Fonts.caption)
                        .foregroundColor(OuestTheme.Colors.primary)
                }
            }

            // Split type picker
            Picker("Split Type", selection: $splitType) {
                ForEach(SplitType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)

            // Members selection
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: OuestTheme.Spacing.sm) {
                ForEach(members) { member in
                    SplitMemberRow(
                        member: member,
                        isSelected: selectedMembers.contains(member.userId),
                        splitType: splitType,
                        customAmount: customSplits[member.userId] ?? 0,
                        onToggle: {
                            if selectedMembers.contains(member.userId) {
                                selectedMembers.remove(member.userId)
                            } else {
                                selectedMembers.insert(member.userId)
                            }
                        },
                        onAmountChange: { newAmount in
                            customSplits[member.userId] = newAmount
                        }
                    )
                }
            }
        }
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.xs) {
            Text("Note (optional)")
                .font(OuestTheme.Fonts.subheadline)
                .foregroundColor(OuestTheme.Colors.textSecondary)

            TextField("Add a note...", text: $note, axis: .vertical)
                .font(OuestTheme.Fonts.body)
                .lineLimit(2...4)
                .padding(OuestTheme.Spacing.md)
                .background(OuestTheme.Colors.cardBackground)
                .cornerRadius(OuestTheme.CornerRadius.medium)
        }
    }

    // MARK: - Actions

    private func addExpense() async {
        guard let amount = amount else { return }
        isSaving = true

        let request = CreateExpenseRequest(
            tripId: trip.id,
            title: title,
            amount: amount,
            currency: trip.currency,
            category: category,
            paidBy: paidBy,
            splitAmong: Array(selectedMembers),
            date: date
        )

        await onAdd(request)
        dismiss()
    }
}

// MARK: - Split Type

enum SplitType: String, CaseIterable {
    case equal = "Equal"
    case custom = "Custom"

    var displayName: String { rawValue }
}

// MARK: - Member Chip

struct MemberChip: View {
    let profile: Profile?
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: OuestTheme.Spacing.xs) {
                OuestAvatar(profile, size: .small)

                Text(profile?.displayNameOrEmail ?? "Unknown")
                    .font(OuestTheme.Fonts.subheadline)
                    .foregroundColor(isSelected ? .white : OuestTheme.Colors.text)
                    .lineLimit(1)
            }
            .padding(.horizontal, OuestTheme.Spacing.sm)
            .padding(.vertical, OuestTheme.Spacing.xs)
            .background(
                isSelected
                    ? AnyView(OuestTheme.Gradients.primary)
                    : AnyView(OuestTheme.Colors.cardBackground)
            )
            .cornerRadius(OuestTheme.CornerRadius.pill)
        }
    }
}

// MARK: - Split Member Row

struct SplitMemberRow: View {
    let member: TripMember
    let isSelected: Bool
    let splitType: SplitType
    let customAmount: Decimal
    let onToggle: () -> Void
    let onAmountChange: (Decimal) -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: OuestTheme.Spacing.sm) {
                // Checkbox
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? OuestTheme.Colors.primary : OuestTheme.Colors.textTertiary)

                // Avatar
                OuestAvatar(member.profile, size: .small)

                // Name
                Text(member.profile?.displayNameOrEmail ?? "Unknown")
                    .font(OuestTheme.Fonts.subheadline)
                    .foregroundColor(OuestTheme.Colors.text)
                    .lineLimit(1)

                Spacer()
            }
            .padding(OuestTheme.Spacing.sm)
            .background(
                isSelected
                    ? OuestTheme.Colors.primary.opacity(0.1)
                    : OuestTheme.Colors.cardBackground
            )
            .cornerRadius(OuestTheme.CornerRadius.medium)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Category Picker Sheet

struct CategoryPickerSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedCategory: ExpenseCategory

    var body: some View {
        NavigationStack {
            List {
                ForEach(ExpenseCategory.allCases, id: \.self) { category in
                    Button {
                        selectedCategory = category
                        dismiss()
                    } label: {
                        HStack {
                            Text(category.emoji)
                                .font(.system(size: 24))

                            Text(category.displayName)
                                .font(OuestTheme.Fonts.body)
                                .foregroundColor(OuestTheme.Colors.text)

                            Spacer()

                            if selectedCategory == category {
                                Image(systemName: "checkmark")
                                    .foregroundColor(OuestTheme.Colors.primary)
                            }
                        }
                        .padding(.vertical, OuestTheme.Spacing.xs)
                    }
                }
            }
            .navigationTitle("Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AddExpenseView(
        trip: DemoModeManager.demoTrips[0],
        members: [
            TripMember(id: "1", tripId: "demo-trip-1", userId: "demo-user-1", role: .owner, createdAt: Date(), profile: DemoModeManager.demoMembers[0]),
            TripMember(id: "2", tripId: "demo-trip-1", userId: "demo-user-2", role: .member, createdAt: Date(), profile: DemoModeManager.demoMembers[1])
        ]
    ) { _ in }
    .environmentObject(AppState(isDemoMode: true))
}
