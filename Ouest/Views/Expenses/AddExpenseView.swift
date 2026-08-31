import SwiftUI
import PhotosUI

struct AddExpenseView: View {
    @Bindable var viewModel: ExpensesViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var contentAppeared = false
    @State private var selectedPhoto: PhotosPickerItem?

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

                    // Receipt photo section
                    receiptSection
                        .fadeSlideIn(isVisible: contentAppeared, delay: 0.18)

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
                    .disabled(!viewModel.isFormValid || viewModel.isSaving || viewModel.isFetchingFXRate)
                }
            }
            .onAppear {
                withAnimation(OuestTheme.Anim.smooth) {
                    contentAppeared = true
                }
                Task { await viewModel.refreshFXRate() }
            }
            .onChange(of: viewModel.expenseCurrency) { _, _ in
                Task { await viewModel.refreshFXRate() }
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

                // Amount + currency
                VStack(alignment: .leading, spacing: OuestTheme.Spacing.xs) {
                    HStack(spacing: OuestTheme.Spacing.sm) {
                        currencyPicker

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

                    conversionPreview
                        .padding(.horizontal, OuestTheme.Spacing.xs)
                }

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

    // MARK: - Receipt Section

    private var receiptSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.md) {
            Text("Receipt")
                .font(OuestTheme.Typography.sectionTitle)

            if let data = viewModel.receiptImageData, let uiImage = UIImage(data: data) {
                // Show selected receipt
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))

                    Button {
                        withAnimation {
                            viewModel.receiptImageData = nil
                            selectedPhoto = nil
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .accessibilityLabel("Remove receipt photo")
                            .shadow(radius: 2)
                    }
                    .padding(OuestTheme.Spacing.sm)
                }
            } else if let existingUrl = viewModel.editingExpense?.receiptUrl,
                      let url = URL(string: existingUrl) {
                // Show existing receipt from server
                ZStack(alignment: .topTrailing) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
                        case .failure:
                            receiptPlaceholder(text: "Failed to load receipt")
                        case .empty:
                            receiptPlaceholder(text: "Loading…")
                                .shimmerEffect()
                        @unknown default:
                            receiptPlaceholder(text: "Receipt")
                        }
                    }
                }
            }

            let hasReceiptImage = viewModel.receiptImageData != nil
            
            PhotosPicker(
                selection: $selectedPhoto,
                matching: .images,
                photoLibrary: .shared()
            ) {
                HStack(spacing: OuestTheme.Spacing.sm) {
                    Image(systemName: "camera.fill")
                        .font(.body)
                    Text(hasReceiptImage ? "Change Photo" : "Add Receipt Photo")
                        .font(.body)
                }
                .frame(maxWidth: .infinity)
                .padding(OuestTheme.Spacing.md)
                .background(OuestTheme.Colors.surfaceSecondary)
                .foregroundStyle(OuestTheme.Colors.brand)
                .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
            }
            .onChange(of: selectedPhoto) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        // Compress to JPEG
                        if let uiImage = UIImage(data: data),
                           let jpeg = uiImage.jpegData(compressionQuality: 0.7) {
                            withAnimation {
                                viewModel.receiptImageData = jpeg
                            }
                        }
                    }
                }
            }
        }
    }

    private func receiptPlaceholder(text: String) -> some View {
        VStack(spacing: OuestTheme.Spacing.sm) {
            Image(systemName: "doc.text.image")
                .font(.title2)
                .foregroundStyle(OuestTheme.Colors.textSecondary)
            Text(text)
                .font(OuestTheme.Typography.caption)
                .foregroundStyle(OuestTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(OuestTheme.Colors.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
    }

    // MARK: - Currency Picker

    private var currencyPicker: some View {
        let entries = CommonCurrency.listIncluding(viewModel.trip.currency)
        return Menu {
            ForEach(entries) { entry in
                Button {
                    HapticFeedback.selection()
                    viewModel.expenseCurrency = entry.code
                } label: {
                    HStack {
                        Text(entry.code).bold()
                        Text(entry.name)
                        Spacer()
                        if entry.code == viewModel.expenseCurrency {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(viewModel.expenseCurrency)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                if viewModel.canEditCurrency {
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
            }
            .foregroundStyle(viewModel.canEditCurrency ? OuestTheme.Colors.brand : OuestTheme.Colors.textSecondary)
            .padding(.horizontal, OuestTheme.Spacing.sm)
            .padding(.vertical, 6)
            .background(OuestTheme.Colors.brand.opacity(viewModel.canEditCurrency ? 0.1 : 0.05))
            .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.sm))
        }
        .disabled(!viewModel.canEditCurrency)
        .accessibilityLabel("Currency")
        .accessibilityValue(viewModel.expenseCurrency)
        .accessibilityHint(viewModel.canEditCurrency
            ? "Double tap to change the currency for this expense"
            : "Currency is locked on existing expenses")
    }

    @ViewBuilder
    private var conversionPreview: some View {
        if viewModel.needsCurrencyConversion {
            if viewModel.isFetchingFXRate {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.mini)
                    Text("Fetching exchange rate…")
                        .font(OuestTheme.Typography.caption)
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                }
            } else if let error = viewModel.fxFetchError {
                Text(error)
                    .font(OuestTheme.Typography.caption)
                    .foregroundStyle(OuestTheme.Colors.warning)
            } else if let preview = viewModel.convertedAmountPreviewText {
                Text(preview)
                    .font(OuestTheme.Typography.caption)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
            }
        }
    }

    // MARK: - Helpers

    private var currencySymbol: String {
        symbol(for: viewModel.expenseCurrency)
    }

    private func symbol(for code: String) -> String {
        let locale = Locale.availableIdentifiers
            .map { Locale(identifier: $0) }
            .first { $0.currency?.identifier == code }
        return locale?.currencySymbol ?? "$"
    }

    private func formatAmount(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = viewModel.expenseCurrency
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
