import SwiftUI

struct MainTabView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var selectedTab = 0
    @State private var showCreateTrip = false
    @State private var notificationsVM = NotificationsViewModel()
    /// Observes the shared AI run state so the floating bubble can persist
    /// across tabs and across navigation pushes — wherever the user is in the
    /// app, they see progress until the generation completes.
    @State private var aiRun = AIRunCoordinator.shared

    var body: some View {
        ZStack(alignment: .bottom) {
            // Main content
            Group {
                switch selectedTab {
                case 0: HomeView()
                case 1: ExploreView()
                case 3: NotificationsView(viewModel: notificationsVM)
                case 4: ProfileView()
                default: HomeView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // AI run bubble — sits above the tab bar, visible app-wide while
            // a generation / import is in flight or has just failed.
            if aiRun.isRunning || aiRun.errorMessage != nil {
                aiRunBubble
                    .padding(.horizontal, OuestTheme.Spacing.md)
                    .padding(.bottom, OuestTheme.Layout.tabBarInset)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Floating pill tab bar
            floatingTabBar
        }
        .animation(OuestTheme.Anim.smooth, value: aiRun.isRunning)
        .animation(OuestTheme.Anim.smooth, value: aiRun.errorMessage)
        .sheet(isPresented: $showCreateTrip) {
            CreateTripView()
                .environment(authViewModel)
        }
        .task {
            if let userId = authViewModel.currentUser?.id {
                await notificationsVM.startListening(userId: userId)
            } else {
                await notificationsVM.refreshUnreadCount()
            }
        }
    }

    // MARK: - Floating Pill Tab Bar

    private var floatingTabBar: some View {
        GooeyTabBar(
            items: [
                .init(id: 0, icon: "house", filledIcon: "house.fill", label: "Home"),
                .init(id: 1, icon: "safari", filledIcon: "safari.fill", label: "Explore"),
                .init(id: 3, icon: "bell", filledIcon: "bell.fill", label: "Activity",
                      badge: notificationsVM.unreadCount),
                .init(id: 4, icon: "person", filledIcon: "person.fill", label: "Profile"),
            ],
            selection: $selectedTab
        ) {
            createButton
        }
        .padding(.horizontal, OuestTheme.Spacing.xl)
        .padding(.bottom, OuestTheme.Spacing.sm)
    }

    // MARK: - AI Run Bubble

    /// Visible globally (above the tab bar) whenever the shared coordinator
    /// reports an in-flight or failed AI run. Tapping it does nothing for now
    /// — the actual progress view lives inside the trip's Itinerary screen.
    /// We just want to give the user constant visual confirmation that work
    /// is happening, even if they wander off to Explore or Profile.
    @ViewBuilder
    private var aiRunBubble: some View {
        if aiRun.isRunning {
            HStack(spacing: OuestTheme.Spacing.sm) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.small)
                    .tint(.white)

                VStack(alignment: .leading, spacing: 0) {
                    Text("Building your itinerary…")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    if let title = aiRun.tripTitle {
                        Text(title)
                            .font(OuestTheme.Typography.micro)
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "sparkles")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(.horizontal, OuestTheme.Spacing.lg)
            .padding(.vertical, OuestTheme.Spacing.sm)
            .frame(maxWidth: .infinity)
            .background(OuestTheme.Colors.brandFill) // 15pt white label needs solid fill for contrast
            .clipShape(Capsule())
            .ouestElevation(.md)
            .accessibilityLabel("AI is building your itinerary in the background")
        } else if let error = aiRun.errorMessage {
            HStack(spacing: OuestTheme.Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 0) {
                    Text("Couldn't generate itinerary")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(error)
                        .font(OuestTheme.Typography.micro)
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Button {
                    HapticFeedback.light()
                    withAnimation(OuestTheme.Anim.smooth) {
                        aiRun.clearError()
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(.white.opacity(0.18))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss error")
            }
            .padding(.horizontal, OuestTheme.Spacing.md)
            .padding(.vertical, OuestTheme.Spacing.sm)
            .frame(maxWidth: .infinity)
            .background(OuestTheme.Colors.error)
            .clipShape(Capsule())
            .ouestElevation(.md)
        }
    }

    private var createButton: some View {
        Button {
            HapticFeedback.medium()
            showCreateTrip = true
        } label: {
            Image(systemName: "plus")
                .font(OuestTheme.Icon.control.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(OuestTheme.Colors.decorGradient) // no label — decorative gradient is safe
                .clipShape(Circle())
                .ouestElevation(.md)
                .accessibilityLabel("New trip")
        }
        .buttonStyle(ScaledButtonStyle(scale: 0.9))
    }
}

#Preview {
    MainTabView()
        .environment(AuthViewModel())
}
