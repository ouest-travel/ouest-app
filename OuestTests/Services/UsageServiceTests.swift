import Testing
import Foundation
@testable import Ouest

@Suite("UsageService")
struct UsageServiceTests {

    // A failed write is dropped silently by design, so an event the database
    // would reject just never gets counted and nobody notices. The table
    // (migration 00036) only accepts names matching ^[a-z_]{1,40}$.
    @Test("Every event name is one the usage_events table accepts")
    func eventNamesFitTheTable() {
        for event in UsageEvent.allCases {
            #expect(event.rawValue.wholeMatch(of: /[a-z_]{1,40}/) != nil, "\(event.rawValue)")
        }
    }

    // The database stamps the user from the session. If the app ever sent a
    // user id, the insert policy would be the only thing stopping one
    // account from recording activity as another.
    @Test("An event carries its name and trip, and never a user id")
    func payloadShape() throws {
        let tripId = UUID()
        let data = try JSONEncoder().encode(UsageEventPayload(name: UsageEvent.tripCloned.rawValue, tripId: tripId))
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: String])
        #expect(json == ["name": "trip_cloned", "trip_id": tripId.uuidString])
    }
}
