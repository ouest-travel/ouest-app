import Foundation
import SwiftUI

// MARK: - Profile ViewModel

@MainActor
final class ProfileViewModel: ObservableObject {
    // MARK: - Published State

    @Published private(set) var profile: Profile?
    @Published private(set) var stats: ProfileStats = .empty
    @Published private(set) var savedItems: [SavedItineraryItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?

    // MARK: - Dependencies

    private let profileRepository: any ProfileRepositoryProtocol
    private let savedItineraryRepository: any SavedItineraryRepositoryProtocol
    private let userId: String

    // MARK: - Initialization

    init(
        profileRepository: any ProfileRepositoryProtocol,
        savedItineraryRepository: any SavedItineraryRepositoryProtocol,
        userId: String,
        profile: Profile? = nil
    ) {
        self.profileRepository = profileRepository
        self.savedItineraryRepository = savedItineraryRepository
        self.userId = userId
        self.profile = profile
    }

    // MARK: - Data Loading

    func loadData() async {
        isLoading = true
        error = nil

        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadProfile() }
            group.addTask { await self.loadStats() }
            group.addTask { await self.loadSavedItems() }
        }

        isLoading = false
    }

    private func loadProfile() async {
        do {
            profile = try await profileRepository.getProfile(userId: userId)
        } catch {
            print("Failed to load profile: \(error)")
        }
    }

    private func loadStats() async {
        do {
            stats = try await profileRepository.getProfileStats(userId: userId)
        } catch {
            print("Failed to load stats: \(error)")
        }
    }

    private func loadSavedItems() async {
        do {
            savedItems = try await savedItineraryRepository.getSavedItems(userId: userId)
        } catch {
            print("Failed to load saved items: \(error)")
        }
    }

    func refresh() async {
        await loadData()
    }

    // MARK: - Profile Actions

    func updateProfile(displayName: String?, handle: String?, avatarUrl: String?) async {
        isLoading = true
        error = nil

        do {
            profile = try await profileRepository.updateProfile(
                userId: userId,
                displayName: displayName,
                handle: handle,
                avatarUrl: avatarUrl
            )
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Saved Itinerary Actions

    func removeSavedItem(_ item: SavedItineraryItem) async {
        do {
            try await savedItineraryRepository.removeItem(id: item.id)
            savedItems.removeAll { $0.id == item.id }
            // Update stats
            stats = ProfileStats(
                countriesVisited: stats.countriesVisited,
                totalTrips: stats.totalTrips,
                memories: stats.memories,
                savedItineraries: savedItems.count
            )
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Error Handling

    func clearError() {
        error = nil
    }
}
