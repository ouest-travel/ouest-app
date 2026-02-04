import Foundation

// MARK: - Profile Repository Implementation (Local Storage)

final class ProfileRepository: ProfileRepositoryProtocol {
    private let userDefaultsKey = "ouest_profiles"

    init() {}

    func getProfile(userId: String) async throws -> Profile? {
        let profiles = loadProfiles()
        return profiles[userId]
    }

    func createProfile(userId: String, email: String, displayName: String) async throws -> Profile {
        let handle = generateHandle(from: displayName, email: email)

        let profile = Profile(
            id: userId,
            email: email,
            displayName: displayName,
            handle: handle,
            avatarUrl: nil,
            createdAt: Date()
        )

        var profiles = loadProfiles()
        profiles[userId] = profile
        saveProfiles(profiles)

        return profile
    }

    func updateProfile(userId: String, displayName: String?, handle: String?, avatarUrl: String?) async throws -> Profile {
        var profiles = loadProfiles()

        guard var profile = profiles[userId] else {
            throw ProfileRepositoryError.profileNotFound
        }

        // Create updated profile
        profile = Profile(
            id: profile.id,
            email: profile.email,
            displayName: displayName ?? profile.displayName,
            handle: handle ?? profile.handle,
            avatarUrl: avatarUrl ?? profile.avatarUrl,
            createdAt: profile.createdAt
        )

        profiles[userId] = profile
        saveProfiles(profiles)

        return profile
    }

    func getProfileStats(userId: String) async throws -> ProfileStats {
        // For local storage, return empty stats
        // These would be calculated from actual trip data in a real implementation
        return ProfileStats.empty
    }

    // MARK: - Private Storage Methods

    private func loadProfiles() -> [String: Profile] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return [:]
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode([String: Profile].self, from: data)
        } catch {
            print("Failed to decode profiles: \(error)")
            return [:]
        }
    }

    private func saveProfiles(_ profiles: [String: Profile]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(profiles)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            print("Failed to save profiles: \(error)")
        }
    }

    private func generateHandle(from displayName: String, email: String) -> String {
        let base = displayName.isEmpty
            ? email.components(separatedBy: "@").first ?? "user"
            : displayName

        let handle = base
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .filter { $0.isLetter || $0.isNumber }

        let suffix = String(Int.random(in: 100...999))
        return "\(handle)\(suffix)"
    }
}

// MARK: - Mock Profile Repository

final class MockProfileRepository: ProfileRepositoryProtocol {
    func getProfile(userId: String) async throws -> Profile? {
        return DemoModeManager.demoProfile
    }

    func createProfile(userId: String, email: String, displayName: String) async throws -> Profile {
        return Profile(
            id: userId,
            email: email,
            displayName: displayName,
            handle: "\(displayName.lowercased().replacingOccurrences(of: " ", with: ""))123",
            avatarUrl: nil,
            createdAt: Date()
        )
    }

    func updateProfile(userId: String, displayName: String?, handle: String?, avatarUrl: String?) async throws -> Profile {
        try await Task.sleep(nanoseconds: 500_000_000)
        return DemoModeManager.demoProfile
    }

    func getProfileStats(userId: String) async throws -> ProfileStats {
        return ProfileStats.demo
    }
}

// MARK: - Profile Repository Errors

enum ProfileRepositoryError: LocalizedError {
    case profileNotFound
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .profileNotFound:
            return "Profile not found."
        case .saveFailed:
            return "Failed to save profile."
        }
    }
}
