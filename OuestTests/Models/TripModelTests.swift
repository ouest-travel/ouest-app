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
