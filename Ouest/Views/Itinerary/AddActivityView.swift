import SwiftUI
import MapKit

struct AddActivityView: View {
    @Bindable var viewModel: ItineraryViewModel
    let day: ItineraryDay
    @Environment(\.dismiss) private var dismiss
    @State private var appeared = false
    @State private var searchTask: Task<Void, Never>?

    private var isEditing: Bool { viewModel.editingActivity != nil }

    private static let currencies: [(code: String, symbol: String)] = [
        ("USD", "$"), ("EUR", "\u{20AC}"), ("GBP", "\u{00A3}"), ("CAD", "C$"),
        ("JPY", "\u{00A5}"), ("AUD", "A$"), ("CHF", "CHF")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: OuestTheme.Spacing.xxl) {
                    detailsSection
                        .fadeSlideIn(isVisible: appeared, delay: 0.05)

                    locationSection
                        .fadeSlideIn(isVisible: appeared, delay: 0.1)

                    timeSection
                        .fadeSlideIn(isVisible: appeared, delay: 0.15)

                    categorySection
                        .fadeSlideIn(isVisible: appeared, delay: 0.2)

                    costSection
                        .fadeSlideIn(isVisible: appeared, delay: 0.25)

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(OuestTheme.Typography.caption)
                            .foregroundStyle(OuestTheme.Colors.error)
                            .multilineTextAlignment(.center)
                    }

                    // Save button
                    OuestButton(
                        title: isEditing ? "Save Changes" : "Add Activity",
                        isLoading: viewModel.isSaving
                    ) {
                        Task {
                            let success = await viewModel.saveActivity(forDay: day)
                            if success { dismiss() }
                        }
                    }
                    .disabled(!viewModel.isActivityFormValid)
                    .fadeSlideIn(isVisible: appeared, delay: 0.3)
                }
                .padding(OuestTheme.Spacing.xl)
            }
            .navigationTitle(isEditing ? "Edit Activity" : "New Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
                }
            }
            .onAppear {
                withAnimation(OuestTheme.Anim.smooth) {
                    appeared = true
                }
            }
        }
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.md) {
            sectionHeader("Details", icon: "pencil.line")

            OuestTextField(
                text: $viewModel.activityTitle,
                placeholder: "Activity name"
            )

            TextField("Description (optional)", text: $viewModel.activityDescription, axis: .vertical)
                .lineLimit(3...6)
                .padding(OuestTheme.Spacing.md)
                .background(OuestTheme.Colors.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
        }
    }

    // MARK: - Location Section

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.md) {
            sectionHeader("Location", icon: "mappin.and.ellipse")

            // Selected location chip
            if !viewModel.activityLocationName.isEmpty {
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundStyle(OuestTheme.Colors.brand)
                    Text(viewModel.activityLocationName)
                        .font(.subheadline)
                        .lineLimit(1)
                    Spacer()
                    Button {
                        viewModel.clearSelectedPlace()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(OuestTheme.Colors.textSecondary)
                    }
                }
                .padding(OuestTheme.Spacing.md)
                .background(OuestTheme.Colors.brandLight)
                .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
            }

            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
                TextField("Search for a place...", text: $viewModel.searchQuery)
                    .autocorrectionDisabled()

                if viewModel.isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(OuestTheme.Spacing.md)
            .background(OuestTheme.Colors.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
            .onChange(of: viewModel.searchQuery) {
                searchTask?.cancel()
                searchTask = Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    guard !Task.isCancelled else { return }
                    await viewModel.searchPlaces()
                }
            }

            // Search results
            if !viewModel.searchResults.isEmpty {
                VStack(spacing: 0) {
                    ForEach(viewModel.searchResults.prefix(5), id: \.self) { item in
                        Button {
                            HapticFeedback.selection()
                            viewModel.selectPlace(item)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name ?? "Unknown")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(OuestTheme.Colors.textPrimary)
                                    if let subtitle = item.placemark.formattedAddress {
                                        Text(subtitle)
                                            .font(OuestTheme.Typography.caption)
                                            .foregroundStyle(OuestTheme.Colors.textSecondary)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                                Image(systemName: "arrow.up.left")
                                    .font(.caption)
                                    .foregroundStyle(OuestTheme.Colors.textSecondary)
                            }
                            .padding(.vertical, OuestTheme.Spacing.sm)
                            .padding(.horizontal, OuestTheme.Spacing.md)
                        }
                        .buttonStyle(.plain)

                        if item != viewModel.searchResults.prefix(5).last {
                            Divider().padding(.leading, OuestTheme.Spacing.md)
                        }
                    }
                }
                .background(OuestTheme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
                .shadow(OuestTheme.Shadow.md)
            }
        }
    }

    // MARK: - Time Section

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.md) {
            sectionHeader("Time", icon: "clock")

            VStack(spacing: OuestTheme.Spacing.md) {
                Toggle(isOn: $viewModel.hasStartTime.animation(OuestTheme.Anim.quick)) {
                    Text("Start Time")
                        .font(.subheadline)
                }
                .tint(OuestTheme.Colors.brand)

                if viewModel.hasStartTime {
                    DatePicker("", selection: $viewModel.activityStartTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Toggle(isOn: $viewModel.hasEndTime.animation(OuestTheme.Anim.quick)) {
                    Text("End Time")
                        .font(.subheadline)
                }
                .tint(OuestTheme.Colors.brand)

                if viewModel.hasEndTime {
                    DatePicker("", selection: $viewModel.activityEndTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Category Section

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.md) {
            sectionHeader("Category", icon: "tag")

            LazyVGrid(columns: [
                GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())
            ], spacing: OuestTheme.Spacing.sm) {
                ForEach(ActivityCategory.allCases, id: \.self) { category in
                    let isSelected = viewModel.activityCategory == category
                    Button {
                        HapticFeedback.selection()
                        withAnimation(OuestTheme.Anim.quick) {
                            viewModel.activityCategory = category
                        }
                    } label: {
                        VStack(spacing: OuestTheme.Spacing.xs) {
                            Image(systemName: category.icon)
                                .font(.title3)
                                .frame(width: 40, height: 40)
                                .background(isSelected ? category.color.opacity(0.2) : OuestTheme.Colors.surfaceSecondary)
                                .foregroundStyle(isSelected ? category.color : OuestTheme.Colors.textSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.sm))

                            Text(category.label)
                                .font(OuestTheme.Typography.micro)
                                .foregroundStyle(isSelected ? category.color : OuestTheme.Colors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, OuestTheme.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: OuestTheme.Radius.md)
                                .stroke(isSelected ? category.color : .clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Cost Section

    private var costSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.md) {
            sectionHeader("Cost", icon: "dollarsign.circle")

            Toggle(isOn: $viewModel.hasCost.animation(OuestTheme.Anim.quick)) {
                Text("Estimated Cost")
                    .font(.subheadline)
            }
            .tint(OuestTheme.Colors.brand)

            if viewModel.hasCost {
                HStack(spacing: OuestTheme.Spacing.md) {
                    Picker("Currency", selection: $viewModel.activityCurrency) {
                        ForEach(Self.currencies, id: \.code) { c in
                            Text(c.symbol).tag(c.code)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 70)

                    TextField("Amount", text: $viewModel.activityCostText)
                        .keyboardType(.decimalPad)
                        .padding(OuestTheme.Spacing.md)
                        .background(OuestTheme.Colors.surfaceSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
                }
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: OuestTheme.Spacing.sm) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(OuestTheme.Colors.brand)
            Text(title)
                .font(OuestTheme.Typography.sectionTitle)
        }
    }
}

// MARK: - MKPlacemark Address Helper

private extension MKPlacemark {
    var formattedAddress: String? {
        let components = [locality, administrativeArea, country].compactMap { $0 }
        return components.isEmpty ? nil : components.joined(separator: ", ")
    }
}

#Preview {
    AddActivityView(
        viewModel: ItineraryViewModel(trip: Trip(
            id: UUID(), createdBy: UUID(), title: "Barcelona", destination: "Barcelona, Spain",
            status: .planning, isPublic: false, createdAt: Date(), updatedAt: Date()
        )),
        day: ItineraryDay(tripId: UUID(), dayNumber: 1, date: Date())
    )
}
