import Foundation

/// The "share this trip with the community?" ask on Home.
///
/// Explore only lists trips that are public and already over, but the public
/// switch lives in the create and edit forms, where it is decided weeks
/// before the trip could ever appear. This asks again at the moment the trip
/// becomes eligible.
enum SharePrompt {

    /// How long after a trip ends we still ask. Past this the moment is gone,
    /// and it keeps someone with years of old trips from being asked about
    /// each one in turn.
    static let windowDays = 30

    /// The trip to ask about, if any: the most recently finished one that
    /// this person created, is still private, and has not been declined.
    ///
    /// Only the creator is asked. Editors can flip the switch too, but
    /// putting a group's trip in front of strangers is the owner's call.
    static func candidate(
        in trips: [Trip],
        userId: UUID,
        dismissed: Set<UUID>,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Trip? {
        let today = calendar.startOfDay(for: now)
        guard let earliest = calendar.date(byAdding: .day, value: -windowDays, to: today) else { return nil }

        return trips
            .filter { trip in
                guard trip.createdBy == userId, !trip.isPublic, !dismissed.contains(trip.id),
                      let end = trip.endDate else { return false }
                // The last day of the trip is still the trip.
                return end < today && end >= earliest
            }
            .max { ($0.endDate ?? .distantPast) < ($1.endDate ?? .distantPast) }
    }

    // MARK: - Declined trips

    // Stored per user per device, like AIConsent. "Not now" is remembered so
    // the same trip is never asked about twice on this phone.

    private static func key(for userId: UUID) -> String {
        "sharePromptDismissed.\(userId.uuidString.lowercased())"
    }

    static func dismissed(for userId: UUID) -> Set<UUID> {
        let stored = UserDefaults.standard.stringArray(forKey: key(for: userId)) ?? []
        return Set(stored.compactMap(UUID.init(uuidString:)))
    }

    static func dismiss(_ tripId: UUID, for userId: UUID) {
        let all = dismissed(for: userId).union([tripId])
        UserDefaults.standard.set(all.map(\.uuidString), forKey: key(for: userId))
    }

    // MARK: - Counting

    /// Trips already counted as "shown" since launch. Home is rebuilt on
    /// every tab switch, and one prompt should not count once per visit.
    @MainActor private static var counted: Set<UUID> = []

    @MainActor static func trackShown(_ trip: Trip) {
        guard counted.insert(trip.id).inserted else { return }
        UsageService.track(.sharePromptShown, tripId: trip.id)
    }
}
