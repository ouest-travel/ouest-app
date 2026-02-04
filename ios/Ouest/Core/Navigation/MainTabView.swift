import SwiftUI

// MARK: - Tab Enum

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

    var selectedIcon: String {
        icon // Same for now, could differentiate filled/outlined
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @EnvironmentObject var appState: AppState

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
        .ignoresSafeArea(.keyboard)
    }
}

// MARK: - Tab Content

struct TabContent: View {
    let selectedTab: Tab

    var body: some View {
        // Use switch to avoid keeping all views in memory
        Group {
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
        .transition(.opacity)
    }
}

// MARK: - Custom Tab Bar

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
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()

                    withAnimation(OuestTheme.Animation.spring) {
                        selectedTab = tab
                    }
                }
            }
        }
        .padding(.horizontal, OuestTheme.Spacing.xs)
        .padding(.top, OuestTheme.Spacing.sm)
        .padding(.bottom, 28) // Safe area
        .background(
            OuestTheme.Colors.cardBackground
                .shadow(color: Color.black.opacity(0.08), radius: 16, y: -4)
                .ignoresSafeArea()
        )
    }
}

// MARK: - Tab Bar Button

struct TabBarButton: View {
    let tab: Tab
    let isSelected: Bool
    var animation: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: OuestTheme.Spacing.xxs) {
                ZStack {
                    if isSelected {
                        Capsule()
                            .fill(OuestTheme.Gradients.primary)
                            .frame(width: 64, height: 36)
                            .matchedGeometryEffect(id: "TAB_BG", in: animation)
                            .shadow(OuestTheme.Shadow.sm)
                    }

                    Image(systemName: tab.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isSelected ? .white : OuestTheme.Colors.textTertiary)
                        .scaleEffect(isSelected ? 1.1 : 1.0)
                }
                .frame(height: 36)

                Text(tab.rawValue)
                    .font(OuestTheme.Fonts.caption)
                    .foregroundColor(isSelected ? OuestTheme.Colors.primary : OuestTheme.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(tab.rawValue)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Preview

#Preview {
    MainTabView()
        .environmentObject(AppState())
}
