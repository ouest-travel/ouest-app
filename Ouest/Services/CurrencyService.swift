import Foundation

/// Fetches foreign-exchange rates so expenses entered in a non-trip currency
/// can be converted before storage. Rates are sourced from frankfurter.app
/// (ECB-published, free, no API key) and cached in-memory by `(from, to, day)`
/// so rapid-fire form interactions don't hammer the network.
enum CurrencyService {

    struct FXRate: Sendable {
        let from: String
        let to: String
        let rate: Double
        let asOf: Date
    }

    enum CurrencyError: LocalizedError {
        case invalidResponse
        case rateUnavailable(from: String, to: String)

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "Couldn't read the exchange-rate response."
            case let .rateUnavailable(from, to):
                return "No \(from) → \(to) rate is available right now."
            }
        }
    }

    // MARK: - Cache

    private actor Cache {
        private var entries: [String: FXRate] = [:]

        private static func key(from: String, to: String, day: String) -> String {
            "\(from)|\(to)|\(day)"
        }

        func get(from: String, to: String, day: String) -> FXRate? {
            entries[Self.key(from: from, to: to, day: day)]
        }

        func set(_ rate: FXRate, day: String) {
            entries[Self.key(from: rate.from, to: rate.to, day: day)] = rate
        }
    }

    private static let cache = Cache()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    // MARK: - Public API

    /// Look up the rate to convert 1 unit of `from` into `to`. Identity pairs
    /// short-circuit. Results are cached per UTC day.
    static func fetchRate(from: String, to: String) async throws -> Double {
        let source = from.uppercased()
        let target = to.uppercased()
        guard source != target else { return 1.0 }

        let day = dayFormatter.string(from: Date())
        if let cached = await cache.get(from: source, to: target, day: day) {
            return cached.rate
        }

        let rate = try await fetchRateFromAPI(from: source, to: target)
        await cache.set(
            FXRate(from: source, to: target, rate: rate, asOf: Date()),
            day: day
        )
        return rate
    }

    /// Convenience: convert a concrete amount, returning the converted value
    /// and the rate that was used (so callers can persist it).
    static func convert(amount: Double, from: String, to: String) async throws -> (amount: Double, rate: Double) {
        let rate = try await fetchRate(from: from, to: to)
        return (amount * rate, rate)
    }

    // MARK: - Networking

    private static func fetchRateFromAPI(from: String, to: String) async throws -> Double {
        var components = URLComponents(string: "https://api.frankfurter.app/latest")!
        components.queryItems = [
            URLQueryItem(name: "from", value: from),
            URLQueryItem(name: "to", value: to),
        ]
        guard let url = components.url else { throw CurrencyError.invalidResponse }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw CurrencyError.rateUnavailable(from: from, to: to)
        }

        struct Payload: Decodable { let rates: [String: Double] }
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data),
              let rate = payload.rates[to], rate > 0
        else {
            throw CurrencyError.rateUnavailable(from: from, to: to)
        }
        return rate
    }
}

// MARK: - Curated currency list

/// Common travel currencies surfaced in the picker. Keep short and ordered by
/// rough usage frequency so the most-likely picks live at the top.
enum CommonCurrency {
    struct Entry: Identifiable, Hashable, Sendable {
        let code: String
        let name: String
        var id: String { code }
    }

    static let all: [Entry] = [
        Entry(code: "USD", name: "US Dollar"),
        Entry(code: "EUR", name: "Euro"),
        Entry(code: "GBP", name: "British Pound"),
        Entry(code: "CAD", name: "Canadian Dollar"),
        Entry(code: "AUD", name: "Australian Dollar"),
        Entry(code: "JPY", name: "Japanese Yen"),
        Entry(code: "MXN", name: "Mexican Peso"),
        Entry(code: "INR", name: "Indian Rupee"),
        Entry(code: "CHF", name: "Swiss Franc"),
        Entry(code: "CNY", name: "Chinese Yuan"),
        Entry(code: "SGD", name: "Singapore Dollar"),
        Entry(code: "NZD", name: "New Zealand Dollar"),
        Entry(code: "HKD", name: "Hong Kong Dollar"),
        Entry(code: "KRW", name: "South Korean Won"),
        Entry(code: "BRL", name: "Brazilian Real"),
        Entry(code: "ZAR", name: "South African Rand"),
        Entry(code: "SEK", name: "Swedish Krona"),
        Entry(code: "NOK", name: "Norwegian Krone"),
        Entry(code: "THB", name: "Thai Baht"),
        Entry(code: "AED", name: "UAE Dirham"),
    ]

    /// Build the list shown in the picker, guaranteeing the trip currency is
    /// at the top even if it's not in the curated set.
    static func listIncluding(_ tripCurrency: String?) -> [Entry] {
        guard let code = tripCurrency?.uppercased(), !code.isEmpty else { return all }
        if all.contains(where: { $0.code == code }) {
            return [all.first { $0.code == code }!] + all.filter { $0.code != code }
        }
        return [Entry(code: code, name: code)] + all
    }
}
