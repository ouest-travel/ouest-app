import SwiftUI

struct TripDetailView: View {
    let tripId: UUID

    /// Source id + namespace for the iOS 18 zoom transition from the card.
    /// Both optional so callers that don't opt into the transition (or
    /// previews) keep working — `.zoomDestination` is a no-op on nil.
    var zoomSourceId: UUID? = nil
    var zoomNamespace: Namespace.ID? = nil

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
        .navigationDestination(for: ProfileDestination.self) { dest in
            UserProfileView(userId: dest.userId)
        }
        .zoomDestination(id: zoomSourceId, in: zoomNamespace)
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

                // Action Buttons (always visible; child views handle read-only)
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
        // Establish the screen-width bound via Color.clear at the back of the
        // ZStack. .scaledToFill() preserves aspect ratio, so a panoramic cover
        // image at 260pt tall has a natural width far wider than the screen —
        // without an explicit maxWidth: .infinity constraint, the ZStack
        // expands to that natural width and pushes every section below it off
        // the leading edge. .clipped() clips painting but NOT layout, so the
        // bug stays invisible until the cover image has a wide aspect.
        ZStack(alignment: .bottomLeading) {
            // Width-bounding sibling — guarantees the ZStack takes exactly
            // the proposed (screen) width regardless of the cover image's
            // intrinsic dimensions.
            Color.clear

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
                colors: [.clear, OuestTheme.Colors.deepNavy.opacity(0.75)],
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
        .frame(maxWidth: .infinity)
        .frame(height: 260)
        .clipped()
    }

    private func gradientPlaceholder(_ trip: Trip) -> some View {
        let hash = abs(trip.destination.hashValue)
        let colors = OuestTheme.Colors.tripGradients[hash % OuestTheme.Colors.tripGradients.count]

        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay {
                Image(systemName: "airplane")
                    .font(.system(size: OuestTheme.Icon.hero))
                    .foregroundStyle(.white.opacity(0.2))
            }
    }

    // MARK: - Quick Info Bar

    private func quickInfoBar(_ trip: Trip) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: OuestTheme.Spacing.sm) {
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
            .padding(.horizontal, OuestTheme.Spacing.lg)
        }
        .padding(.vertical, OuestTheme.Spacing.md)
    }

    private func infoChip(icon: String, value: String) -> some View {
        HStack(spacing: OuestTheme.Spacing.xs) {
            Image(systemName: icon)
                .font(.caption2)
            Text(value)
                .font(OuestTheme.Typography.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, OuestTheme.Spacing.md)
        .padding(.vertical, OuestTheme.Spacing.xs)
        .background(OuestTheme.Colors.brand.opacity(0.85))
        .clipShape(Capsule())
    }

    // MARK: - Action Buttons

    private func actionButtons(_ trip: Trip) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: OuestTheme.Spacing.md) {
                // Itinerary
                NavigationLink {
                    ItineraryView(trip: trip, canEdit: viewModel.isMember)
                } label: {
                    actionButtonLabel("Itinerary", icon: "list.bullet.clipboard", color: .blue, index: 0)
                }
                .buttonStyle(ScaledButtonStyle(scale: 0.92))

                // Expenses
                NavigationLink {
                    ExpensesView(trip: trip, canEdit: viewModel.isMember)
                } label: {
                    actionButtonLabel("Expenses", icon: "creditcard", color: .green, index: 1)
                }
                .buttonStyle(ScaledButtonStyle(scale: 0.92))

                // Entry Requirements (already read-only)
                NavigationLink {
                    EntryRequirementsView(trip: trip)
                        .environment(authViewModel)
                } label: {
                    actionButtonLabel("Entry Reqs", icon: "doc.text.magnifyingglass", color: .red, index: 2)
                }
                .buttonStyle(ScaledButtonStyle(scale: 0.92))

                // Journal
                NavigationLink {
                    JournalView(trip: trip, canEdit: viewModel.isMember)
                } label: {
                    actionButtonLabel("Journal", icon: "book", color: .purple, index: 3)
                }
                .buttonStyle(ScaledButtonStyle(scale: 0.92))

                // Polls
                NavigationLink {
                    PollsView(trip: trip, canEdit: viewModel.isMember)
                } label: {
                    actionButtonLabel("Polls", icon: "chart.bar", color: .orange, index: 4)
                }
                .buttonStyle(ScaledButtonStyle(scale: 0.92))

                // Gallery
                NavigationLink {
                    TripGalleryView(trip: trip, canEdit: viewModel.isMember)
                        .environment(authViewModel)
                } label: {
                    actionButtonLabel("Gallery", icon: "photo.on.rectangle.angled", color: .pink, index: 5)
                }
                .buttonStyle(ScaledButtonStyle(scale: 0.92))

                actionButtonLabel("Chat", icon: "bubble.left.and.bubble.right", color: .teal, index: 6)
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
                .ouestElevation(.sm)

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
                if viewModel.isMember {
                    Button {
                        HapticFeedback.light()
                        showMembers = true
                    } label: {
                        Text("See All")
                            .font(.subheadline)
                            .foregroundStyle(OuestTheme.Colors.brand)
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: OuestTheme.Spacing.md) {
                    ForEach(Array(viewModel.members.enumerated()), id: \.element.id) { index, member in
                        NavigationLink(value: ProfileDestination(userId: member.userId)) {
                            VStack(spacing: OuestTheme.Spacing.xs) {
                                AvatarView(url: member.profile?.avatarUrl, size: 48)
                                    .ouestElevation(.sm)
                                Text(member.profile?.fullName?.components(separatedBy: " ").first ?? "?")
                                    .font(OuestTheme.Typography.micro)
                                    .foregroundStyle(OuestTheme.Colors.textPrimary)
                                    .lineLimit(1)
                                if member.role == .owner {
                                    Image(systemName: "crown.fill")
                                        .font(.caption2) // was 8pt — below SF Symbol legibility
                                        .foregroundStyle(.orange)
                                }
                            }
                            .frame(width: 56)
                        }
                        .buttonStyle(.plain)
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
