import SwiftUI

/// 10-day forecast strip on the trip detail screen. Fetches lazily via
/// `TripDetailViewModel.loadForecast()`, which the parent view kicks off after
/// `loadTrip` completes. Renders one of five states, selected in order:
///
/// 1. hidden (no dates, past trip, or destination didn't geocode)
/// 2. too-far-out caption (start date > 10 days away)
/// 3. skeleton (fetching for the first time)
/// 4. compact inline error (with retry)
/// 5. populated day cards + WeatherKit attribution footer
///
/// The compact error case exists because `OuestErrorState` is full-screen and
/// would dominate the trip detail. This section owns its own tiny error UI.
struct WeatherSection: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: TripDetailViewModel

    var body: some View {
        Group {
            switch state {
            case .hidden:
                EmptyView()
            case .tooFarOut(let days):
                tooFarOutView(days: days)
            case .loading:
                loadingView
            case .error:
                errorView
            case .populated(let forecast):
                populatedView(forecast)
            }
        }
    }

    // MARK: - State Selection

    private enum State {
        case hidden
        case tooFarOut(days: Int)
        case loading
        case error
        case populated(DailyForecast)
    }

    /// Precondition ladder — the view is the single source of truth for what
    /// renders; the view model's `loadForecast` only decides whether to fetch.
    private var state: State {
        guard let trip = viewModel.trip, let start = trip.startDate else {
            return .hidden
        }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startDay = calendar.startOfDay(for: start)
        let daysUntilStart = calendar.dateComponents([.day], from: today, to: startDay).day ?? 0

        // Trip already ended — hide.
        if let end = trip.endDate {
            let endDay = calendar.startOfDay(for: end)
            let daysSinceEnd = calendar.dateComponents([.day], from: endDay, to: today).day ?? 0
            if daysSinceEnd > 0 { return .hidden }
        }

        // Populated wins over "too far out" the moment we have data, so a user
        // scrolling into the future then back sees consistent state.
        if let forecast = viewModel.forecast {
            return .populated(forecast)
        }

        if daysUntilStart > 10 { return .tooFarOut(days: daysUntilStart) }

        if viewModel.isLoadingWeather { return .loading }
        if viewModel.weatherFailure != nil { return .error }

        // Preconditions met, nothing fetched yet — treat as loading. The
        // detached Task from `loadTrip` will flip `isLoadingWeather` shortly.
        return .loading
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: OuestTheme.Spacing.sm) {
            Image(systemName: "cloud.sun.fill")
                .font(.subheadline)
                .foregroundStyle(OuestTheme.Colors.brand)
            Text("Weather")
                .font(OuestTheme.Typography.sectionTitle)
        }
    }

    // MARK: - Too Far Out

    private func tooFarOutView(days: Int) -> some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.md) {
            header
            HStack(spacing: OuestTheme.Spacing.sm) {
                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
                Text("Forecast available closer to your trip")
                    .font(OuestTheme.Typography.caption)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
            }
            .padding(OuestTheme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(OuestTheme.Colors.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
        }
        .padding(.horizontal, OuestTheme.Spacing.xl)
        .padding(.vertical, OuestTheme.Spacing.md)
    }

    // MARK: - Loading Skeleton

    private var loadingView: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.md) {
            header
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: OuestTheme.Spacing.sm) {
                    ForEach(0..<5, id: \.self) { _ in
                        skeletonCard
                    }
                }
            }
        }
        .padding(.horizontal, OuestTheme.Spacing.xl)
        .padding(.vertical, OuestTheme.Spacing.md)
    }

    private var skeletonCard: some View {
        VStack(spacing: OuestTheme.Spacing.sm) {
            SkeletonView(width: 40, height: 10)
            SkeletonView(width: 28, height: 20)
            SkeletonView(width: 28, height: 20, radius: OuestTheme.Radius.sm)
            SkeletonView(width: 36, height: 12)
        }
        .frame(width: 72)
        .padding(.vertical, OuestTheme.Spacing.md)
        .background(OuestTheme.Colors.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
        .shimmerEffect()
    }

    // MARK: - Error

    private var errorView: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.md) {
            header
            HStack(spacing: OuestTheme.Spacing.sm) {
                Image(systemName: "cloud.slash")
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
                Text("Couldn't load forecast")
                    .font(OuestTheme.Typography.caption)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
                Spacer()
                Button {
                    HapticFeedback.light()
                    Task { await viewModel.loadForecast() }
                } label: {
                    Text("Retry")
                        .font(OuestTheme.Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(OuestTheme.Colors.brand)
                }
                .accessibilityLabel("Retry loading forecast")
            }
            .padding(OuestTheme.Spacing.md)
            .background(OuestTheme.Colors.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
        }
        .padding(.horizontal, OuestTheme.Spacing.xl)
        .padding(.vertical, OuestTheme.Spacing.md)
    }

    // MARK: - Populated

    private func populatedView(_ forecast: DailyForecast) -> some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.md) {
            header
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: OuestTheme.Spacing.sm) {
                    ForEach(forecast.days) { day in
                        dayCard(day)
                    }
                }
            }
            attributionFooter(forecast.attribution)
        }
        .padding(.horizontal, OuestTheme.Spacing.xl)
        .padding(.vertical, OuestTheme.Spacing.md)
    }

    private func dayCard(_ day: WeatherDay) -> some View {
        VStack(spacing: OuestTheme.Spacing.xs) {
            Text(day.date.formatted(.dateTime.weekday(.abbreviated)))
                .font(OuestTheme.Typography.caption)
                .foregroundStyle(OuestTheme.Colors.textSecondary)
            Text(day.date.formatted(.dateTime.day()))
                .font(OuestTheme.Typography.cardTitle)
                .foregroundStyle(OuestTheme.Colors.textPrimary)
            Image(systemName: day.symbolName)
                .font(.title3)
                .foregroundStyle(OuestTheme.Colors.brand)
                .padding(.vertical, OuestTheme.Spacing.xxs)
            VStack(spacing: OuestTheme.Spacing.xxs) {
                Text(Self.formatTemp(day.highC))
                    .font(OuestTheme.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(OuestTheme.Colors.textPrimary)
                Text(Self.formatTemp(day.lowC))
                    .font(OuestTheme.Typography.caption)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
            }
            if day.precipitationChance > 0.05 {
                HStack(spacing: OuestTheme.Spacing.xxs) {
                    Image(systemName: "drop.fill")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                    Text("\(Int((day.precipitationChance * 100).rounded()))%")
                        .font(OuestTheme.Typography.micro)
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                }
            }
        }
        .frame(width: 72)
        .padding(.vertical, OuestTheme.Spacing.md)
        .padding(.horizontal, OuestTheme.Spacing.xs)
        .background(OuestTheme.Colors.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Self.accessibilityLabel(for: day))
    }

    private func attributionFooter(_ attribution: ForecastAttribution) -> some View {
        // WeatherKit's terms of service require this mark to appear next to
        // displayed forecast data with a tap-through to the legal page. Do not
        // remove without checking the current WeatherKit branding docs.
        HStack {
            Spacer()
            Link(destination: attribution.legalPageURL) {
                AsyncImage(
                    url: colorScheme == .dark
                        ? attribution.darkLogoURL
                        : attribution.lightLogoURL
                ) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    default:
                        // If Apple's CDN ever hiccups, keep the required link
                        // visible with plain text so we stay compliant.
                        HStack(spacing: OuestTheme.Spacing.xxs) {
                            Text("Weather data")
                            Image(systemName: "arrow.up.right")
                        }
                        .font(OuestTheme.Typography.micro)
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                    }
                }
                .frame(height: 14)
            }
            .accessibilityLabel("Weather data sources")
        }
    }

    // MARK: - Helpers

    private static func formatTemp(_ celsius: Double) -> String {
        // `.weather` usage tells Foundation to render like the system Weather
        // app — degree sign, no unit letter, rounded to whole degrees, C/F
        // chosen by the user's locale.
        Measurement(value: celsius, unit: UnitTemperature.celsius)
            .formatted(.measurement(width: .narrow, usage: .weather))
    }

    private static func accessibilityLabel(for day: WeatherDay) -> String {
        let dayText = day.date.formatted(.dateTime.weekday(.wide).day())
        var parts = [
            dayText,
            day.conditionDescription,
            "High \(formatTemp(day.highC))",
            "Low \(formatTemp(day.lowC))",
        ]
        if day.precipitationChance > 0.05 {
            parts.append("\(Int((day.precipitationChance * 100).rounded())) percent chance of precipitation")
        }
        return parts.joined(separator: ", ")
    }
}
