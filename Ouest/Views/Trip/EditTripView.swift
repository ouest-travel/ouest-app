import SwiftUI
import PhotosUI

struct EditTripView: View {
    @Bindable var viewModel: TripDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var coverPreview: Image?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    coverImagePicker
                    tripDetailsSection
                    dateSection
                    statusSection
                    optionsSection

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(20)
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
                } else {
                    LinearGradient(
                        colors: [.teal.opacity(0.3), .blue.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }

                VStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.title2)
                    Text("Change Photo")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.white)
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .onChange(of: selectedPhoto) {
            Task {
                if let data = try? await selectedPhoto?.loadTransferable(type: Data.self) {
                    viewModel.coverImageData = data
                    if let uiImage = UIImage(data: data) {
                        coverPreview = Image(uiImage: uiImage)
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

    // MARK: - Fields

    private var tripDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.headline)

            OuestTextField(text: $viewModel.title, placeholder: "Trip name")
            OuestTextField(text: $viewModel.destination, placeholder: "Destination")

            TextField("Description", text: $viewModel.description, axis: .vertical)
                .lineLimit(3...6)
                .padding(16)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Dates")
                    .font(.headline)
                Spacer()
                Toggle("", isOn: $viewModel.hasDates)
                    .labelsHidden()
            }

            if viewModel.hasDates {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Start").font(.caption).foregroundStyle(.secondary)
                        DatePicker("", selection: $viewModel.startDate, displayedComponents: .date)
                            .labelsHidden()
                    }
                    Image(systemName: "arrow.right").foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("End").font(.caption).foregroundStyle(.secondary)
                        DatePicker("", selection: $viewModel.endDate, in: viewModel.startDate..., displayedComponents: .date)
                            .labelsHidden()
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Status")
                .font(.headline)

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
        VStack(alignment: .leading, spacing: 12) {
            Text("Visibility")
                .font(.headline)

            Toggle(isOn: $viewModel.isPublic) {
                HStack(spacing: 10) {
                    Image(systemName: viewModel.isPublic ? "globe" : "lock.fill")
                        .foregroundStyle(viewModel.isPublic ? .green : .secondary)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.isPublic ? "Public" : "Private")
                            .font(.subheadline)
                        Text(viewModel.isPublic ? "Anyone can discover this trip" : "Only invited members can see")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

#Preview {
    EditTripView(viewModel: TripDetailViewModel())
}
