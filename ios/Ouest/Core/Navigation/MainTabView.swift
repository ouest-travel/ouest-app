import SwiftUI

enum Tab: String, CaseIterable {
    case home = "Home"
    case guide = "Guide"
    case community = "Community"
    case you = "You"

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .guide: return "book.fill"
        case .community: return "person.3.fill"
        case .you: return "person.fill"
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab: Tab = .home
    @Namespace private var animation

    var body: some View {
        VStack(spacing: 0) {
            // Content
            TabContent(selectedTab: selectedTab)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Custom Tab Bar
            CustomTabBar(selectedTab: $selectedTab, animation: animation)
        }
        .background(OuestTheme.Colors.background)
    }
}

struct TabContent: View {
    let selectedTab: Tab

    var body: some View {
        switch selectedTab {
        case .home:
            HomeView()
        case .guide:
            GuideView()
        case .community:
            CommunityView()
        case .you:
            ProfileView()
        }
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: Tab
    var animation: Namespace.ID

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                TabBarButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    animation: animation
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 12)
        .padding(.bottom, 28)
        .background(
            OuestTheme.Colors.cardBackground
                .shadow(color: Color.black.opacity(0.05), radius: 10, y: -5)
        )
    }
}

struct TabBarButton: View {
    let tab: Tab
    let isSelected: Bool
    var animation: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    if isSelected {
                        Capsule()
                            .fill(OuestTheme.Gradients.primary)
                            .frame(width: 60, height: 32)
                            .matchedGeometryEffect(id: "TAB_BG", in: animation)
                    }

                    Image(systemName: tab.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(isSelected ? .white : OuestTheme.Colors.textSecondary)
                }
                .frame(height: 32)

                Text(tab.rawValue)
                    .font(OuestTheme.Fonts.caption)
                    .foregroundColor(isSelected ? OuestTheme.Colors.primary : OuestTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthManager())
        .environmentObject(DemoModeManager())
        .environmentObject(ThemeManager())
}
