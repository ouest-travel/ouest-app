import SwiftUI

struct TripDetailView: View {
    let tripId: UUID
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = TripDetailViewModel()
    @State private var showEditTrip = false
    @State private var showMembers = false
    @State private var showShareSheet = false
    @State private var showDeleteConfirmation = false
    @State private var contentAppeared = false

    var body: some View {
        Group {
            if viewModel.isLoading {
                loadingSkeleton
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
            withAnimation(OuestTheme.Anim.smooth) {
                contentAppeared = true
            }
        }
    }

    // MARK: - Loading Skeleton

    private var loadingSkeleton: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero skeleton
                RoundedRectangle(cornerRadius: 0)
                    .fill(OuestTheme.Colors.surfaceSecondary)
                    .frame(height: 260)
                    .shimmerEffect()

                // Info bar skeleton
                HStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { _ in
                        SkeletonView(width: 60, height: 12)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, OuestTheme.Spacing.md)

                // Action buttons skeleton
                HStack(spacing: OuestTheme.Spacing.md) {
                    ForEach(0..<5, id: \.self) { _ in
                        VStack(spacing: OuestTheme.Spacing.sm) {
                            SkeletonView(height: 48, radius: OuestTheme.Radius.md)
                                .frame(width: 48)
                            SkeletonView(width: 40, height: 10)
                        }
                    }
                }
                .padding(.horizontal, OuestTheme.Spacing.xl)
                .padding(.vertical, OuestTheme.Spacing.lg)

                // Description skeleton
                VStack(alignment: .leading, spacing: OuestTheme.Spacing.sm) {
                    SkeletonView(width: 60, height: 14)
                    SkeletonView(height: 12)
                    SkeletonView(width: 200, height: 12)
                }
                .padding(.horizontal, OuestTheme.Spacing.xl)
                .padding(.vertical, OuestTheme.Spacing.md)
            }
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
                    .fadeSlideIn(isVisible: contentAppeared, delay: 0.05)

                // Action Buttons
                actionButtons(trip)
                    .fadeSlideIn(isVisible: contentAppeared, delay: 0.1)

                // Description
                if let desc = trip.description, !desc.isEmpty {
                    descriptionSection(desc)
                        .fadeSlideIn(isVisible: contentAppeared, delay: 0.15)
                }

                // Members Preview
                membersPreview
                    .fadeSlideIn(isVisible: contentAppeared, delay: 0.2)

                // Placeholder sections for future phases
                futureSections(trip)
                    .fadeSlideIn(isVisible: contentAppeared, delay: 0.25)
            }
        }
        .toolbar {
            if viewModel.canEdit {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showShareSheet = true
                        } label: {
                            Label("Share Trip", systemImage: "square.and.arrow.up")
                        }

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
        .sheet(isPresented: $showShareSheet) {
            if let trip = viewModel.trip {
                ShareTripSheet(trip: trip)
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
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .transition(.opacity)
                    case .failure:
                        gradientPlaceholder(trip)
                    case .empty:
                        gradientPlaceholder(trip)
                            .shimmerEffect()
                    @unknown default:
                        gradientPlaceholder(trip)
                    }
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

            VStack(alignment: .leading, spacing: OuestTheme.Spacing.xs) {
                Text(trip.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                HStack(spacing: OuestTheme.Spacing.xs) {
                    Image(systemName: "mappin.circle.fill")
                    Text(trip.destination)
                }
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
            }
            .padding(OuestTheme.Spacing.xl)
        }
        .frame(height: 260)
        .clipped()
    }

    private func gradientPlaceholder(_ trip: Trip) -> some View {
        let hash = abs(trip.destination.hashValue)
        let colors = OuestTheme.Colors.tripGradients[hash % OuestTheme.Colors.tripGradients.count]

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
            if let formatted = trip.formattedBudget {
                infoChip(icon: "dollarsign.circle", value: formatted)
            }
            infoChip(icon: "person.2", value: "\(viewModel.members.count)")
            infoChip(icon: trip.status.icon, value: trip.status.label)
        }
        .padding(.vertical, OuestTheme.Spacing.md)
        .background(OuestTheme.Colors.surfaceSecondary)
    }

    private func infoChip(icon: String, value: String) -> some View {
        HStack(spacing: OuestTheme.Spacing.xs) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(OuestTheme.Colors.textSecondary)
            Text(value)
                .font(OuestTheme.Typography.caption)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Action Buttons

    private func actionButtons(_ trip: Trip) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: OuestTheme.Spacing.md) {
                // Itinerary — live NavigationLink
                NavigationLink {
                    ItineraryView(trip: trip)
                } label: {
                    actionButtonLabel("Itinerary", icon: "list.bullet.clipboard", color: .blue, index: 0)
                }
                .buttonStyle(ScaledButtonStyle(scale: 0.92))

                // Expenses — live NavigationLink
                NavigationLink {
                    ExpensesView(trip: trip)
                } label: {
                    actionButtonLabel("Expenses", icon: "creditcard", color: .green, index: 1)
                }
                .buttonStyle(ScaledButtonStyle(scale: 0.92))

                // Entry Requirements — live NavigationLink
                NavigationLink {
                    EntryRequirementsView(trip: trip)
                        .environment(authViewModel)
                } label: {
                    actionButtonLabel("Entry Reqs", icon: "doc.text.magnifyingglass", color: .red, index: 2)
                }
                .buttonStyle(ScaledButtonStyle(scale: 0.92))

                // Journal — live NavigationLink
                NavigationLink {
                    JournalView(trip: trip)
                } label: {
                    actionButtonLabel("Journal", icon: "book", color: .purple, index: 3)
                }
                .buttonStyle(ScaledButtonStyle(scale: 0.92))

                // Polls — live NavigationLink
                NavigationLink {
                    PollsView(trip: trip)
                } label: {
                    actionButtonLabel("Polls", icon: "chart.bar", color: .orange, index: 4)
                }
                .buttonStyle(ScaledButtonStyle(scale: 0.92))
                actionButtonLabel("Chat", icon: "bubble.left.and.bubble.right", color: .teal, index: 5)
            }
            .padding(.horizontal, OuestTheme.Spacing.xl)
            .padding(.vertical, OuestTheme.Spacing.lg)
        }
    }

    private func actionButtonLabel(_ label: String, icon: String, color: Color, index: Int) -> some View {
        VStack(spacing: OuestTheme.Spacing.sm) {
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 48, height: 48)
                .background(color.opacity(0.12))
                .foregroundStyle(color)
                .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
                .shadow(OuestTheme.Shadow.sm)

            Text(label)
                .font(OuestTheme.Typography.micro)
                .fontWeight(.medium)
                .foregroundStyle(OuestTheme.Colors.textSecondary)
        }
        .bouncyAppear(isVisible: contentAppeared, delay: 0.15 + Double(index) * 0.05)
    }

    // MARK: - Description

    private func descriptionSection(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.sm) {
            HStack(spacing: OuestTheme.Spacing.sm) {
                Image(systemName: "text.alignleft")
                    .font(.subheadline)
                    .foregroundStyle(OuestTheme.Colors.brand)
                Text("About")
                    .font(OuestTheme.Typography.sectionTitle)
            }

            Text(text)
                .font(.subheadline)
                .foregroundStyle(OuestTheme.Colors.textSecondary)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, OuestTheme.Spacing.xl)
        .padding(.vertical, OuestTheme.Spacing.md)
    }

    // MARK: - Members Preview

    private var membersPreview: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.md) {
            HStack {
                HStack(spacing: OuestTheme.Spacing.sm) {
                    Image(systemName: "person.2.fill")
                        .font(.subheadline)
                        .foregroundStyle(OuestTheme.Colors.brand)
                    Text("Travelers")
                        .font(OuestTheme.Typography.sectionTitle)
                }
                Spacer()
                Button {
                    HapticFeedback.light()
                    showMembers = true
                } label: {
                    Text("See All")
                        .font(.subheadline)
                        .foregroundStyle(OuestTheme.Colors.brand)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: OuestTheme.Spacing.md) {
                    ForEach(Array(viewModel.members.enumerated()), id: \.element.id) { index, member in
                        VStack(spacing: OuestTheme.Spacing.xs) {
                            AvatarView(url: member.profile?.avatarUrl, size: 48)
                                .shadow(OuestTheme.Shadow.sm)
                            Text(member.profile?.fullName?.components(separatedBy: " ").first ?? "?")
                                .font(OuestTheme.Typography.micro)
                                .lineLimit(1)
                            if member.role == .owner {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.orange)
                            }
                        }
                        .frame(width: 56)
                        .bouncyAppear(isVisible: contentAppeared, delay: 0.25 + Double(index) * 0.06)
                    }
                }
            }
        }
        .padding(.horizontal, OuestTheme.Spacing.xl)
        .padding(.vertical, OuestTheme.Spacing.md)
    }

    // MARK: - Future Sections (placeholders for later phases)

    private func futureSections(_ trip: Trip) -> some View {
        VStack(spacing: OuestTheme.Spacing.lg) {
            Divider().padding(.horizontal, OuestTheme.Spacing.xl)

            HStack(spacing: OuestTheme.Spacing.sm) {
                Image(systemName: "sparkles")
                    .foregroundStyle(OuestTheme.Colors.brand)
                    .symbolEffect(.pulse)
                Text("Chat and more coming soon")
                    .font(OuestTheme.Typography.caption)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
            }
            .padding(.horizontal, OuestTheme.Spacing.xl)
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
