import SwiftUI

// MARK: - Navigation Destination

/// Lightweight Hashable wrapper for notification-driven navigation. Each case
/// describes WHERE the user lands when they tap a specific notification type,
/// not just which trip — so a "new comment" lands on the comments section, a
/// "new journal entry" lands on the journal list, etc.
enum NotificationNav: Hashable {
    case trip(id: UUID)
    case profile(id: UUID)
    /// Comments thread for a trip. Used for "new_comment" notifications.
    /// Optionally focus a specific comment id once we have scroll-to support.
    case commentsForTrip(tripId: UUID, focusCommentId: UUID? = nil)
    /// Expenses tab for a trip. Optionally focus a specific expense.
    case expensesForTrip(tripId: UUID, focusExpenseId: UUID? = nil)
    /// Journal tab for a trip. Optionally focus a specific entry.
    case journalForTrip(tripId: UUID, focusEntryId: UUID? = nil)
    /// Polls tab for a trip. Optionally focus a specific poll.
    case pollsForTrip(tripId: UUID, focusPollId: UUID? = nil)
}

struct NotificationsView: View {
    @Bindable var viewModel: NotificationsViewModel
    @State private var contentAppeared = false
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.notifications.isEmpty {
                    emptyState
                } else {
                    notificationsList
                }
            }
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: NotificationNav.self) { nav in
                switch nav {
                case .trip(let id):
                    TripDetailView(tripId: id)
                case .profile(let id):
                    UserProfileView(userId: id)
                case .commentsForTrip(let tripId, _):
                    // CommentsView only needs the trip id — no loader. Push
                    // presentation so it uses the parent NavigationStack
                    // instead of wrapping itself in another one (nested
                    // NavigationStacks break programmatic navigation).
                    CommentsView(tripId: tripId, presentation: .push)
                case .expensesForTrip(let tripId, _):
                    TripSectionLoader(tripId: tripId) { trip, canEdit in
                        ExpensesView(trip: trip, canEdit: canEdit)
                    }
                case .journalForTrip(let tripId, _):
                    TripSectionLoader(tripId: tripId) { trip, canEdit in
                        JournalView(trip: trip, canEdit: canEdit)
                    }
                case .pollsForTrip(let tripId, _):
                    TripSectionLoader(tripId: tripId) { trip, canEdit in
                        PollsView(trip: trip, canEdit: canEdit)
                    }
                }
            }
            .toolbar {
                if !viewModel.notifications.isEmpty && viewModel.unreadCount > 0 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            HapticFeedback.light()
                            Task { await viewModel.markAllAsRead() }
                        } label: {
                            Text("Read All")
                                .font(OuestTheme.Typography.caption)
                                .foregroundStyle(OuestTheme.Colors.brand)
                        }
                    }
                }
            }
            .task {
                await viewModel.loadNotifications()
                let status = await viewModel.checkPermissionStatus()
                if status == .notDetermined {
                    _ = await viewModel.requestPermission()
                }
                withAnimation(OuestTheme.Anim.smooth) {
                    contentAppeared = true
                }
            }
            .refreshable {
                contentAppeared = false
                await viewModel.loadNotifications()
                withAnimation(OuestTheme.Anim.smooth) {
                    contentAppeared = true
                }
            }
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(0..<8, id: \.self) { _ in
                    HStack(spacing: OuestTheme.Spacing.md) {
                        SkeletonView(width: 40, height: 40)
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: OuestTheme.Spacing.xs) {
                            SkeletonView(width: 200, height: 14)
                            SkeletonView(width: 140, height: 12)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, OuestTheme.Spacing.xl)
                    .padding(.vertical, OuestTheme.Spacing.md)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        EmptyStateView(
            icon: "bell",
            title: "No Activity",
            message: "You'll see trip updates, likes, and comments here."
        )
    }

    // MARK: - Notifications List

    private var notificationsList: some View {
        List {
            ForEach(Array(viewModel.notifications.enumerated()), id: \.element.id) { index, notification in
                notificationRow(notification, index: index)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            HapticFeedback.light()
                            Task { await viewModel.deleteNotification(notification) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Notification Row

    private func notificationRow(_ notification: AppNotification, index: Int) -> some View {
        Button {
            HapticFeedback.light()
            Task { await viewModel.markAsRead(notification) }

            // Navigate to the relevant screen
            if let nav = notificationNav(for: notification) {
                path.append(nav)
            }
        } label: {
            HStack(alignment: .top, spacing: OuestTheme.Spacing.md) {
                // Type icon
                Image(systemName: notification.type.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(notification.type.color)
                    .clipShape(Circle())

                // Text content
                VStack(alignment: .leading, spacing: OuestTheme.Spacing.xxs) {
                    Text(notification.title)
                        .font(OuestTheme.Typography.sectionTitle)
                        .foregroundStyle(OuestTheme.Colors.textPrimary)

                    Text(notification.body)
                        .font(OuestTheme.Typography.caption)
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                        .lineLimit(2)

                    if let date = notification.createdAt {
                        Text(date, style: .relative)
                            .font(OuestTheme.Typography.micro)
                            .foregroundStyle(OuestTheme.Colors.textSecondary.opacity(0.7))
                    }
                }

                Spacer()

                // Unread indicator
                if !notification.isRead {
                    Circle()
                        .fill(OuestTheme.Colors.brand)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal, OuestTheme.Spacing.xl)
            .padding(.vertical, OuestTheme.Spacing.md)
            .background(notification.isRead ? Color.clear : OuestTheme.Colors.brand.opacity(0.04))
        }
        .buttonStyle(.plain)
        .fadeSlideIn(isVisible: contentAppeared, delay: Double(index) * 0.03)
    }

    // MARK: - Helpers

    /// Map a notification to a navigation destination. Each notification type
    /// lands the user on the most relevant screen — not just the trip detail.
    private func notificationNav(for notification: AppNotification) -> NotificationNav? {
        switch notification.type {
        case .newFollower:
            return notification.followerId.map { .profile(id: $0) }

        case .newExpense:
            guard let tripId = notification.tripId else { return nil }
            return .expensesForTrip(
                tripId: tripId,
                focusExpenseId: notification.expenseId
            )

        case .newComment:
            // Trip-level comments live in CommentsView (the same surface used
            // by Explore when you tap the comment bubble on a feed card).
            guard let tripId = notification.tripId else { return nil }
            return .commentsForTrip(
                tripId: tripId,
                focusCommentId: notification.commentId
            )

        case .newJournalEntry:
            guard let tripId = notification.tripId else { return nil }
            return .journalForTrip(
                tripId: tripId,
                focusEntryId: notification.entryId
            )

        case .newPoll:
            guard let tripId = notification.tripId else { return nil }
            return .pollsForTrip(
                tripId: tripId,
                focusPollId: notification.pollId
            )

        case .tripInvite, .tripLiked:
            // No more-specific destination — land on the trip itself.
            return notification.tripId.map { .trip(id: $0) }
        }
    }
}

// MARK: - Trip Section Loader

/// Loads a Trip by id and renders an arbitrary section view that needs the
/// full Trip object (Expenses / Journal / Polls). Used for notification deep
/// links where we only have the tripId but the destination view needs the
/// fully-loaded trip + canEdit flag.
private struct TripSectionLoader<Content: View>: View {
    let tripId: UUID
    let content: (_ trip: Trip, _ canEdit: Bool) -> Content

    @Environment(AuthViewModel.self) private var authViewModel
    @State private var trip: Trip?
    @State private var canEdit: Bool = false
    @State private var errorMessage: String?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let trip {
                content(trip, canEdit)
            } else if let errorMessage {
                ErrorView(message: errorMessage) {
                    Task { await load() }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            // Avoid reloading if the user back-navigates and returns.
            if trip == nil { await load() }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let loadedTrip = try await TripService.fetchTrip(id: tripId)
            // Compute canEdit from the current user's membership.
            let userId = authViewModel.currentUser?.id
            let members = (try? await TripService.fetchMembers(tripId: tripId)) ?? []
            let myRole = members.first(where: { $0.userId == userId })?.role
            canEdit = myRole?.canEdit ?? false
            trip = loadedTrip
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
