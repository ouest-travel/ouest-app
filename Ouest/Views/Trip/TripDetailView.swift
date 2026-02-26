import SwiftUI

struct TripDetailView: View {
    let tripId: UUID
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = TripDetailViewModel()
    @State private var showEditTrip = false
    @State private var showMembers = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading...")
            } else if let trip = viewModel.trip {
                tripContent(trip)
            } else if let error = viewModel.errorMessage {
                ErrorView(message: error) {
                    Task { await viewModel.loadTrip(id: tripId) }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadTrip(id: tripId)
        }
    }

    // MARK: - Trip Content

    private func tripContent(_ trip: Trip) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero Cover
                coverHeader(trip)

                // Quick Info Bar
                quickInfoBar(trip)

                // Action Buttons
                actionButtons(trip)

                // Description
                if let desc = trip.description, !desc.isEmpty {
                    descriptionSection(desc)
                }

                // Members Preview
                membersPreview

                // Placeholder sections for future phases
                futureSections(trip)
            }
        }
        .toolbar {
            if viewModel.canEdit {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showEditTrip = true
                        } label: {
                            Label("Edit Trip", systemImage: "pencil")
                        }

                        Button {
                            showMembers = true
                        } label: {
                            Label("Manage Members", systemImage: "person.2")
                        }

                        if viewModel.myRole == .owner {
                            Divider()
                            Button(role: .destructive) {
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete Trip", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showEditTrip) {
            EditTripView(viewModel: viewModel)
        }
        .sheet(isPresented: $showMembers) {
            TripMembersView(viewModel: viewModel)
        }
        .alert("Delete Trip", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    try await TripService.deleteTrip(id: tripId)
                    dismiss()
                }
            }
        } message: {
            Text("This will permanently delete \"\(trip.title)\" and all its data. This cannot be undone.")
        }
    }

    // MARK: - Cover Header

    private func coverHeader(_ trip: Trip) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let urlString = trip.coverImageUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    gradientPlaceholder(trip)
                }
            } else {
                gradientPlaceholder(trip)
            }

            // Gradient overlay
            LinearGradient(
                colors: [.clear, .clear, .black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(trip.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                    Text(trip.destination)
                }
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
            }
            .padding(20)
        }
        .frame(height: 260)
        .clipped()
    }

    private func gradientPlaceholder(_ trip: Trip) -> some View {
        let hash = abs(trip.destination.hashValue)
        let palettes: [[Color]] = [
            [.blue, .purple], [.teal, .blue], [.orange, .pink],
            [.green, .teal], [.indigo, .blue], [.pink, .orange],
        ]
        let colors = palettes[hash % palettes.count]

        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay {
                Image(systemName: "airplane")
                    .font(.system(size: 40))
                    .foregroundStyle(.white.opacity(0.2))
            }
    }

    // MARK: - Quick Info Bar

    private func quickInfoBar(_ trip: Trip) -> some View {
        HStack(spacing: 0) {
            if let dates = trip.dateRangeText {
                infoChip(icon: "calendar", value: dates)
            }
            if let days = trip.durationDays {
                infoChip(icon: "clock", value: "\(days) day\(days == 1 ? "" : "s")")
            }
            infoChip(icon: "person.2", value: "\(viewModel.members.count)")
            infoChip(icon: trip.status.icon, value: trip.status.label)
        }
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
    }

    private func infoChip(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Action Buttons

    private func actionButtons(_ trip: Trip) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                actionButton("Itinerary", icon: "list.bullet.clipboard", color: .blue)
                actionButton("Expenses", icon: "creditcard", color: .green)
                actionButton("Journal", icon: "book", color: .purple)
                actionButton("Polls", icon: "chart.bar", color: .orange)
                actionButton("Chat", icon: "bubble.left.and.bubble.right", color: .teal)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    private func actionButton(_ label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 48, height: 48)
                .background(color.opacity(0.12))
                .foregroundStyle(color)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(label)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Description

    private func descriptionSection(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About")
                .font(.headline)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Members Preview

    private var membersPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Travelers")
                    .font(.headline)
                Spacer()
                Button("See All") { showMembers = true }
                    .font(.subheadline)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.members) { member in
                        VStack(spacing: 4) {
                            AvatarView(url: member.profile?.avatarUrl, size: 48)
                            Text(member.profile?.fullName?.components(separatedBy: " ").first ?? "?")
                                .font(.caption2)
                                .lineLimit(1)
                            if member.role == .owner {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.orange)
                            }
                        }
                        .frame(width: 56)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Future Sections (placeholders for later phases)

    private func futureSections(_ trip: Trip) -> some View {
        VStack(spacing: 16) {
            Divider().padding(.horizontal, 20)

            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.teal)
                Text("Itinerary, expenses, journal, and more coming soon")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }
}

#Preview {
    NavigationStack {
        TripDetailView(tripId: UUID())
            .environment(AuthViewModel())
    }
}
