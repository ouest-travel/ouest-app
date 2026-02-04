import Foundation
import SwiftUI

// MARK: - Repository Provider (Dependency Injection)

/// Provides repository instances based on demo mode state
@MainActor
final class RepositoryProvider: ObservableObject {
    @Published var isDemoMode: Bool = false {
        didSet {
            // Recreate repositories when demo mode changes
            setupRepositories()
        }
    }

    // Repository instances
    private(set) var tripRepository: any TripRepositoryProtocol
    private(set) var expenseRepository: any ExpenseRepositoryProtocol
    private(set) var profileRepository: any ProfileRepositoryProtocol

    init(isDemoMode: Bool = false) {
        self.isDemoMode = isDemoMode

        // Initialize with appropriate repositories
        if isDemoMode {
            self.tripRepository = MockTripRepository()
            self.expenseRepository = MockExpenseRepository()
            self.profileRepository = MockProfileRepository()
        } else {
            self.tripRepository = TripRepository()
            self.expenseRepository = ExpenseRepository()
            self.profileRepository = ProfileRepository()
        }
    }

    private func setupRepositories() {
        if isDemoMode {
            tripRepository = MockTripRepository()
            expenseRepository = MockExpenseRepository()
            profileRepository = MockProfileRepository()
        } else {
            tripRepository = TripRepository()
            expenseRepository = ExpenseRepository()
            profileRepository = ProfileRepository()
        }
    }
}

// MARK: - Environment Key

struct RepositoryProviderKey: EnvironmentKey {
    static let defaultValue = RepositoryProvider()
}

extension EnvironmentValues {
    var repositoryProvider: RepositoryProvider {
        get { self[RepositoryProviderKey.self] }
        set { self[RepositoryProviderKey.self] = newValue }
    }
}

// MARK: - View Extension

extension View {
    func withRepositories(_ provider: RepositoryProvider) -> some View {
        self.environment(\.repositoryProvider, provider)
    }
}
