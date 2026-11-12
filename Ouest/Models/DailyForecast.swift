import Foundation

// MARK: - DailyForecast
//
// Pure-Swift, WeatherKit-free view-layer model. Keeping WeatherKit out of the
// view surface means WeatherSection can preview under Reduce Motion, dark
// mode, and offline conditions without dragging in a real WeatherKit query,
// and it keeps the test surface small enough to fixture by hand.

struct DailyForecast: Sendable, Equatable {
    let days: [WeatherDay]
    let attribution: ForecastAttribution
}

struct WeatherDay: Sendable, Equatable, Identifiable {
    let date: Date
    /// High temperature in Celsius. The view renders in the user's locale via
    /// Measurement so we don't have to duplicate F/C paths here.
    let highC: Double
    let lowC: Double
    /// SF Symbol name provided by WeatherKit (`sun.max.fill`, `cloud.rain.fill`
    /// etc). Rendering is a straight `Image(systemName:)`.
    let symbolName: String
    /// Human-readable condition ("Mostly Sunny"). Used for VoiceOver.
    let conditionDescription: String
    /// 0.0 – 1.0. Rendered as a percentage when > 0.
    let precipitationChance: Double

    var id: Date { date }
}

/// Apple requires the "  Weather" mark next to displayed forecast data with
/// tap-through to the source list. WeatherKit exposes these three URLs on its
/// own `WeatherAttribution` struct — we hold onto them so the view can render
/// the right logo for the current color scheme.
struct ForecastAttribution: Sendable, Equatable {
    let lightLogoURL: URL
    let darkLogoURL: URL
    let legalPageURL: URL
}
