import SwiftUI

@main
struct OuestApp: App {
    // MARK: - App State

    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(appState.repositories)
                .environmentObject(appState.themeManager)
                .preferredColorScheme(appState.themeManager.colorScheme)
        }
    }
}

// MARK: - App State (Centralized State Management)

@MainActor
final class AppState: ObservableObject {
    // MARK: - Core Managers

    let repositories: RepositoryProvider
    let themeManager: ThemeManager

    // MARK: - Auth ViewModel

    @Published private(set) var authViewModel: AuthViewModel

    // MARK: - Demo Mode

    @Published var isDemoMode: Bool = false {
        didSet {
            if oldValue != isDemoMode {
                repositories.isDemoMode = isDemoMode
                setupAuthViewModel()
            }
        }
    }

    // MARK: - Initialization

    init() {
        // Initialize repositories
        let repos = RepositoryProvider(isDemoMode: false)
        self.repositories = repos
        self.themeManager = ThemeManager()

        // Initialize auth view model
        self.authViewModel = AuthViewModel(
            authRepository: repos.authRepository,
            profileRepository: repos.profileRepository
        )

        // Load demo mode preference
        self.isDemoMode = UserDefaults.standard.bool(forKey: "isDemoMode")
    }

    // MARK: - Setup

    private func setupAuthViewModel() {
        authViewModel = AuthViewModel(
            authRepository: repositories.authRepository,
            profileRepository: repositories.profileRepository
        )
    }

    // MARK: - Demo Mode Toggle

    func toggleDemoMode() {
        isDemoMode.toggle()
        UserDefaults.standard.set(isDemoMode, forKey: "isDemoMode")
    }
}

// MARK: - Root View

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            switch appState.authViewModel.state {
            case .loading:
                LoadingView()
            case .authenticated:
                MainTabView()
            case .unauthenticated:
                if appState.isDemoMode {
                    // In demo mode, skip auth
                    MainTabView()
                } else {
                    AuthNavigationView()
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.authViewModel.state)
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var body: some View {
        ZStack {
            OuestTheme.Colors.background
                .ignoresSafeArea()

            VStack(spacing: OuestTheme.Spacing.md) {
                // Animated logo
                Image(systemName: "airplane.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(OuestTheme.Gradients.primary)

                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: OuestTheme.Colors.primary))
                    .scaleEffect(1.2)

                Text("Loading...")
                    .font(OuestTheme.Fonts.body)
                    .foregroundColor(OuestTheme.Colors.textSecondary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    RootView()
        .environmentObject(AppState())
}
