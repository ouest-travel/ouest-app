import Testing
import Foundation
@testable import Ouest

@Suite("SharePrompt")
struct SharePromptTests {

    private let me = UUID()
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()
    private var now: Date { date(2026, 11, 12, hour: 9) }

    private func candidate(in trips: [Trip], dismissed: Set<UUID> = []) -> Trip? {
        SharePrompt.candidate(in: trips, userId: me, dismissed: dismissed, now: now, calendar: calendar)
    }

    // Explore only lists trips that are over, so this is the first moment
    // sharing does anything. Asking earlier would publish a plan in progress.
    @Test("A trip is offered once it is over, not on its last day")
    func onlyFinishedTrips() {
        #expect(candidate(in: [trip(end: date(2026, 11, 11))]) != nil, "ended yesterday")
        #expect(candidate(in: [trip(end: date(2026, 11, 12))]) == nil, "last day is still the trip")
        #expect(candidate(in: [trip(end: date(2026, 12, 1))]) == nil, "not started or under way")
        #expect(candidate(in: [trip(end: nil)]) == nil, "no dates, so Explore would never list it")
    }

    // Going public shows the whole group's itinerary, photos and expenses to
    // strangers. That is the creator's decision, not any member's.
    @Test("Only the person who created the trip is asked")
    func onlyTheCreator() {
        let someoneElses = trip(end: date(2026, 11, 10), createdBy: UUID())
        #expect(candidate(in: [someoneElses]) == nil)
    }

    @Test("A trip that is already public is not offered")
    func skipsPublicTrips() {
        #expect(candidate(in: [trip(end: date(2026, 11, 10), isPublic: true)]) == nil)
    }

    // "Not now" has to stick, or the card becomes a nag on every launch.
    @Test("A declined trip is never offered again")
    func respectsNotNow() {
        let declined = trip(end: date(2026, 11, 10))
        #expect(candidate(in: [declined], dismissed: [declined.id]) == nil)
    }

    // Someone with years of history should not be walked through every old
    // trip one launch at a time.
    @Test("Trips that ended long ago are left alone")
    func ignoresOldTrips() {
        #expect(candidate(in: [trip(end: date(2026, 10, 13))]) != nil, "30 days ago is still in")
        #expect(candidate(in: [trip(end: date(2026, 10, 12))]) == nil, "31 days ago is out")
    }

    @Test("With several finished trips, the most recent one is offered first")
    func mostRecentFirst() {
        let older = trip(end: date(2026, 10, 20))
        let newer = trip(end: date(2026, 11, 8))
        #expect(candidate(in: [older, newer])?.id == newer.id)
        #expect(candidate(in: [older, newer], dismissed: [newer.id])?.id == older.id, "then the next one")
    }

    @Test("Declined trips are remembered per user")
    func dismissalsPersistPerUser() {
        let user = UUID(), otherUser = UUID(), tripId = UUID()
        defer {
            for id in [user, otherUser] {
                UserDefaults.standard.removeObject(forKey: "sharePromptDismissed.\(id.uuidString.lowercased())")
            }
        }
        SharePrompt.dismiss(tripId, for: user)
        #expect(SharePrompt.dismissed(for: user) == [tripId])
        #expect(SharePrompt.dismissed(for: otherUser).isEmpty, "a second account on the phone starts clean")
    }

    // MARK: Fixtures

    private func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    private func trip(end: Date?, createdBy: UUID? = nil, isPublic: Bool = false) -> Trip {
        Trip(
            id: UUID(), createdBy: createdBy ?? me, title: "Trip", destination: "Lisbon",
            description: nil, coverImageUrl: nil, startDate: end?.addingTimeInterval(-5 * 86_400), endDate: end,
            status: .planning, isPublic: isPublic, budget: nil, currency: nil, votingEnabled: nil,
            tags: nil, countryCodes: nil, coverAttribution: nil, coverAttributionUrl: nil,
            createdAt: nil, updatedAt: nil
        )
    }
}
