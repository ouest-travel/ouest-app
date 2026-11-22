import Testing
import Foundation
@testable import Ouest

@Suite("TripService search")
struct TripServiceTests {

    // PostgREST splits the conditions of an `or` filter on commas. Most
    // destinations are written "City, Country", so an unquoted value would
    // turn the commonest search into a malformed request.
    @Test("A comma in the search stays part of the search")
    func commaStaysInsideTheValue() {
        #expect(
            TripService.publicTripSearchFilter("Lisbon, Portugal")
                == #"title.ilike."%lisbon, portugal%",destination.ilike."%lisbon, portugal%""#
        )
    }

    // Explore runs one search box against trips and people at once, so a
    // destination typed there reaches the people query too. Unquoted, the
    // comma made that request fail and the People results silently vanish.
    @Test("A destination typed into search does not break the people query")
    func peopleSearchSurvivesAComma() {
        #expect(
            TripService.profileSearchFilter("Lisbon, Portugal")
                == #"handle.ilike."%lisbon, portugal%",full_name.ilike."%lisbon, portugal%",email.ilike."%lisbon, portugal%""#
        )
        #expect(TripService.profileSearchFilter("   ") == nil)
    }

    // The search box is open to anyone. Text typed there must not be able
    // to close the quoted value and append conditions of its own.
    @Test("Typed text cannot end the quoted value or add conditions")
    func cannotBreakOutOfTheValue() throws {
        let filter = try #require(TripService.publicTripSearchFilter(#"x"),is_public.eq.false,(title.ilike."\"#))
        #expect(filter.filter { $0 == "\"" }.count == 4, "only the quotes around the two values")
        #expect(!filter.contains("\\"))
    }

    // A wildcard typed by the user would match every trip rather than
    // trips containing that character.
    @Test("Wildcards typed by the user are not passed through")
    func wildcardsAreRemoved() {
        #expect(TripService.searchTerms("to%k*yo") == "to k yo")
        #expect(TripService.publicTripSearchFilter("%%") == nil)
    }

    // One letter matches most of the catalogue and is not a search yet.
    @Test("Nothing is searched until there are two characters")
    func needsTwoCharacters() {
        #expect(TripService.publicTripSearchFilter("") == nil)
        #expect(TripService.publicTripSearchFilter("  t ") == nil)
        #expect(TripService.publicTripSearchFilter("to") != nil)
    }

    // The on-screen filter compares against handles, which use underscores.
    @Test("Underscores survive so handles can still be matched")
    func keepsUnderscores() {
        #expect(TripService.searchTerms("  Mya_Travels ") == "mya_travels")
    }
}
