import SwiftUI
import MapKit

struct ItineraryMapView: View {
    @Bindable var viewModel: ItineraryViewModel
    @Environment(\.dismiss) private var dismiss

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
                }
            }
        }
    }

    // MARK: - Map Content

    private var mapContent: some View {
        let items = viewModel.allActivitiesWithCoordinates

        return Map {
            ForEach(items, id: \.activity.id) { item in
                let coord = CLLocationCoordinate2D(
                    latitude: item.activity.latitude!,
                    longitude: item.activity.longitude!
                )

                Annotation(item.activity.title, coordinate: coord) {
                    VStack(spacing: 2) {
                        Image(systemName: item.activity.category.icon)
                            .font(.caption)
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(item.activity.category.color)
                            .clipShape(Circle())
                            .shadow(OuestTheme.Shadow.sm)

                        Text(item.activity.title)
                            .font(OuestTheme.Typography.micro)
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .padding(.horizontal, OuestTheme.Spacing.xs)
                            .padding(.vertical, 2)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .including([
            .restaurant, .hotel, .museum, .park, .airport, .publicTransport
        ])))
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
