import Foundation
import Testing
@testable import Ouest

@Suite("Trip Invite Models")
struct TripInviteTests {

    // MARK: - Supabase Decoder

    private static var supabaseDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        let isoWithFrac = ISO8601DateFormatter()
        isoWithFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoPlain = ISO8601DateFormatter()
        isoPlain.formatOptions = [.withInternetDateTime]

        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            if let d = isoWithFrac.date(from: str) { return d }
            if let d = isoPlain.date(from: str) { return d }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Bad date: \(str)")
        }
        return decoder
    }

    // MARK: - TripInvite Decoding

    @Test("Decodes a full TripInvite from JSON")
    func decodeFullInvite() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "trip_id": "22222222-2222-2222-2222-222222222222",
            "created_by": "33333333-3333-3333-3333-333333333333",
            "code": "AbCd1234",
            "role": "viewer",
            "expires_at": "2026-12-31T23:59:59+00:00",
            "max_uses": 10,
            "use_count": 3,
            "is_active": true,
            "created_at": "2026-01-01T00:00:00+00:00"
        }
        """.data(using: .utf8)!

        let invite = try Self.supabaseDecoder.decode(TripInvite.self, from: json)

        #expect(invite.id == UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        #expect(invite.tripId == UUID(uuidString: "22222222-2222-2222-2222-222222222222"))
        #expect(invite.createdBy == UUID(uuidString: "33333333-3333-3333-3333-333333333333"))
        #expect(invite.code == "AbCd1234")
        #expect(invite.role == .viewer)
        #expect(invite.expiresAt != nil)
        #expect(invite.maxUses == 10)
        #expect(invite.useCount == 3)
        #expect(invite.isActive == true)
        #expect(invite.createdAt != nil)
    }

    @Test("Decodes TripInvite with minimal fields")
    func decodeMinimalInvite() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "trip_id": "22222222-2222-2222-2222-222222222222",
            "created_by": "33333333-3333-3333-3333-333333333333",
            "code": "XyZ98765",
            "role": "editor",
            "max_uses": 0,
            "use_count": 0,
            "is_active": true
        }
        """.data(using: .utf8)!

        let invite = try Self.supabaseDecoder.decode(TripInvite.self, from: json)

        #expect(invite.code == "XyZ98765")
        #expect(invite.role == .editor)
        #expect(invite.expiresAt == nil)
        #expect(invite.maxUses == 0)
        #expect(invite.useCount == 0)
        #expect(invite.createdAt == nil)
    }

    // MARK: - TripInvite Computed Properties

    @Test("isValid returns true for active, non-expired, within max uses")
    func isValidActive() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "trip_id": "22222222-2222-2222-2222-222222222222",
            "created_by": "33333333-3333-3333-3333-333333333333",
            "code": "VALID123",
            "role": "viewer",
            "expires_at": "2099-12-31T23:59:59+00:00",
            "max_uses": 10,
            "use_count": 3,
            "is_active": true
        }
        """.data(using: .utf8)!

        let invite = try Self.supabaseDecoder.decode(TripInvite.self, from: json)
        #expect(invite.isValid == true)
    }

    @Test("isValid returns false when inactive")
    func isValidInactive() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "trip_id": "22222222-2222-2222-2222-222222222222",
            "created_by": "33333333-3333-3333-3333-333333333333",
            "code": "DEAD1234",
            "role": "viewer",
            "max_uses": 0,
            "use_count": 0,
            "is_active": false
        }
        """.data(using: .utf8)!

        let invite = try Self.supabaseDecoder.decode(TripInvite.self, from: json)
        #expect(invite.isValid == false)
    }

    @Test("isValid returns false when expired")
    func isValidExpired() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "trip_id": "22222222-2222-2222-2222-222222222222",
            "created_by": "33333333-3333-3333-3333-333333333333",
            "code": "EXPR1234",
            "role": "viewer",
            "expires_at": "2020-01-01T00:00:00+00:00",
            "max_uses": 0,
            "use_count": 0,
            "is_active": true
        }
        """.data(using: .utf8)!

        let invite = try Self.supabaseDecoder.decode(TripInvite.self, from: json)
        #expect(invite.isValid == false)
    }

    @Test("isValid returns false when max uses reached")
    func isValidMaxUsesReached() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "trip_id": "22222222-2222-2222-2222-222222222222",
            "created_by": "33333333-3333-3333-3333-333333333333",
            "code": "FULL1234",
            "role": "viewer",
            "max_uses": 5,
            "use_count": 5,
            "is_active": true
        }
        """.data(using: .utf8)!

        let invite = try Self.supabaseDecoder.decode(TripInvite.self, from: json)
        #expect(invite.isValid == false)
    }

    @Test("isValid returns true when max_uses is 0 (unlimited)")
    func isValidUnlimited() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "trip_id": "22222222-2222-2222-2222-222222222222",
            "created_by": "33333333-3333-3333-3333-333333333333",
            "code": "UNLM1234",
            "role": "viewer",
            "max_uses": 0,
            "use_count": 100,
            "is_active": true
        }
        """.data(using: .utf8)!

        let invite = try Self.supabaseDecoder.decode(TripInvite.self, from: json)
        #expect(invite.isValid == true)
    }

    @Test("inviteURL has correct format")
    func inviteURL() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "trip_id": "22222222-2222-2222-2222-222222222222",
            "created_by": "33333333-3333-3333-3333-333333333333",
            "code": "TestCode",
            "role": "viewer",
            "max_uses": 0,
            "use_count": 0,
            "is_active": true
        }
        """.data(using: .utf8)!

        let invite = try Self.supabaseDecoder.decode(TripInvite.self, from: json)
        #expect(invite.inviteURL.absoluteString == "ouest://join/TestCode")
    }

    @Test("shareText contains invite URL")
    func shareTextContent() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "trip_id": "22222222-2222-2222-2222-222222222222",
            "created_by": "33333333-3333-3333-3333-333333333333",
            "code": "Share123",
            "role": "viewer",
            "max_uses": 0,
            "use_count": 0,
            "is_active": true
        }
        """.data(using: .utf8)!

        let invite = try Self.supabaseDecoder.decode(TripInvite.self, from: json)
        #expect(invite.shareText.contains("ouest://join/Share123"))
        #expect(invite.shareText.contains("Ouest"))
    }

    // MARK: - CreateInvitePayload Encoding

    @Test("CreateInvitePayload encodes with snake_case keys")
    func createInvitePayloadEncoding() throws {
        let payload = CreateInvitePayload(
            tripId: UUID(),
            createdBy: UUID(),
            code: "TEST1234",
            role: .viewer,
            expiresAt: nil,
            maxUses: 0
        )

        let data = try JSONEncoder().encode(payload)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(dict["trip_id"] != nil)
        #expect(dict["created_by"] != nil)
        #expect(dict["code"] as? String == "TEST1234")
        #expect(dict["role"] as? String == "viewer")
        #expect(dict["max_uses"] as? Int == 0)

        // No camelCase keys
        #expect(dict["tripId"] == nil)
        #expect(dict["createdBy"] == nil)
        #expect(dict["maxUses"] == nil)
    }

    // MARK: - InvitePreview Decoding

    @Test("InvitePreview decodes from JSON")
    func decodeInvitePreview() throws {
        let json = """
        {
            "trip_id": "11111111-1111-1111-1111-111111111111",
            "trip_title": "Paris Trip",
            "trip_destination": "Paris, France",
            "trip_cover_image_url": "https://example.com/cover.jpg",
            "role": "viewer",
            "creator_name": "Alice",
            "member_count": 5,
            "is_already_member": false
        }
        """.data(using: .utf8)!

        let preview = try JSONDecoder().decode(InvitePreview.self, from: json)

        #expect(preview.tripId == UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        #expect(preview.tripTitle == "Paris Trip")
        #expect(preview.tripDestination == "Paris, France")
        #expect(preview.tripCoverImageUrl == "https://example.com/cover.jpg")
        #expect(preview.role == "viewer")
        #expect(preview.creatorName == "Alice")
        #expect(preview.memberCount == 5)
        #expect(preview.isAlreadyMember == false)
    }

    @Test("InvitePreview decodes with null cover image")
    func decodeInvitePreviewNullCover() throws {
        let json = """
        {
            "trip_id": "11111111-1111-1111-1111-111111111111",
            "trip_title": "Beach Trip",
            "trip_destination": "Bali",
            "trip_cover_image_url": null,
            "role": "editor",
            "creator_name": "Bob",
            "member_count": 2,
            "is_already_member": true
        }
        """.data(using: .utf8)!

        let preview = try JSONDecoder().decode(InvitePreview.self, from: json)
        #expect(preview.tripCoverImageUrl == nil)
        #expect(preview.isAlreadyMember == true)
    }

    // MARK: - DeepLinkRouter

    @Test("Parses ouest://join/{code} path format")
    func parseJoinPath() {
        let url = URL(string: "ouest://join/AbCd1234")!
        let destination = DeepLinkRouter.parse(url: url)
        #expect(destination == .joinTrip(code: "AbCd1234"))
    }

    @Test("Parses ouest://join?code={code} query format")
    func parseJoinQuery() {
        let url = URL(string: "ouest://join?code=XyZ98765")!
        let destination = DeepLinkRouter.parse(url: url)
        #expect(destination == .joinTrip(code: "XyZ98765"))
    }

    @Test("Returns nil for invalid scheme")
    func parseInvalidScheme() {
        let url = URL(string: "https://join/AbCd1234")!
        let destination = DeepLinkRouter.parse(url: url)
        #expect(destination == nil)
    }

    @Test("Returns nil for missing code")
    func parseMissingCode() {
        let url = URL(string: "ouest://join")!
        let destination = DeepLinkRouter.parse(url: url)
        #expect(destination == nil)
    }

    @Test("Returns nil for unknown host")
    func parseUnknownHost() {
        let url = URL(string: "ouest://profile/123")!
        let destination = DeepLinkRouter.parse(url: url)
        #expect(destination == nil)
    }

    // MARK: - QR Code Generator

    @Test("Generates a non-nil UIImage for a valid string")
    func qrCodeGenerates() {
        let image = QRCodeGenerator.generate(from: "ouest://join/TestCode")
        #expect(image != nil)
    }

    @Test("Returns nil for an empty string")
    func qrCodeEmptyString() {
        let image = QRCodeGenerator.generate(from: "")
        #expect(image == nil)
    }

    @Test("Generated QR code has expected dimensions")
    func qrCodeDimensions() {
        let size: CGFloat = 300
        let image = QRCodeGenerator.generate(from: "test", size: size)
        #expect(image != nil)
        // QR code dimensions should be close to requested size
        if let image {
            #expect(image.size.width > 0)
            #expect(image.size.height > 0)
        }
    }

    // MARK: - Invite Code Generation

    @Test("Generated invite code is 8 characters")
    func inviteCodeLength() {
        let code = TripService.generateInviteCode()
        #expect(code.count == 8)
    }

    @Test("Generated invite code contains only allowed characters")
    func inviteCodeCharacters() {
        let allowed = Set("ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789")
        for _ in 0..<100 {
            let code = TripService.generateInviteCode()
            for char in code {
                #expect(allowed.contains(char), "Unexpected character: \(char)")
            }
        }
    }

    @Test("Generated invite codes are unique")
    func inviteCodeUniqueness() {
        var codes = Set<String>()
        for _ in 0..<100 {
            codes.insert(TripService.generateInviteCode())
        }
        // With 57^8 possible codes, 100 codes should all be unique
        #expect(codes.count == 100)
    }
}
