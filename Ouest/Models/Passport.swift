import Foundation

// MARK: - Cover

/// Colour family of a passport cover. The albedo for each lives in
/// `PassportScene`; this is only the classification.
enum PassportCoverFamily: String, CaseIterable, Sendable {
    case burgundy, navy, green, black, red
}

/// Picks a cover family for a nationality (ISO 3166-1 alpha-3).
///
/// These are the broad real-world families, not official specifications:
/// most of Europe and much of South America issue burgundy, the Americas
/// and Commonwealth lean navy, ECOWAS and much of the Islamic world green.
/// Anything unknown gets navy, the most common family.
enum PassportCoverStyle {

    static let fallback: PassportCoverFamily = .navy

    static func family(forNationality code: String?) -> PassportCoverFamily {
        // Accept alpha-2 as well, by resolving to the canonical alpha-3 first.
        guard let code, let country = CountryHelper.country(for: code) else { return fallback }
        return families[country.code] ?? fallback
    }

    static let families: [String: PassportCoverFamily] = {
        var table: [String: PassportCoverFamily] = [:]
        func set(_ family: PassportCoverFamily, _ codes: String) {
            for code in codes.split(separator: " ") { table[String(code)] = family }
        }
        set(.burgundy, """
            AUT BEL BGR HRV CYP CZE DNK EST FIN FRA DEU GRC HUN IRL ITA LVA LTU LUX MLT NLD POL PRT ROU \
            SVK SVN ESP SWE NOR TUR SRB BIH MNE MKD ALB MDA GEO RUS CHN JPN THA PER COL VEN ECU PRY CHL \
            LKA PHL QAT IRN VAT SMR AND MCO
            """)
        set(.navy, """
            USA CAN AUS GBR IND ISR ARE KWT JOR LBN TUN IRQ AFG ARG BRA URY CUB DOM JAM TTO BRB BHS KOR \
            UKR ARM AZE KAZ MNG ISL CRI PAN SLV GTM HND NIC HTI GUY SUR BLZ FJI KEN UGA TZA RWA BDI SSD AGO
            """)
        set(.green, """
            PAK BGD NPL SAU EGY MAR DZA NGA GHA ETH ZAF ZWE SEN CIV CMR MEX IDN VNM UZB TKM TJK MOZ ZMB \
            MWI GMB GIN SLE LBR TGO BEN NER MLI BFA MRT SDN LBY SOM DJI COM MDG GAB COG COD TCD CAF GNQ \
            STP CPV GNB NAM BWA LSO SWZ SYR YEM
            """)
        set(.black, "NZL MDV")
        set(.red, "CHE SGP MYS KGZ OMN BHR")
        return table
    }()
}

// MARK: - Stamps

/// One entry stamp in the passport, made from a completed trip.
struct PassportStamp: Identifiable, Hashable, Sendable {

    enum Shape: CaseIterable, Sendable {
        case rectangle, oval, circle, hexagon
    }

    /// Ink colour family. Albedos live in the page renderer.
    enum Ink: CaseIterable, Sendable {
        case red, blue, green, violet
    }

    let id: UUID
    let countryCode: String?
    let destination: String
    let arrival: Date?
    let departure: Date?

    /// Stable variety: shape, ink and tilt come from the trip id, so a
    /// stamp looks the same every time the passport is opened.
    var shape: Shape { Shape.allCases[Int(seed % UInt32(Shape.allCases.count))] }
    var ink: Ink { Ink.allCases[Int((seed >> 8) % UInt32(Ink.allCases.count))] }
    var rotationDegrees: Double { Double(Int((seed >> 16) % 25)) - 12 }

    private var seed: UInt32 {
        let b = id.uuid
        return UInt32(b.0) | UInt32(b.1) << 8 | UInt32(b.2) << 16 | UInt32(b.3) << 24
    }

    init(trip: Trip) {
        id = trip.id
        countryCode = trip.countryCodes?.first
        destination = trip.destination
        arrival = trip.startDate
        departure = trip.endDate
    }

    /// Stamps for a passport: completed trips only, oldest first, the way
    /// a real passport fills from the front.
    static func stamps(from trips: [Trip]) -> [PassportStamp] {
        trips
            .filter { $0.status == .completed }
            .sorted { sortDate($0) < sortDate($1) }
            .map(PassportStamp.init)
    }

    private static func sortDate(_ trip: Trip) -> Date {
        trip.endDate ?? trip.startDate ?? trip.createdAt ?? .distantPast
    }
}

// MARK: - Book

/// Everything the passport renders for one user.
struct PassportBook: Hashable, Sendable {
    var holderName: String
    /// ISO 3166-1 alpha-3, as stored on the profile.
    var nationality: String?
    var memberSince: Date?
    var stamps: [PassportStamp]

    var coverFamily: PassportCoverFamily { PassportCoverStyle.family(forNationality: nationality) }
    var country: CountryHelper.Country? { nationality.flatMap(CountryHelper.country(for:)) }
}

// MARK: - Pages

/// What is printed on each page of the book, in reading order.
enum PassportPage: Hashable, Sendable {
    case identity
    case stamps([PassportStamp], number: Int)
    case blank
}

enum PassportPages {

    /// Stamps per page. Four fit at a readable size on a page this small.
    static let stampsPerPage = 4

    /// Page faces in the model: the left block, three sheets front and back,
    /// the right block.
    static let faceCount = 8

    /// How many stamps the book can show before it is full.
    static var capacity: Int { (faceCount - 1) * stampsPerPage }

    /// Pages in reading order: the identity page, then stamp pages, then
    /// blanks up to `faceCount`. Stamps beyond `capacity` are not shown.
    static func pages(for stamps: [PassportStamp]) -> [PassportPage] {
        var pages: [PassportPage] = [.identity]
        let shown = Array(stamps.prefix(capacity))
        var index = 0
        while index < shown.count, pages.count < faceCount {
            let slice = Array(shown[index..<min(index + stampsPerPage, shown.count)])
            pages.append(.stamps(slice, number: pages.count + 1))
            index += stampsPerPage
        }
        while pages.count < faceCount {
            pages.append(.blank)
        }
        return pages
    }
}
