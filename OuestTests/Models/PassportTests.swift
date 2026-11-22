import Testing
import Foundation
import RealityKit
@testable import Ouest

@Suite("Passport")
struct PassportTests {

    // The cover table is keyed by the same alpha-3 codes the profile stores.
    // A typo in the table would silently fall back to navy for that country.
    @Test("Every cover family entry is a known country code")
    func coverTableUsesKnownCountries() {
        for code in PassportCoverStyle.families.keys {
            #expect(CountryHelper.country(for: code) != nil, "\(code) is not in CountryHelper")
        }
    }

    @Test("Unknown or missing nationality gets the fallback cover")
    func coverFallback() {
        #expect(PassportCoverStyle.family(forNationality: nil) == PassportCoverStyle.fallback)
        #expect(PassportCoverStyle.family(forNationality: "") == PassportCoverStyle.fallback)
        #expect(PassportCoverStyle.family(forNationality: "XXX") == PassportCoverStyle.fallback)
        #expect(PassportCoverStyle.family(forNationality: "fra") == .burgundy, "lookup is case-insensitive")
    }

    // Only finished trips earn a stamp, and they read oldest first like a
    // real passport, so the first page is where the story starts.
    @Test("Stamps come from completed trips, oldest first")
    func stampsFromCompletedTrips() {
        let trips = [
            trip(status: .planning, end: date(2026, 6, 1)),
            trip(status: .completed, end: date(2025, 3, 20)),
            trip(status: .active, end: date(2026, 1, 5)),
            trip(status: .completed, end: date(2024, 11, 2))
        ]
        let stamps = PassportStamp.stamps(from: trips)
        #expect(stamps.count == 2)
        #expect(stamps.map(\.departure) == [date(2024, 11, 2), date(2025, 3, 20)])
    }

    @Test("A stamp's look is stable for the same trip")
    func stampVarietyIsStable() {
        let trip = trip(status: .completed, end: date(2025, 1, 1))
        let a = PassportStamp(trip: trip), b = PassportStamp(trip: trip)
        #expect(a.shape == b.shape && a.ink == b.ink && a.rotationDegrees == b.rotationDegrees)
        #expect(abs(a.rotationDegrees) <= 12, "stamps tilt, but stay readable")
    }

    // The identity page is always first, the book always has exactly one
    // page per face in the model, and a full book drops the overflow rather
    // than growing faces that do not exist.
    @Test("Pages fill the model's faces: identity, stamps, then blanks")
    func pageLayout() {
        let none = PassportPages.pages(for: [])
        #expect(none.count == PassportPages.faceCount)
        #expect(none.first == .identity)
        #expect(none.dropFirst().allSatisfy { $0 == .blank })

        let many = (0..<40).map { _ in PassportStamp(trip: trip(status: .completed, end: date(2025, 1, 1))) }
        let full = PassportPages.pages(for: many)
        #expect(full.count == PassportPages.faceCount)
        let shown = full.reduce(0) { total, page in
            if case .stamps(let stamps, _) = page { return total + stamps.count }
            return total
        }
        #expect(shown == PassportPages.capacity)
    }

    // A leaf that swings past flat, or past the leaf above it, sinks through
    // the stack and the page beneath shows through it. The hinge springs
    // overshoot on their own, so the stops have to hold on every frame,
    // including when pages are turned faster than they settle.
    @Test("Cover and pages never pass through each other")
    @MainActor
    @available(iOS 18.0, *)
    func leavesStayStacked() {
        let motion = PassportMotion()
        motion.attach(root: Entity(), book: Entity(), coverPivot: Entity(), sheets: [Entity(), Entity(), Entity()])

        let frame = 1.0 / 60
        func run(frames: Int) {
            for _ in 0..<frames {
                motion.tick(frame)
                var above = motion.cover
                #expect((0...1).contains(above), "cover at \(above)")
                for angle in motion.sheetAngles {
                    #expect((0...above).contains(angle), "sheet at \(angle) under a leaf at \(above)")
                    above = angle
                }
            }
        }

        // Open, turn every page, then come all the way back, 0.3 s apart.
        let taps: [() -> Void] = [motion.open] + Array(repeating: motion.next, count: 3)
            + Array(repeating: motion.previous, count: 2) + Array(repeating: motion.next, count: 2)
        for tap in taps {
            tap()
            run(frames: 18)
        }

        // The stops must not keep the leaves from arriving.
        run(frames: 300)
        #expect(abs(motion.cover - 1) < 0.01)
        #expect(motion.sheetAngles.allSatisfy { abs($0 - 1) < 0.01 })
    }

    // MARK: Fixtures

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(timeZone: .gmt, year: y, month: m, day: d))!
    }

    private func trip(status: TripStatus, end: Date) -> Trip {
        Trip(
            id: UUID(), createdBy: UUID(), title: "Trip", destination: "Lisbon",
            description: nil, coverImageUrl: nil, startDate: end.addingTimeInterval(-5 * 86_400), endDate: end,
            status: status, isPublic: false, budget: nil, currency: nil, votingEnabled: nil,
            tags: nil, countryCodes: ["PRT"], coverAttribution: nil, coverAttributionUrl: nil,
            createdAt: nil, updatedAt: nil
        )
    }
}
