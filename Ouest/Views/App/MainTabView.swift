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

    private let tabs: [(icon: String, filledIcon: String, label: String)] = [
        ("house", "house.fill", "Home"),
        ("safari", "safari.fill", "Explore"),
        ("bell", "bell.fill", "Activity"),
        ("person", "person.fill", "Profile"),
    ]

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
                    .padding(.bottom, 84) // Clear the floating tab bar
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
        HStack(spacing: 0) {
            // Home & Explore tabs
            ForEach(0..<2, id: \.self) { index in
                tabButton(index: index)
            }

            // Create button (gradient circle)
            createButton
                .padding(.horizontal, OuestTheme.Spacing.sm)

            // Activity & Profile tabs
            ForEach(2..<4, id: \.self) { index in
                tabButton(index: index)
            }
        }
        .padding(.horizontal, OuestTheme.Spacing.lg)
        .padding(.vertical, OuestTheme.Spacing.sm)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(OuestTheme.Shadow.lg)
        .padding(.horizontal, OuestTheme.Spacing.xl)
        .padding(.bottom, OuestTheme.Spacing.sm)
    }

    private func tabButton(index: Int) -> some View {
        let tab = tabs[index]
        // Map tab array index to actual tab value: 0,1 → 0,1 and 2,3 → 3,4
        let tabValue = index < 2 ? index : index + 1

        return Button {
            HapticFeedback.light()
            withAnimation(OuestTheme.Anim.quick) {
                selectedTab = tabValue
            }
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    Image(systemName: selectedTab == tabValue ? tab.filledIcon : tab.icon)
                        .font(.system(size: 20))
                        .foregroundStyle(selectedTab == tabValue ? OuestTheme.Colors.brand : OuestTheme.Colors.textSecondary)

                    // Notification badge
                    if tabValue == 3 && notificationsVM.unreadCount > 0 {
                        Text("\(min(notificationsVM.unreadCount, 99))")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(OuestTheme.Colors.error)
                            .clipShape(Capsule())
                            .offset(x: 10, y: -8)
                    }
                }

                // Active dot indicator
                Circle()
                    .fill(OuestTheme.Colors.brand)
                    .frame(width: 4, height: 4)
                    .opacity(selectedTab == tabValue ? 1 : 0)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
            .background(OuestTheme.Colors.brandGradient)
            .clipShape(Capsule())
            .shadow(OuestTheme.Shadow.md)
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
            .shadow(OuestTheme.Shadow.md)
        }
    }

    private var createButton: some View {
        Button {
            HapticFeedback.medium()
            showCreateTrip = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(OuestTheme.Colors.brandGradient)
                .clipShape(Circle())
                .shadow(OuestTheme.Shadow.md)
        }
        .buttonStyle(ScaledButtonStyle(scale: 0.9))
    }
}

#Preview {
    MainTabView()
        .environment(AuthViewModel())
}
