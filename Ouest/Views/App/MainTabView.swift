import SwiftUI

struct MainTabView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var selectedTab = 0
    @State private var showCreateTrip = false
    @State private var notificationsVM = NotificationsViewModel()

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

            // Floating pill tab bar
            floatingTabBar
        }
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
