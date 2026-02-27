import Foundation

// MARK: - Entry Requirement Service (Travel Buddy API v2)

enum EntryRequirementService {

    private static let baseURL = "https://visa-requirement.p.rapidapi.com"

    // MARK: - API Calls

    /// Fetch visa requirements for a single passport → destination pair.
    static func checkVisa(passport: String, destination: String) async throws -> VisaCheckResponse {
        let url = URL(string: "\(baseURL)/v2/visa/check")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(Secrets.rapidAPIKey, forHTTPHeaderField: "X-RapidAPI-Key")
        request.addValue("visa-requirement.p.rapidapi.com", forHTTPHeaderField: "X-RapidAPI-Host")

        let body: [String: String] = [
            "passport": passport.uppercased(),
            "destination": destination.uppercased()
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw EntryRequirementError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw EntryRequirementError.apiError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(VisaCheckResponse.self, from: data)
    }

    /// Fetch requirements for multiple destinations (sequential to respect rate limits).
    /// Returns results for each destination — individual failures don't crash the batch.
    static func checkVisas(passport: String, destinations: [String]) async -> [EntryRequirementResult] {
        var results: [EntryRequirementResult] = []

        for (index, dest) in destinations.enumerated() {
            // Small delay between requests to respect rate limits
            if index > 0 {
                try? await Task.sleep(for: .milliseconds(300))
            }

            do {
                let response = try await checkVisa(passport: passport, destination: dest)
                results.append(EntryRequirementResult(
                    destinationCode: dest,
                    destinationName: response.data.destination.name,
                    response: response.data,
                    error: nil
                ))
            } catch {
                results.append(EntryRequirementResult(
                    destinationCode: dest,
                    destinationName: countryName(for: dest),
                    response: nil,
                    error: error.localizedDescription
                ))
            }
        }

        return results
    }

    // MARK: - Country Helpers

    /// Localized country name from ISO 3166-1 alpha-2 code.
    static func countryName(for code: String) -> String {
        Locale.current.localizedString(forRegionCode: code.uppercased()) ?? code
    }

    /// Emoji flag from ISO 3166-1 alpha-2 code (e.g. "US" → "🇺🇸").
    static func flag(for code: String) -> String {
        let base: UInt32 = 127397
        return code.uppercased().unicodeScalars.compactMap {
            UnicodeScalar(base + $0.value).map(String.init)
        }.joined()
    }

    /// Sorted list of all countries for the country picker.
    static func allCountries() -> [(code: String, name: String)] {
        Locale.Region.isoRegions
            .map { region in
                let code = region.identifier
                let name = Locale.current.localizedString(forRegionCode: code) ?? code
                return (code: code, name: name)
            }
            .filter { $0.name != $0.code } // filter out codes that didn't resolve
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

// MARK: - Errors

enum EntryRequirementError: LocalizedError, Sendable {
    case invalidResponse
    case apiError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Invalid response from visa requirements service."
        case .apiError(let code):
            "Visa API error (status \(code)). Please try again later."
        }
    }
}
