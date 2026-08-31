import SwiftUI
import MapKit

/// Lightweight search-and-add sheet — find a place, tap to instantly add it as an activity.
struct QuickAddActivityView: View {

    @Bindable var viewModel: ItineraryViewModel
    let day: ItineraryDay
    @Environment(\.dismiss) private var dismiss

    @State private var searchTask: Task<Void, Never>?
    @State private var localQuery = ""
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: OuestTheme.Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                        .font(.body)

                    TextField("Search places...", text: $localQuery)
                        .font(.body)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($isSearchFocused)

                    if !localQuery.isEmpty {
                        Button {
                            localQuery = ""
                            viewModel.searchResults = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(OuestTheme.Colors.textSecondary)
                        }
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding(.horizontal, OuestTheme.Spacing.md)
                .frame(height: 48)
                .background(OuestTheme.Colors.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.sm))
                .padding(.horizontal, OuestTheme.Spacing.lg)
                .padding(.top, OuestTheme.Spacing.sm)

                // Results or empty state
                if viewModel.isSearching {
                    Spacer()
                    ProgressView()
                        .tint(OuestTheme.Colors.brand)
                    Spacer()
                } else if viewModel.searchResults.isEmpty && !localQuery.isEmpty {
                    Spacer()
                    VStack(spacing: OuestTheme.Spacing.sm) {
                        Image(systemName: "mappin.slash")
                            .font(.title2)
                            .foregroundStyle(OuestTheme.Colors.textSecondary)
                        Text("No places found")
                            .font(OuestTheme.Typography.caption)
                            .foregroundStyle(OuestTheme.Colors.textSecondary)
                    }
                    Spacer()
                } else if viewModel.searchResults.isEmpty {
                    Spacer()
                    VStack(spacing: OuestTheme.Spacing.sm) {
                        Image(systemName: "magnifyingglass")
                            .font(.title2)
                            .foregroundStyle(OuestTheme.Colors.textSecondary.opacity(0.5))
                        Text("Search for a restaurant, hotel,\nlandmark, or activity")
                            .font(OuestTheme.Typography.caption)
                            .foregroundStyle(OuestTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                } else {
                    resultsList
                }
            }
            .navigationTitle("Quick Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(OuestTheme.Colors.brand)
                }
            }
            .onAppear {
                isSearchFocused = true
            }
            .onChange(of: localQuery) { _, newValue in
                viewModel.searchQuery = newValue
                searchTask?.cancel()
                searchTask = Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    guard !Task.isCancelled else { return }
                    await viewModel.searchPlaces()
                }
            }
        }
    }

    // MARK: - Results List

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.searchResults.prefix(8), id: \.self) { item in
                    resultRow(item)
                }
            }
            .padding(.top, OuestTheme.Spacing.sm)
        }
    }

    private func resultRow(_ item: MKMapItem) -> some View {
        let category = ActivityCategory.from(pointOfInterest: item.pointOfInterestCategory)

        return Button {
            Task {
                let success = await viewModel.quickAddActivity(from: item, toDay: day)
                if success {
                    dismiss()
                }
            }
        } label: {
            HStack(spacing: OuestTheme.Spacing.md) {
                // Category icon
                Image(systemName: category.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(category.color)
                    .clipShape(Circle())

                // Place info
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name ?? "Unknown")
                        .font(.body)
                        .foregroundStyle(OuestTheme.Colors.textPrimary)
                        .lineLimit(1)

                    if let address = item.placemark.formattedAddress {
                        Text(address)
                            .font(OuestTheme.Typography.caption)
                            .foregroundStyle(OuestTheme.Colors.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Add indicator
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(OuestTheme.Colors.brand)
            }
            .padding(.horizontal, OuestTheme.Spacing.lg)
            .padding(.vertical, OuestTheme.Spacing.md)
        }
        .buttonStyle(.plain)
    }
}
