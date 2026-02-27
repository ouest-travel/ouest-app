import Foundation
import Testing
@testable import Ouest

@Suite("Entry Requirement Models")
struct EntryRequirementModelTests {

    // MARK: - VisaCheckResponse Decoding

    @Test("Decodes a full visa check API response")
    func decodeFullResponse() throws {
        let json = """
        {
            "data": {
                "passport": { "code": "US", "name": "United States" },
                "destination": {
                    "code": "FR",
                    "name": "France",
                    "continent": "Europe",
                    "capital": "Paris",
                    "currency_code": "EUR",
                    "currency": "Euro",
                    "passport_validity": "Valid for duration of stay",
                    "phone_code": "+33",
                    "timezone": "+01:00",
                    "embassy_url": "https://example.com/embassy"
                },
                "mandatory_registration": {
                    "name": "ETIAS",
                    "color": "yellow",
                    "link": "https://example.com/etias"
                },
                "visa_rules": {
                    "primary_rule": {
                        "name": "Visa Free",
                        "duration": "90 days",
                        "color": "green",
                        "link": null
                    },
                    "secondary_rule": null
                }
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(VisaCheckResponse.self, from: json)

        #expect(response.data.passport.code == "US")
        #expect(response.data.passport.name == "United States")
        #expect(response.data.destination.code == "FR")
        #expect(response.data.destination.name == "France")
        #expect(response.data.destination.continent == "Europe")
        #expect(response.data.destination.capital == "Paris")
        #expect(response.data.destination.currency == "Euro")
        #expect(response.data.destination.passportValidity == "Valid for duration of stay")
        #expect(response.data.destination.phoneCode == "+33")
        #expect(response.data.destination.timezone == "+01:00")
        #expect(response.data.destination.embassyUrl == "https://example.com/embassy")
        #expect(response.data.mandatoryRegistration?.name == "ETIAS")
        #expect(response.data.mandatoryRegistration?.color == "yellow")
        #expect(response.data.mandatoryRegistration?.link == "https://example.com/etias")
        #expect(response.data.visaRules.primaryRule?.name == "Visa Free")
        #expect(response.data.visaRules.primaryRule?.duration == "90 days")
        #expect(response.data.visaRules.primaryRule?.color == "green")
        #expect(response.data.visaRules.secondaryRule == nil)
    }

    @Test("Decodes response with secondary rule and eVisa link")
    func decodeWithSecondaryRule() throws {
        let json = """
        {
            "data": {
                "passport": { "code": "CN", "name": "China" },
                "destination": {
                    "code": "ID",
                    "name": "Indonesia",
                    "continent": "Asia",
                    "capital": "Jakarta"
                },
                "visa_rules": {
                    "primary_rule": {
                        "name": "Visa on arrival",
                        "duration": "30 days",
                        "color": "blue"
                    },
                    "secondary_rule": {
                        "name": "eVisa",
                        "duration": "30 days",
                        "color": "blue",
                        "link": "https://example.com/evisa"
                    }
                }
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(VisaCheckResponse.self, from: json)

        #expect(response.data.mandatoryRegistration == nil)
        #expect(response.data.visaRules.primaryRule?.name == "Visa on arrival")
        #expect(response.data.visaRules.secondaryRule?.name == "eVisa")
        #expect(response.data.visaRules.secondaryRule?.link == "https://example.com/evisa")
    }

    @Test("Decodes response with minimal destination fields")
    func decodeMinimalDestination() throws {
        let json = """
        {
            "data": {
                "passport": { "code": "NG", "name": "Nigeria" },
                "destination": {
                    "code": "GH",
                    "name": "Ghana"
                },
                "visa_rules": {
                    "primary_rule": {
                        "name": "Visa Free",
                        "duration": "90 days",
                        "color": "green"
                    }
                }
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(VisaCheckResponse.self, from: json)

        #expect(response.data.destination.continent == nil)
        #expect(response.data.destination.capital == nil)
        #expect(response.data.destination.currency == nil)
        #expect(response.data.destination.passportValidity == nil)
    }

    // MARK: - VisaColor

    @Test("VisaColor maps API colors to SwiftUI colors")
    func visaColorMapping() {
        #expect(VisaColor(apiColor: "green") == .green)
        #expect(VisaColor(apiColor: "blue") == .blue)
        #expect(VisaColor(apiColor: "yellow") == .yellow)
        #expect(VisaColor(apiColor: "red") == .red)
        #expect(VisaColor(apiColor: nil) == .gray)
        #expect(VisaColor(apiColor: "unknown") == .gray)
        #expect(VisaColor(apiColor: "GREEN") == .green) // case insensitive
    }

    // MARK: - EntryRequirementResult

    @Test("EntryRequirementResult success state")
    func resultSuccess() {
        let data = VisaCheckData(
            passport: PassportInfo(code: "US", name: "United States"),
            destination: DestinationInfo(
                code: "FR", name: "France",
                continent: nil, capital: nil, currencyCode: nil, currency: nil,
                passportValidity: nil, phoneCode: nil, timezone: nil, embassyUrl: nil
            ),
            mandatoryRegistration: nil,
            visaRules: VisaRules(primaryRule: nil, secondaryRule: nil)
        )

        let result = EntryRequirementResult(
            destinationCode: "FR",
            destinationName: "France",
            response: data,
            error: nil
        )

        #expect(result.isSuccess)
        #expect(result.error == nil)
    }

    @Test("EntryRequirementResult error state")
    func resultError() {
        let result = EntryRequirementResult(
            destinationCode: "XX",
            destinationName: "Unknown",
            response: nil,
            error: "API error (status 429)"
        )

        #expect(!result.isSuccess)
        #expect(result.error == "API error (status 429)")
    }

    // MARK: - Country Helpers

    @Test("Flag emoji generation")
    func flagEmoji() {
        #expect(EntryRequirementService.flag(for: "US") == "🇺🇸")
        #expect(EntryRequirementService.flag(for: "FR") == "🇫🇷")
        #expect(EntryRequirementService.flag(for: "NG") == "🇳🇬")
        #expect(EntryRequirementService.flag(for: "JP") == "🇯🇵")
        #expect(EntryRequirementService.flag(for: "us") == "🇺🇸") // lowercase
    }

    @Test("Country name resolution")
    func countryName() {
        // These depend on locale but should resolve for common codes
        let name = EntryRequirementService.countryName(for: "US")
        #expect(!name.isEmpty)
        #expect(name != "US") // Should resolve to something like "United States"
    }

    @Test("All countries list is populated and sorted")
    func allCountries() {
        let countries = EntryRequirementService.allCountries()
        #expect(countries.count > 100)

        // Check sorting
        for i in 0..<(countries.count - 1) {
            #expect(countries[i].name.localizedCaseInsensitiveCompare(countries[i + 1].name) != .orderedDescending)
        }
    }

    // MARK: - Error Types

    @Test("EntryRequirementError descriptions")
    func errorDescriptions() {
        let invalidResponse = EntryRequirementError.invalidResponse
        #expect(invalidResponse.errorDescription != nil)

        let apiError = EntryRequirementError.apiError(statusCode: 429)
        #expect(apiError.errorDescription?.contains("429") == true)
    }
}
