import Foundation
import Supabase

/// The product moments we count. The raw value is the `name` column in
/// `usage_events` (migration 00036), which only accepts lowercase and
/// underscores.
///
/// Saves, likes and comments are not here on purpose: `saved_trips`,
/// `trip_likes` and `trip_comments` already record them with a timestamp.
enum UsageEvent: String, CaseIterable, Sendable {
    /// The Explore tab was selected.
    case exploreOpened = "explore_opened"
    /// A trip was opened from the Explore feed.
    case exploreTripOpened = "explore_trip_opened"
    /// A public trip was copied into the user's own trips.
    case tripCloned = "trip_cloned"
    /// The app was opened from a shared trip link.
    case shareLinkOpened = "share_link_opened"
    /// Home offered to share a finished trip with the community.
    case sharePromptShown = "share_prompt_shown"
    /// The user said yes to that offer and the trip went public.
    case sharePromptAccepted = "share_prompt_accepted"
}

/// One row for `usage_events`. There is no user id: the database fills it in
/// from the session, so a client can only ever record itself.
struct UsageEventPayload: Encodable, Sendable {
    let name: String
    let tripId: UUID?

    enum CodingKeys: String, CodingKey {
        case name
        case tripId = "trip_id"
    }
}

/// Records usage events in our own Supabase project. No third-party SDK.
enum UsageService {

    /// Fire and forget. Counting must never slow down or break what the
    /// person is doing, so a failed write is dropped (and logged in debug).
    static func track(_ event: UsageEvent, tripId: UUID? = nil) {
        Task {
            do {
                try await SupabaseManager.client
                    .from("usage_events")
                    .insert(UsageEventPayload(name: event.rawValue, tripId: tripId))
                    .execute()
            } catch {
                #if DEBUG
                print("[Usage] \(event.rawValue) not recorded: \(error)")
                #endif
            }
        }
    }
}
