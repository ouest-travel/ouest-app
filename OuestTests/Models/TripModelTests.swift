import Testing
import Foundation
@testable import Ouest

@Suite("Trip Model")
struct TripModelTests {

    // MARK: - Date Range Text

    @Test("dateRangeText formats same-month dates correctly")
    func sameMonthDateRange() {
        let trip = makeTrip(
            start: date(2025, 3, 15),
            end: date(2025, 3, 25)
        )
        let text = trip.dateRangeText
        #expect(text != nil)
        #expect(text!.contains("Mar"))
        #expect(text!.contains("15"))
        #expect(text!.contains("25"))
    }

    @Test("dateRangeText formats cross-month dates correctly")
    func crossMonthDateRange() {
        let trip = makeTrip(
            start: date(2025, 3, 28),
            end: date(2025, 4, 5)
        )
        let text = trip.dateRangeText
        #expect(text != nil)
        #expect(text!.contains("Mar"))
        #expect(text!.contains("Apr"))
    }

    @Test("dateRangeText returns nil when no start date")
    func noStartDate() {
        let trip = makeTrip(start: nil, end: nil)
        #expect(trip.dateRangeText == nil)
    }

    @Test("dateRangeText shows only start when no end date")
    func startOnlyDate() {
        let trip = makeTrip(start: date(2025, 6, 1), end: nil)
        let text = trip.dateRangeText
        #expect(text != nil)
        #expect(text!.contains("Jun"))
    }

    // MARK: - Duration

    @Test("durationDays calculates correctly for multi-day trip")
    func multiDayDuration() {
        let trip = makeTrip(
            start: date(2025, 3, 1),
            end: date(2025, 3, 7)
        )
        #expect(trip.durationDays == 7) // 7 days inclusive
    }

    @Test("durationDays is 1 for same-day trip")
    func sameDayDuration() {
        let trip = makeTrip(
            start: date(2025, 3, 1),
            end: date(2025, 3, 1)
        )
        #expect(trip.durationDays == 1)
    }

    @Test("durationDays is nil when dates are missing")
    func noDuration() {
        let trip = makeTrip(start: nil, end: nil)
        #expect(trip.durationDays == nil)
    }

    // MARK: - Trip Status

    @Test("TripStatus has correct labels")
    func statusLabels() {
        #expect(TripStatus.planning.label == "Planning")
        #expect(TripStatus.active.label == "Active")
        #expect(TripStatus.completed.label == "Completed")
    }

    @Test("TripStatus has icon names")
    func statusIcons() {
        for status in TripStatus.allCases {
            #expect(!status.icon.isEmpty)
        }
    }

    // MARK: - Member Role

    @Test("MemberRole canEdit is correct")
    func memberRolePermissions() {
        #expect(MemberRole.owner.canEdit == true)
        #expect(MemberRole.editor.canEdit == true)
        #expect(MemberRole.viewer.canEdit == false)
    }

    @Test("MemberRole has labels")
    func memberRoleLabels() {
        #expect(MemberRole.owner.label == "Owner")
        #expect(MemberRole.editor.label == "Editor")
        #expect(MemberRole.viewer.label == "Viewer")
    }

    // MARK: - UpdateTripPayload encoding

    // PostgREST treats an omitted key as "leave unchanged" and an explicit
    // null as "clear". A partial update (e.g. status only) must not touch
    // other columns, while Edit Trip toggling dates/budget off must clear them.

    @Test("UpdateTripPayload omits nil fields so partial updates leave other columns alone")
    func payloadOmitsNilByDefault() throws {
        let data = try JSONEncoder().encode(UpdateTripPayload(status: .planning))
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json.keys.sorted() == ["status"])
    }

    @Test("UpdateTripPayload sends explicit null for fields the user cleared")
    func payloadEncodesExplicitNulls() throws {
        let payload = UpdateTripPayload(
            title: "Lisbon",
            nullFields: [.startDate, .endDate, .budget]
        )
        let data = try JSONEncoder().encode(payload)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["title"] as? String == "Lisbon")
        #expect(json["start_date"] is NSNull)
        #expect(json["end_date"] is NSNull)
        #expect(json["budget"] is NSNull)
        #expect(json["currency"] == nil)
    }

    @Test("UpdateTripPayload can clear a stock cover's credit when the user uploads their own photo")
    func payloadClearsStockAttribution() throws {
        // A stale Unsplash credit under a user's own photo would misattribute
        // it — and `coverAttribution != nil` is what marks a cover as
        // replaceable stock, so leaving it set would let the next
        // destination edit silently overwrite the user's upload.
        let payload = UpdateTripPayload(
            coverImageUrl: "https://example.com/mine.jpg",
            nullFields: [.coverAttribution, .coverAttributionUrl]
        )
        let data = try JSONEncoder().encode(payload)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["cover_image_url"] as? String == "https://example.com/mine.jpg")
        #expect(json["cover_attribution"] is NSNull)
        #expect(json["cover_attribution_url"] is NSNull)
    }

    // MARK: - Expenses visibility

    // The app ships before or after migration 00037 reaches a database. A
    // trip row without the column must still load, and must read as "not
    // shared": the safe answer for the group's money.
    @Test("A trip from a database without expenses_public still decodes, with expenses private")
    func expensesPrivateWhenColumnMissing() throws {
        let json = #"{"id":"11111111-1111-1111-1111-111111111111","created_by":"22222222-2222-2222-2222-222222222222","title":"Paris","destination":"Paris, France","status":"planning","is_public":true}"#
        let trip = try SupabaseManager.postgrestDecoder.decode(Trip.self, from: Data(json.utf8))
        #expect(trip.sharesExpenses == false)

        let optedIn = try SupabaseManager.postgrestDecoder.decode(
            Trip.self, from: Data(json.replacingOccurrences(of: #""is_public":true"#, with: #""is_public":true,"expenses_public":true"#).utf8)
        )
        #expect(optedIn.sharesExpenses)
    }

    // Saving a trip names the column only when the choice actually changed.
    // Otherwise every edit and every share would fail outright on a
    // database that has not had the column added yet.
    @Test("expenses_public is sent only when the choice changes")
    func expensesPublicSentOnlyOnChange() throws {
        let trip = try SupabaseManager.postgrestDecoder.decode(Trip.self, from: Data(
            #"{"id":"11111111-1111-1111-1111-111111111111","created_by":"22222222-2222-2222-2222-222222222222","title":"Paris","destination":"Paris, France","status":"planning","is_public":true}"#.utf8
        ))
        #expect(trip.expensesPublicChange(to: false) == nil, "already private: say nothing")
        #expect(trip.expensesPublicChange(to: true) == true)

        func keys(_ payload: UpdateTripPayload) throws -> [String: Bool] {
            try JSONDecoder().decode([String: Bool].self, from: JSONEncoder().encode(payload))
        }
        #expect(try keys(UpdateTripPayload(isPublic: true, expensesPublic: trip.expensesPublicChange(to: false))) == ["is_public": true])
        #expect(try keys(UpdateTripPayload(isPublic: true, expensesPublic: trip.expensesPublicChange(to: true)))
                == ["is_public": true, "expenses_public": true])
    }

    @Test("Trip.hasStockCover is true only when both a cover and a credit exist")
    func hasStockCover() {
        var trip = makeTrip(start: nil, end: nil)
        #expect(trip.hasStockCover == false)
        trip.coverImageUrl = "https://images.unsplash.com/x"
        #expect(trip.hasStockCover == false) // user upload: must not be auto-replaced
        trip.coverAttribution = "Jane Doe"
        #expect(trip.hasStockCover == true)
    }

    // MARK: - Date column decoding

    // `date` columns carry no timezone. Decoding "2026-11-05" as UTC midnight
    // made every local-calendar display (titles, calendar grid, DatePicker)
    // show Nov 4 for anyone west of Greenwich.

    @Test("postgrestDecoder decodes date-only columns as local midnight")
    func dateOnlyDecodesAsLocalMidnight() throws {
        struct Row: Decodable { let date: Date }
        let data = Data(#"{"date":"2026-11-05"}"#.utf8)
        let row = try SupabaseManager.postgrestDecoder.decode(Row.self, from: data)

        let comps = Calendar.current.dateComponents([.year, .month, .day], from: row.date)
        #expect(comps.year == 2026)
        #expect(comps.month == 11)
        #expect(comps.day == 5)
        #expect(Calendar.current.startOfDay(for: row.date) == row.date)
    }

    // MARK: - Helpers

    private func makeTrip(
        start: Date?,
        end: Date?,
        status: TripStatus = .planning
    ) -> Trip {
        Trip(
            id: UUID(),
            createdBy: UUID(),
            title: "Test Trip",
            destination: "Test City",
            description: nil,
            coverImageUrl: nil,
            startDate: start,
            endDate: end,
            status: status,
            isPublic: false,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components)!
    }
}
