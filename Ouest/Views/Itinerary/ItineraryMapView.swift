import SwiftUI
import MapKit

struct ItineraryMapView: View {
    @Bindable var viewModel: ItineraryViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.allActivitiesWithCoordinates.isEmpty {
                    emptyMapView
                } else {
                    mapContent
                }
            }
            .navigationTitle("Trip Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(OuestTheme.Colors.textSecondary)
                    }
                    .accessibilityLabel("Close map")
                }

                // Only show the trail toggle when there's actually a trail to toggle
                // (at least one day has 2+ stops with coordinates)
                if hasAnyTrails {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            HapticFeedback.selection()
                            withAnimation(OuestTheme.Anim.smooth) {
                                viewModel.showMapTrails.toggle()
                            }
                        } label: {
                            Image(systemName: viewModel.showMapTrails
                                ? "point.topleft.down.curvedto.point.bottomright.up.fill"
                                : "point.topleft.down.curvedto.point.bottomright.up")
                                .foregroundStyle(viewModel.showMapTrails ? OuestTheme.Colors.brand : OuestTheme.Colors.textSecondary)
                        }
                        .accessibilityLabel(viewModel.showMapTrails ? "Hide trip trails on map" : "Show trip trails on map")
                    }
                }
            }
        }
    }

    // MARK: - Map Content

    private var mapContent: some View {
        ZStack(alignment: .top) {
            mapLayer

            // Floating day filter chips
            if viewModel.daysWithCoordinates.count > 1 {
                dayFilterChips
                    .padding(.horizontal, OuestTheme.Spacing.lg)
                    .padding(.top, OuestTheme.Spacing.sm)
            }
        }
    }

    private var mapLayer: some View {
        let visibleDays = visibleDaysForMap

        return Map(position: $cameraPosition) {
            // Draw polylines first (under markers).
            // We always include them in the map content tree (because SwiftUI's
            // MapContentBuilder doesn't reliably rebuild conditional content), but
            // when trails are toggled OFF we set both opacity to 0 AND lineWidth to 0
            // so MapKit definitively skips drawing.
            ForEach(visibleDays) { day in
                let coords = day.sortedActivities
                    .filter(\.hasCoordinates)
                    .map { CLLocationCoordinate2D(latitude: $0.latitude!, longitude: $0.longitude!) }

                if coords.count >= 2 {
                    MapPolyline(coordinates: coords)
                        .stroke(
                            day.routeColor.opacity(viewModel.showMapTrails ? opacityForDay(day) : 0),
                            style: StrokeStyle(
                                lineWidth: viewModel.showMapTrails ? 4 : 0,
                                lineCap: .round,
                                lineJoin: .round,
                                dash: viewModel.showMapTrails ? [10, 6] : []
                            )
                        )
                }
            }

            // Markers
            ForEach(visibleDays) { day in
                let stops = day.sortedActivities.filter(\.hasCoordinates)
                ForEach(Array(stops.enumerated()), id: \.element.id) { index, activity in
                    let coord = CLLocationCoordinate2D(
                        latitude: activity.latitude!,
                        longitude: activity.longitude!
                    )

                    Annotation(activity.title, coordinate: coord) {
                        numberedMarker(
                            number: index + 1,
                            color: day.routeColor,
                            category: activity.category,
                            title: activity.title,
                            opacity: opacityForDay(day)
                        )
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .including([
            .restaurant, .hotel, .museum, .park, .airport, .publicTransport
        ])))
        // Force Map to fully rebuild when the trail toggle flips —
        // MapContentBuilder caches stroke values and won't always pick up
        // changes otherwise. Camera state is preserved via the external @State.
        .id("map-trails-\(viewModel.showMapTrails)")
        .onChange(of: viewModel.selectedDayFilter?.id) { _, _ in
            updateCameraPosition()
        }
        .onAppear {
            updateCameraPosition()
        }
    }

    // MARK: - Numbered Marker

    private func numberedMarker(
        number: Int,
        color: Color,
        category: ActivityCategory,
        title: String,
        opacity: Double
    ) -> some View {
        VStack(spacing: 2) {
            ZStack(alignment: .bottomTrailing) {
                // Numbered circle
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 32, height: 32)

                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: 32, height: 32)

                    Text("\(number)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
                .shadow(color: .black.opacity(0.4), radius: 3, y: 2)

                // Category icon badge in bottom-right
                Image(systemName: category.icon)
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(color)
                    .frame(width: 13, height: 13)
                    .background(Circle().fill(.white))
                    .offset(x: 2, y: 2)
            }

            // Title pill
            Text(title)
                .font(OuestTheme.Typography.micro)
                .fontWeight(.medium)
                .foregroundStyle(OuestTheme.Colors.textPrimary)
                .lineLimit(1)
                .padding(.horizontal, OuestTheme.Spacing.xs)
                .padding(.vertical, 2)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
        }
        .opacity(opacity)
    }

    // MARK: - Day Filter Chips

    private var dayFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: OuestTheme.Spacing.xs) {
                // "All" chip
                filterChip(
                    label: "All",
                    color: nil,
                    isActive: viewModel.selectedDayFilter == nil,
                    action: {
                        HapticFeedback.selection()
                        withAnimation(OuestTheme.Anim.smooth) {
                            viewModel.selectedDayFilter = nil
                        }
                    }
                )

                // Per-day chips
                ForEach(viewModel.daysWithCoordinates) { day in
                    filterChip(
                        label: "Day \(day.dayNumber)",
                        color: day.routeColor,
                        isActive: viewModel.selectedDayFilter?.id == day.id,
                        action: {
                            HapticFeedback.selection()
                            withAnimation(OuestTheme.Anim.smooth) {
                                if viewModel.selectedDayFilter?.id == day.id {
                                    viewModel.selectedDayFilter = nil
                                } else {
                                    viewModel.selectedDayFilter = day
                                }
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, OuestTheme.Spacing.xs)
        }
        .padding(.vertical, OuestTheme.Spacing.sm)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
        )
    }

    private func filterChip(
        label: String,
        color: Color?,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: OuestTheme.Spacing.xs) {
                if let color {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                }
                Text(label)
                    .font(OuestTheme.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(isActive ? .white : OuestTheme.Colors.textPrimary)
            }
            .padding(.horizontal, OuestTheme.Spacing.md)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isActive ? (color ?? OuestTheme.Colors.brand) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    /// Days currently visible on the map based on the filter
    private var visibleDaysForMap: [ItineraryDay] {
        if let filter = viewModel.selectedDayFilter {
            return viewModel.daysWithCoordinates.filter { $0.id == filter.id }
        }
        return viewModel.daysWithCoordinates
    }

    /// True if at least one day has 2+ activities with coordinates (i.e. a drawable trail).
    /// When false, hiding/showing trails is meaningless so we hide the toolbar toggle.
    private var hasAnyTrails: Bool {
        viewModel.daysWithCoordinates.contains { day in
            day.sortedActivities.filter(\.hasCoordinates).count >= 2
        }
    }

    /// Opacity for a day's polyline + markers based on whether it's filtered
    private func opacityForDay(_ day: ItineraryDay) -> Double {
        guard let filter = viewModel.selectedDayFilter else { return 1.0 }
        return filter.id == day.id ? 1.0 : 0.25
    }

    /// Update camera to fit visible coordinates
    private func updateCameraPosition() {
        let activities: [Activity]
        if let filter = viewModel.selectedDayFilter {
            activities = filter.sortedActivities.filter(\.hasCoordinates)
        } else {
            activities = viewModel.allActivitiesWithCoordinates.map(\.activity)
        }

        guard !activities.isEmpty else { return }

        let coords = activities.map {
            CLLocationCoordinate2D(latitude: $0.latitude!, longitude: $0.longitude!)
        }

        let lats = coords.map(\.latitude)
        let lons = coords.map(\.longitude)
        let minLat = lats.min()!
        let maxLat = lats.max()!
        let minLon = lons.min()!
        let maxLon = lons.max()!

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        // Add padding via 1.5x span
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.5, 0.005),
            longitudeDelta: max((maxLon - minLon) * 1.5, 0.005)
        )

        withAnimation(.easeInOut(duration: 0.6)) {
            cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
        }
    }

    // MARK: - Empty State

    private var emptyMapView: some View {
        VStack(spacing: OuestTheme.Spacing.lg) {
            Image(systemName: "map")
                .font(.system(size: 48))
                .foregroundStyle(OuestTheme.Colors.textSecondary.opacity(0.4))

            Text("No locations yet")
                .font(OuestTheme.Typography.sectionTitle)
                .foregroundStyle(OuestTheme.Colors.textSecondary)

            Text("Add activities with locations\nto see them on the map")
                .font(OuestTheme.Typography.caption)
                .foregroundStyle(OuestTheme.Colors.textSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ItineraryMapView(
        viewModel: ItineraryViewModel(trip: Trip(
            id: UUID(), createdBy: UUID(), title: "Barcelona", destination: "Barcelona, Spain",
            status: .planning, isPublic: false, createdAt: Date(), updatedAt: Date()
        ))
    )
}
