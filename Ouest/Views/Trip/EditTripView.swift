import SwiftUI
import PhotosUI

struct EditTripView: View {
    @Bindable var viewModel: TripDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var coverPreview: Image?
    @State private var showCountryPicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: OuestTheme.Spacing.xxl) {
                    coverImagePicker
                    tripDetailsSection
                    destinationCountriesSection
                    dateSection
                    budgetSection
                    statusSection
                    optionsSection

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(OuestTheme.Typography.caption)
                            .foregroundStyle(OuestTheme.Colors.error)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(OuestTheme.Spacing.xl)
            }
            .navigationTitle("Edit Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Task {
                            if await viewModel.updateTrip() {
                                dismiss()
                            }
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(viewModel.isSaving || !isFormValid)
                }
            }
            .sheet(isPresented: $showCountryPicker) {
                CountryPickerView(selectedCodes: $viewModel.countryCodes)
            }
            .onAppear {
                if let trip = viewModel.trip {
                    viewModel.populateFromTrip(trip)
                    // Load existing cover image preview
                    if let urlString = trip.coverImageUrl, let url = URL(string: urlString) {
                        loadRemoteCover(url)
                    }
                }
            }
        }
    }

    private var isFormValid: Bool {
        !viewModel.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !viewModel.destination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Cover Image

    private var coverImagePicker: some View {
        PhotosPicker(selection: $selectedPhoto, matching: .images) {
            ZStack {
                if let coverPreview {
                    coverPreview.resizable().scaledToFill()
                        .transition(.opacity)
                } else {
                    LinearGradient(
                        colors: [.teal.opacity(0.3), .blue.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }

                VStack(spacing: OuestTheme.Spacing.sm) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.title2)
                        .symbolEffect(.bounce, value: coverPreview != nil)
                    Text("Change Photo")
                        .font(OuestTheme.Typography.caption)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.white)
                .padding(OuestTheme.Spacing.md)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
            }
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.lg))
        }
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        .pressEffect(scale: 0.97)
        .onChange(of: selectedPhoto) {
            Task {
                if let data = try? await selectedPhoto?.loadTransferable(type: Data.self) {
                    viewModel.coverImageData = data
                    if let uiImage = UIImage(data: data) {
                        withAnimation(OuestTheme.Anim.smooth) {
                            coverPreview = Image(uiImage: uiImage)
                        }
                        HapticFeedback.selection()
                    }
                }
            }
        }
    }

    private func loadRemoteCover(_ url: URL) {
        Task {
            if let (data, _) = try? await URLSession.shared.data(from: url),
               let uiImage = UIImage(data: data) {
                coverPreview = Image(uiImage: uiImage)
            }
        }
    }

    // MARK: - Destination Countries

    private var destinationCountriesSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.md) {
            sectionHeader("Destination Countries", icon: "globe")

            if !viewModel.countryCodes.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: OuestTheme.Spacing.sm) {
                        ForEach(viewModel.countryCodes, id: \.self) { code in
                            HStack(spacing: OuestTheme.Spacing.xs) {
                                Text(EntryRequirementService.flag(for: code))
                                Text(EntryRequirementService.countryName(for: code))
                                    .font(OuestTheme.Typography.caption)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, OuestTheme.Spacing.md)
                            .padding(.vertical, OuestTheme.Spacing.sm)
                            .background(OuestTheme.Colors.brandLight)
                            .clipShape(Capsule())
                        }
                    }
                }
            }

            Button {
                HapticFeedback.light()
                showCountryPicker = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text(viewModel.countryCodes.isEmpty ? "Add Countries" : "Edit Countries")
                        .fontWeight(.medium)
                }
                .font(.subheadline)
                .foregroundStyle(OuestTheme.Colors.brand)
                .frame(maxWidth: .infinity)
                .padding(.vertical, OuestTheme.Spacing.md)
                .background(OuestTheme.Colors.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
            }
        }
    }

    // MARK: - Fields

    private var tripDetailsSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.md) {
            sectionHeader("Details", icon: "pencil.line")

            OuestTextField(text: $viewModel.title, placeholder: "Trip name")
                .textInputAutocapitalization(.words)
            OuestTextField(text: $viewModel.destination, placeholder: "Destination")
                .textInputAutocapitalization(.words)

            TextField("Description", text: $viewModel.description, axis: .vertical)
                .lineLimit(3...6)
                .padding(OuestTheme.Spacing.lg)
                .background(OuestTheme.Colors.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
        }
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.md) {
            HStack {
                sectionHeader("Dates", icon: "calendar")
                Spacer()
                Toggle("", isOn: $viewModel.hasDates)
                    .labelsHidden()
                    .tint(OuestTheme.Colors.brand)
            }

            if viewModel.hasDates {
                HStack(spacing: OuestTheme.Spacing.md) {
                    VStack(alignment: .leading, spacing: OuestTheme.Spacing.xs) {
                        Text("Start")
                            .font(OuestTheme.Typography.caption)
                            .foregroundStyle(OuestTheme.Colors.textSecondary)
                        DatePicker("", selection: $viewModel.startDate, displayedComponents: .date)
                            .labelsHidden()
                    }
                    Image(systemName: "arrow.right")
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                        .font(.caption)
                    VStack(alignment: .leading, spacing: OuestTheme.Spacing.xs) {
                        Text("End")
                            .font(OuestTheme.Typography.caption)
                            .foregroundStyle(OuestTheme.Colors.textSecondary)
                        DatePicker("", selection: $viewModel.endDate, in: viewModel.startDate..., displayedComponents: .date)
                            .labelsHidden()
                    }
                }
                .padding(OuestTheme.Spacing.md)
                .background(OuestTheme.Colors.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(OuestTheme.Anim.smooth, value: viewModel.hasDates)
    }

    // MARK: - Budget

    private static let currencies: [(code: String, symbol: String)] = [
        ("USD", "$"), ("EUR", "€"), ("GBP", "£"), ("CAD", "C$"),
        ("JPY", "¥"), ("AUD", "A$"), ("CHF", "CHF")
    ]

    private var budgetSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.md) {
            HStack {
                sectionHeader("Budget", icon: "dollarsign.circle")
                Spacer()
                Toggle("", isOn: $viewModel.hasBudget)
                    .labelsHidden()
                    .tint(OuestTheme.Colors.brand)
            }

            if viewModel.hasBudget {
                VStack(spacing: OuestTheme.Spacing.md) {
                    // Currency picker
                    HStack {
                        Text("Currency")
                            .font(OuestTheme.Typography.caption)
                            .foregroundStyle(OuestTheme.Colors.textSecondary)
                        Spacer()
                        Picker("Currency", selection: $viewModel.currency) {
                            ForEach(Self.currencies, id: \.code) { curr in
                                Text("\(curr.symbol) \(curr.code)").tag(curr.code)
                            }
                        }
                        .tint(OuestTheme.Colors.brand)
                    }

                    // Budget amount
                    HStack(spacing: OuestTheme.Spacing.sm) {
                        Text(Self.currencies.first(where: { $0.code == viewModel.currency })?.symbol ?? "$")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(OuestTheme.Colors.brand)
                            .frame(width: 28)

                        TextField("0", text: $viewModel.budgetText)
                            .keyboardType(.decimalPad)
                            .font(.title3)
                            .fontWeight(.medium)
                    }
                    .padding(OuestTheme.Spacing.md)
                    .background(OuestTheme.Colors.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(OuestTheme.Anim.smooth, value: viewModel.hasBudget)
    }

    // MARK: - Status

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.md) {
            sectionHeader("Status", icon: "flag")

            Picker("Status", selection: Binding(
                get: { viewModel.trip?.status ?? .planning },
                set: { newStatus in
                    guard let tripId = viewModel.trip?.id else { return }
                    Task {
                        _ = try? await TripService.updateTrip(
                            id: tripId,
                            UpdateTripPayload(status: newStatus)
                        )
                        viewModel.trip?.status = newStatus
                    }
                }
            )) {
                ForEach(TripStatus.allCases, id: \.self) { status in
                    Label(status.label, systemImage: status.icon)
                        .tag(status)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.md) {
            sectionHeader("Visibility", icon: "eye")

            Toggle(isOn: $viewModel.isPublic) {
                HStack(spacing: 10) {
                    Image(systemName: viewModel.isPublic ? "globe" : "lock.fill")
                        .foregroundStyle(viewModel.isPublic ? OuestTheme.Colors.success : OuestTheme.Colors.textSecondary)
                        .frame(width: 20)
                        .contentTransition(.symbolEffect(.replace))
                    VStack(alignment: .leading, spacing: OuestTheme.Spacing.xxs) {
                        Text(viewModel.isPublic ? "Public" : "Private")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(viewModel.isPublic ? "Anyone can discover this trip" : "Only invited members can see")
                            .font(OuestTheme.Typography.caption)
                            .foregroundStyle(OuestTheme.Colors.textSecondary)
                    }
                }
            }
            .tint(OuestTheme.Colors.brand)
            .padding(OuestTheme.Spacing.md)
            .background(OuestTheme.Colors.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
        }
        .animation(OuestTheme.Anim.quick, value: viewModel.isPublic)
    }

    // MARK: - Section Header

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

#Preview {
    EditTripView(viewModel: TripDetailViewModel())
}
