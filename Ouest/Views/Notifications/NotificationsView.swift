import SwiftUI

struct NotificationsView: View {
    @Bindable var viewModel: NotificationsViewModel
    @State private var contentAppeared = false

    var body: some View {
        NavigationStack {
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
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(viewModel.notifications.enumerated()), id: \.element.id) { index, notification in
                    notificationRow(notification, index: index)
                }
            }
        }
    }

    // MARK: - Notification Row

    private func notificationRow(_ notification: AppNotification, index: Int) -> some View {
        Button {
            HapticFeedback.light()
            Task { await viewModel.markAsRead(notification) }
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
}
