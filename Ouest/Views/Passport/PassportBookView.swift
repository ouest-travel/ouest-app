import RealityKit
import SwiftUI

/// The passport book: a cover in the holder's nationality colours and a
/// stamp for every finished trip.
///
/// iOS 18+ renders the RealityKit book (`RealityPassportView`): tap the
/// cover to open it, tap or flick a page to turn it, drag to tilt. iOS 17
/// gets a flat card with the same information.
struct PassportBookView: View {

    let book: PassportBook

    var body: some View {
        if #available(iOS 18.0, *) {
            RealityPassportView(book: book)
        } else {
            FlatPassportCard(book: book)
        }
    }
}

@available(iOS 18.0, *)
struct RealityPassportView: View {

    let book: PassportBook

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var motion = PassportMotion()
    @State private var spread = 0
    @State private var width: CGFloat = 0
    @State private var failed = false

    /// Frames an open spread with a little air; the camera is set to match.
    static let aspectRatio: CGFloat = 1.45

    var body: some View {
        RealityView { content in
            motion.reduceMotion = reduceMotion
            do {
                try await PassportScene.build(in: &content, book: book, motion: motion)
            } catch {
                failed = true
            }
        } placeholder: {
            ProgressView()
        }
        .aspectRatio(Self.aspectRatio, contentMode: .fit)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 8)
                .onChanged { value in
                    motion.dragChanged(translation: value.translation)
                }
                .onEnded { value in
                    motion.dragEnded()
                    flick(value.velocity)
                }
        )
        .onTapGesture(coordinateSpace: .local) { location in
            tap(at: location)
        }
        .overlay {
            if failed {
                Text("The passport couldn't be loaded.")
                    .font(OuestTheme.Typography.caption)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
            }
        }
        .onChange(of: reduceMotion, initial: true) { _, newValue in
            motion.reduceMotion = newValue
        }
        .onAppear {
            motion.onSpreadChange = { spread = $0 }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Passport, \(book.stamps.count) stamps")
        .accessibilityValue(spread == 0 ? "Closed" : "Pages \(spread * 2 - 1) and \(spread * 2)")
        .accessibilityHint(spread == 0 ? "Double tap to open" : "Double tap to turn the page")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Previous page") { motion.previous() }
    }

    private func tap(at location: CGPoint) {
        if motion.spread == 0 {
            motion.open()
        } else if location.x < width / 2 {
            motion.previous()
        } else {
            motion.next()
        }
    }

    /// A horizontal flick turns a page the way the finger moved.
    private func flick(_ velocity: CGSize) {
        guard abs(velocity.width) > 350, abs(velocity.width) > abs(velocity.height) else { return }
        if velocity.width < 0 {
            if motion.spread == 0 { motion.open() } else { motion.next() }
        } else {
            motion.previous()
        }
    }
}

/// iOS 17 fallback: the book's facts without the 3D render.
private struct FlatPassportCard: View {
    let book: PassportBook

    var body: some View {
        OuestCard {
            VStack(alignment: .leading, spacing: OuestTheme.Spacing.sm) {
                Text("Passport")
                    .font(OuestTheme.Typography.sectionTitle)
                    .foregroundStyle(OuestTheme.Colors.textPrimary)
                Text(book.country.map { "\($0.flag) \($0.name)" } ?? "Traveller")
                    .font(OuestTheme.Typography.body)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
                Text("\(book.stamps.count) stamps")
                    .font(OuestTheme.Typography.caption)
                    .foregroundStyle(OuestTheme.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Preview

@available(iOS 18.0, *)
#Preview("Passport book") {
    ZStack {
        OuestTheme.Colors.background.ignoresSafeArea()
        PassportBookView(book: PassportBook.preview)
            .padding(OuestTheme.Layout.pageGutter)
    }
}

@available(iOS 18.0, *)
#Preview("Passport book, dark") {
    ZStack {
        OuestTheme.Colors.background.ignoresSafeArea()
        PassportBookView(book: PassportBook.preview)
            .padding(OuestTheme.Layout.pageGutter)
    }
    .preferredColorScheme(.dark)
}

extension PassportBook {
    /// A Nigerian passport holder with five finished trips.
    static var preview: PassportBook {
        let destinations: [(String, String)] = [
            ("Lisbon", "PRT"), ("Marrakech", "MAR"), ("Tokyo", "JPN"), ("Mexico City", "MEX"), ("Reykjavík", "ISL")
        ]
        let stamps = destinations.enumerated().map { index, item in
            PassportStamp(trip: Trip(
                id: UUID(uuidString: "0000000\(index)-0000-0000-0000-00000000000\(index)")!,
                createdBy: UUID(), title: item.0, destination: item.0, description: nil, coverImageUrl: nil,
                startDate: Calendar.current.date(byAdding: .month, value: -(index + 1) * 3, to: .now),
                endDate: Calendar.current.date(byAdding: .day, value: 6, to: Calendar.current.date(byAdding: .month, value: -(index + 1) * 3, to: .now)!),
                status: .completed, isPublic: false, budget: nil, currency: nil, votingEnabled: nil, tags: nil,
                countryCodes: [item.1], coverAttribution: nil, coverAttributionUrl: nil, createdAt: nil, updatedAt: nil
            ))
        }
        return PassportBook(holderName: "Timmy Afolabi", nationality: "NGA", memberSince: .now, stamps: stamps)
    }
}
