import Foundation
import Testing
@testable import Ouest

@Suite("Packing List Models")
struct PackingItemTests {

    private static let supabaseDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        let isoWithFrac = ISO8601DateFormatter()
        isoWithFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoPlain = ISO8601DateFormatter()
        decoder.dateDecodingStrategy = .custom { decoder in
            let string = try decoder.singleValueContainer().decode(String.self)
            if let date = isoWithFrac.date(from: string) ?? isoPlain.date(from: string) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Bad date \(string)"))
        }
        return decoder
    }()

    @Test("Decodes a packing item with its joined assignee")
    func decodesWithAssignee() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "trip_id": "22222222-2222-2222-2222-222222222222",
            "title": "Sunscreen",
            "category": "toiletries",
            "assigned_to": "33333333-3333-3333-3333-333333333333",
            "is_packed": true,
            "created_by": "33333333-3333-3333-3333-333333333333",
            "created_at": "2026-11-17T10:00:00Z",
            "updated_at": "2026-11-17T10:05:00Z",
            "assignee": {
                "id": "33333333-3333-3333-3333-333333333333",
                "email": "tim@example.com",
                "full_name": "Tim",
                "is_private": false
            }
        }
        """.data(using: .utf8)!

        let item = try Self.supabaseDecoder.decode(PackingItem.self, from: json)
        #expect(item.title == "Sunscreen")
        #expect(item.category == .toiletries)
        #expect(item.isPacked)
        #expect(item.assignee?.fullName == "Tim")
    }

    @Test("Unassigning encodes an explicit null, not an omitted key")
    func unassignEncodesNull() throws {
        // PostgREST ignores omitted keys on update, so "nobody is bringing
        // this any more" has to be sent as `assigned_to: null`.
        var payload = UpdatePackingItemPayload()
        payload.clearAssignee = true
        let json = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(payload)
        ) as? [String: Any]
        #expect(json?["assigned_to"] is NSNull)
        #expect(json?["is_packed"] == nil)
        #expect(json?["title"] == nil)
    }

    @Test("Toggling packed sends only is_packed")
    func toggleSendsOnlyPacked() throws {
        let json = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(UpdatePackingItemPayload(isPacked: true))
        ) as? [String: Any]
        #expect(json?.keys.sorted() == ["is_packed"])
    }

    @Test("Starter list covers every category except Other")
    func starterListSpansCategories() {
        // The starter list exists so an empty trip shows the grouping at
        // its best; if it collapses into one category it stops teaching
        // how the list is organised.
        let categories = Set(PackingItem.starterItems.map(\.category))
        #expect(categories.isSuperset(of: [.documents, .tech, .toiletries, .essentials, .clothing]))
    }
}
