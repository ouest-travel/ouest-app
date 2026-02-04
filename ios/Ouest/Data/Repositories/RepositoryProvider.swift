import Foundation
import SwiftUI

// MARK: - Repository Provider (Dependency Injection Container)

/// Central dependency injection container for all repositories
/// Automatically switches between real and mock implementations based on demo mode
@MainActor
final class RepositoryProvider: ObservableObject {
    @Published var isDemoMode: Bool = false {
        didSet {
            if oldValue != isDemoMode {
                setupRepositories()
            }
        }
    }

    // MARK: - Repository Instances

    private(set) var authRepository: any AuthRepositoryProtocol
    private(set) var tripRepository: any TripRepositoryProtocol
    private(set) var expenseRepository: any ExpenseRepositoryProtocol
    private(set) var profileRepository: any ProfileRepositoryProtocol
    private(set) var chatRepository: any ChatRepositoryProtocol
    private(set) var tripMemberRepository: any TripMemberRepositoryProtocol
    private(set) var savedItineraryRepository: any SavedItineraryRepositoryProtocol

    // MARK: - Initialization

    init(isDemoMode: Bool = false) {
        self.isDemoMode = isDemoMode

        // Initialize with appropriate repositories
        if isDemoMode {
            self.authRepository = MockAuthRepository()
            self.tripRepository = MockTripRepository()
            self.expenseRepository = MockExpenseRepository()
            self.profileRepository = MockProfileRepository()
            self.chatRepository = MockChatRepository()
            self.tripMemberRepository = MockTripMemberRepository()
            self.savedItineraryRepository = MockSavedItineraryRepository()
        } else {
            self.authRepository = AuthRepository()
            self.tripRepository = TripRepository()
            self.expenseRepository = ExpenseRepository()
            self.profileRepository = ProfileRepository()
            self.chatRepository = ChatRepository()
            self.tripMemberRepository = TripMemberRepository()
            self.savedItineraryRepository = SavedItineraryRepository()
        }
    }

    // MARK: - Repository Setup

    private func setupRepositories() {
        if isDemoMode {
            authRepository = MockAuthRepository()
            tripRepository = MockTripRepository()
            expenseRepository = MockExpenseRepository()
            profileRepository = MockProfileRepository()
            chatRepository = MockChatRepository()
            tripMemberRepository = MockTripMemberRepository()
            savedItineraryRepository = MockSavedItineraryRepository()
        } else {
            authRepository = AuthRepository()
            tripRepository = TripRepository()
            expenseRepository = ExpenseRepository()
            profileRepository = ProfileRepository()
            chatRepository = ChatRepository()
            tripMemberRepository = TripMemberRepository()
            savedItineraryRepository = SavedItineraryRepository()
        }
    }
}

// MARK: - Environment Key

private struct RepositoryProviderKey: EnvironmentKey {
    @MainActor static let defaultValue = RepositoryProvider()
}

extension EnvironmentValues {
    var repositories: RepositoryProvider {
        get { self[RepositoryProviderKey.self] }
        set { self[RepositoryProviderKey.self] = newValue }
    }
}

// MARK: - View Extension

extension View {
    func withRepositories(_ provider: RepositoryProvider) -> some View {
        self.environment(\.repositories, provider)
    }
}
