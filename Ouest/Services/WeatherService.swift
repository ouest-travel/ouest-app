import Foundation
import CoreLocation
import WeatherKit

/// Curates Apple's WeatherKit `DayWeather` stream into a flat, view-friendly
/// `DailyForecast` so `WeatherSection` can render + preview without importing
/// WeatherKit. Results are cached in-memory by `(lat, lon, YYYY-MM-DD-HH)` —
/// weather doesn't shift faster than hourly and WeatherKit is billed by call.
///
/// Naming: this enum is `WeatherService` in the `Ouest` module. Apple's own
/// `WeatherKit.WeatherService` is fully-qualified below to avoid the shadow.
enum WeatherService {

    enum WeatherError: LocalizedError {
        case forecastUnavailable

        var errorDescription: String? {
            switch self {
            case .forecastUnavailable:
                return "Couldn't load the forecast for this destination."
            }
        }
    }

    // MARK: - Cache

    private actor Cache {
        private var entries: [String: DailyForecast] = [:]

        private static func key(latitude: Double, longitude: Double, hour: String) -> String {
            // 3 decimal places = ~110m precision. Two trips a block apart share
            // a cache slot, which is what we want — the forecast is the same.
            String(format: "%.3f,%.3f|%@", latitude, longitude, hour)
        }

        func get(latitude: Double, longitude: Double, hour: String) -> DailyForecast? {
            entries[Self.key(latitude: latitude, longitude: longitude, hour: hour)]
        }

        func set(_ forecast: DailyForecast, latitude: Double, longitude: Double, hour: String) {
            entries[Self.key(latitude: latitude, longitude: longitude, hour: hour)] = forecast
        }
    }

    private static let cache = Cache()

    private static let hourFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd-HH"
        return f
    }()

    // MARK: - Public API

    /// Fetches a curated 10-day daily forecast for the given coordinate. Cached
    /// per UTC-hour so the same location fetched twice in short succession only
    /// bills one WeatherKit call.
    static func fetchDailyForecast(
        latitude: Double,
        longitude: Double
    ) async throws -> DailyForecast {
        let hour = hourFormatter.string(from: Date())
        if let cached = await cache.get(latitude: latitude, longitude: longitude, hour: hour) {
            return cached
        }

        let location = CLLocation(latitude: latitude, longitude: longitude)
        let service = WeatherKit.WeatherService.shared

        // WeatherKit's daily forecast is exactly what we want: ~10 days out,
        // one entry per day, in the location's local calendar.
        async let dailyQuery = service.weather(for: location, including: .daily)
        async let attributionQuery = service.attribution

        let (dailyForecast, weatherAttribution) = try await (dailyQuery, attributionQuery)

        let days = dailyForecast.forecast.map { day in
            WeatherDay(
                date: day.date,
                highC: day.highTemperature.converted(to: .celsius).value,
                lowC: day.lowTemperature.converted(to: .celsius).value,
                symbolName: day.symbolName,
                conditionDescription: day.condition.description,
                precipitationChance: day.precipitationChance
            )
        }

        guard !days.isEmpty else { throw WeatherError.forecastUnavailable }

        let forecast = DailyForecast(
            days: days,
            attribution: ForecastAttribution(
                lightLogoURL: weatherAttribution.combinedMarkLightURL,
                darkLogoURL: weatherAttribution.combinedMarkDarkURL,
                legalPageURL: weatherAttribution.legalPageURL
            )
        )

        await cache.set(forecast, latitude: latitude, longitude: longitude, hour: hour)
        return forecast
    }
}
