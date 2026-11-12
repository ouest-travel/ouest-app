import SwiftUI

/// The holder's passport: the book up top, the stamps listed beneath it.
///
/// Stamps come from completed trips, so the book is built once the trips
/// have loaded and rebuilt (via `id`) only when the data changes.
struct PassportView: View {

    @Environment(AuthViewModel.self) private var authViewModel
    @State private var trips = TripsViewModel()
    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: OuestTheme.Layout.sectionGap) {
                if trips.isLoading && trips.trips.isEmpty {
                    bookSkeleton
                } else if let book {
                    VStack(spacing: OuestTheme.Spacing.md) {
                        PassportBookView(book: book)
                            .id(book)
                        Text(hint(for: book))
                            .font(OuestTheme.Typography.caption)
                            .foregroundStyle(OuestTheme.Colors.textTertiary)
                            .multilineTextAlignment(.center)
                    }
                    .fadeSlideIn(isVisible: appeared, delay: 0)

                    stampsSection(book.stamps)
                        .fadeSlideIn(isVisible: appeared, delay: 0.1)
                }
            }
            .padding(.horizontal, OuestTheme.Layout.pageGutter)
            .padding(.top, OuestTheme.Spacing.md)
            .padding(.bottom, OuestTheme.Layout.tabBarInset)
        }
        .background(OuestTheme.Colors.background)
        .navigationTitle("Passport")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await trips.fetchTrips()
            withAnimation(OuestTheme.Anim.smooth) {
                appeared = true
            }
        }
        .refreshable {
            await trips.fetchTrips()
        }
    }

    private var book: PassportBook? {
        guard let profile = authViewModel.currentUser else { return nil }
        return PassportBook(
            holderName: profile.fullName ?? "Traveler",
            nationality: profile.nationality,
            memberSince: profile.createdAt,
            stamps: PassportStamp.stamps(from: trips.trips)
        )
    }

    private func hint(for book: PassportBook) -> String {
        if #available(iOS 18.0, *) {
            return book.nationality == nil
                ? "Tap to open. Add your nationality in Edit Profile for your country's cover."
                : "Tap to open, tap a page to turn it."
        }
        return "The 3D passport needs iOS 18."
    }

    private var bookSkeleton: some View {
        RoundedRectangle(cornerRadius: OuestTheme.Radius.lg, style: .continuous)
            .fill(OuestTheme.Colors.fill)
            .aspectRatio(1.45, contentMode: .fit)
            .shimmer()
    }

    // MARK: Stamps

    @ViewBuilder
    private func stampsSection(_ stamps: [PassportStamp]) -> some View {
        if stamps.isEmpty {
            OuestEmptyState(
                symbol: "book.closed",
                title: "Stamps land when a trip ends",
                message: "Every trip you finish gets a stamp in here."
            )
        } else {
            VStack(alignment: .leading, spacing: OuestTheme.Spacing.md) {
                Text("Stamps")
                    .font(OuestTheme.Typography.sectionTitle)
                    .foregroundStyle(OuestTheme.Colors.textPrimary)
                ForEach(stamps.reversed()) { stamp in
                    NavigationLink(value: stamp.id) {
                        stampRow(stamp)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func stampRow(_ stamp: PassportStamp) -> some View {
        OuestCard {
            HStack(spacing: OuestTheme.Spacing.md) {
                Text(stamp.countryCode.map(CountryHelper.flag(for:)) ?? "✈︎")
                    .font(OuestTheme.Icon.control)
                VStack(alignment: .leading, spacing: OuestTheme.Spacing.xxs) {
                    Text(stamp.destination)
                        .font(OuestTheme.Typography.cardTitle)
                        .foregroundStyle(OuestTheme.Colors.textPrimary)
                    if let dates = dateRange(stamp) {
                        Text(dates)
                            .font(OuestTheme.Typography.caption)
                            .foregroundStyle(OuestTheme.Colors.textSecondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(OuestTheme.Colors.textTertiary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func dateRange(_ stamp: PassportStamp) -> String? {
        switch (stamp.arrival, stamp.departure) {
        case let (arrival?, departure?):
            return (arrival..<departure).formatted(.interval.day().month(.abbreviated).year())
        case let (arrival?, nil):
            return arrival.formatted(date: .abbreviated, time: .omitted)
        default:
            return nil
        }
    }
}

// MARK: - Preview

#Preview("Passport") {
    NavigationStack {
        PassportView()
            .environment(AuthViewModel())
    }
}
