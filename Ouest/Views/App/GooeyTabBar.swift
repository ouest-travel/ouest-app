import SwiftUI

/// Floating tab bar whose selected tab is a capsule that moves like liquid.
///
/// Two blobs ("head" and "tail") are drawn into one `Canvas`, blurred,
/// then cut back to a hard edge with `alphaThreshold` — the metaball trick.
/// On a tab change the head detaches from the old pill as a small drop and
/// springs ahead, inflating into the new pill; the old pill shrinks into a
/// drop that follows on a slower spring and merges in. While the two are
/// close the blur joins them with a neck that stretches and snaps. Both
/// blobs are smaller than the pill while travelling — that is what gives the
/// motion a visible neck instead of one long slab. The result masks
/// `decorGradient`.
///
/// The centre view (Create) sits between the second and third tabs and is
/// drawn above the capsule, so the liquid passes behind it.
///
/// Reduce Motion: head and tail move together with a plain ease, and the
/// label crossfades without blur.
struct GooeyTabBar<Center: View>: View {

    struct Item: Identifiable {
        let id: Int          // value written to `selection`
        let icon: String
        let filledIcon: String
        let label: String
        var badge: Int = 0
    }

    let items: [Item]        // exactly four
    @Binding var selection: Int
    @ViewBuilder let center: () -> Center

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Which tab the icons are laid out around (switches with the head).
    @State private var head: Int?
    /// The two metaball shapes. `nil` means "the resting pill of `selection`".
    @State private var headBlob: Blob?
    @State private var tailBlob: Blob?
    /// Inner width from the last layout pass, needed to compute blob frames
    /// inside `move(from:to:)`.
    @State private var barWidth: CGFloat = 0
    /// Bumped on every move so a stale animation completion can't park the
    /// tail in the wrong place.
    @State private var moveID = 0
    /// The selected tab shows its label for a moment after a switch, then
    /// the pill shrinks back around the icon so the bar stays quiet.
    @State private var showsLabel = false
    @State private var labelTask: Task<Void, Never>?
    private static var labelLinger: Duration { .seconds(2.5) }

    /// A capsule inside the bar's inner frame, vertically centred.
    struct Blob: Equatable {
        var x: CGFloat
        var width: CGFloat
        var height: CGFloat
    }

    // Geometry
    private let height: CGFloat = 48
    private let collapsed: CGFloat = 48
    private let centerWidth: CGFloat = 56
    private let gap: CGFloat = OuestTheme.Spacing.xs
    private let inset: CGFloat = OuestTheme.Spacing.xs
    /// Diameter of a blob while it travels. Smaller than `height` so the
    /// neck between two drops is visibly thinner than the drops.
    private let drop: CGFloat = 34
    // Blur sets how far apart two blobs can be and still be joined by a
    // neck. The threshold stays at 0.5 so a lone blob keeps its exact
    // outline — only the join between the two is affected.
    private let blurRadius: CGFloat = 12

    private static var headSpring: Animation { .spring(duration: 0.34, bounce: 0.28) }
    /// Old pill → drop.
    private static var shrinkSpring: Animation { .spring(duration: 0.22, bounce: 0) }
    /// Drop follows the head and merges.
    private static var tailSpring: Animation { .spring(duration: 0.5, bounce: 0.1) }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width - inset * 2
            let headSel = head ?? selection
            let rest = pill(width: width, selected: selection, labelled: showsLabel)

            ZStack(alignment: .topLeading) {
                // Liquid capsule
                Rectangle()
                    .fill(OuestTheme.Colors.decorGradient)
                    .mask { liquid(width: width, head: headBlob ?? rest, tail: tailBlob ?? rest) }
                    .shadow(color: OuestTheme.Colors.brandFill.opacity(0.35), radius: 10, y: 2)
                    .allowsHitTesting(false)

                // Tabs and centre view
                ForEach(slots(width: width, selected: headSel, labelled: showsLabel), id: \.key) { slot in
                    Group {
                        switch slot.kind {
                        case .tab(let item):
                            tabButton(item, isSelected: item.id == headSel)
                        case .center:
                            center()
                        }
                    }
                    .frame(width: slot.width, height: height)
                    .offset(x: slot.x)
                }
            }
            .padding(inset)
            .onChange(of: width, initial: true) { _, w in barWidth = w }
        }
        .frame(height: height + inset * 2)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .ouestElevation(.lg, cornerRadius: (height + inset * 2) / 2)
        .onChange(of: selection) { oldValue, newValue in move(from: oldValue, to: newValue) }
    }

    // MARK: - Liquid

    private func liquid(width: CGFloat, head: Blob, tail: Blob) -> some View {
        Canvas { context, size in
            context.addFilter(.alphaThreshold(min: 0.5))
            context.addFilter(.blur(radius: blurRadius))
            context.drawLayer { layer in
                for tag in [0, 1] {
                    if let symbol = layer.resolveSymbol(id: tag) {
                        layer.draw(symbol, at: CGPoint(x: size.width / 2, y: size.height / 2))
                    }
                }
            }
        } symbols: {
            blobView(head, width: width).tag(0)
            blobView(tail, width: width).tag(1)
        }
    }

    /// One capsule, laid out inside a full-width frame so its offset and
    /// size animate as ordinary view properties.
    private func blobView(_ blob: Blob, width: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            Capsule()
                .frame(width: blob.width, height: blob.height)
                .offset(x: blob.x)
        }
        .frame(width: width, height: height, alignment: .leading)
    }

    /// The resting pill over a tab: wide with the label, a disc without.
    private func pill(width: CGFloat, selected: Int, labelled: Bool) -> Blob {
        let slot = slots(width: width, selected: selected, labelled: labelled).first { $0.tabID == selected }
        return Blob(x: slot?.x ?? 0, width: slot?.width ?? collapsed, height: height)
    }

    /// A travelling drop centred on a pill.
    private func dropBlob(centredOn pill: Blob) -> Blob {
        Blob(x: pill.x + (pill.width - drop) / 2, width: drop, height: drop)
    }

    private func move(from oldValue: Int, to newValue: Int) {
        moveID += 1
        let id = moveID
        let from = pill(width: barWidth, selected: oldValue, labelled: showsLabel)
        let to = pill(width: barWidth, selected: newValue, labelled: true)
        scheduleLabelCollapse(for: id)

        if reduceMotion || barWidth == 0 {
            withAnimation(.easeInOut(duration: 0.25)) {
                head = newValue
                showsLabel = true
                headBlob = to
                tailBlob = to
            }
            return
        }

        let fromDrop = dropBlob(centredOn: from)
        let toDrop = dropBlob(centredOn: to)

        // Head: park as a drop inside the old pill (hidden by the tail, which
        // still is the old pill), then one frame later fly to the new tab and
        // inflate. The frame's delay is what makes SwiftUI animate from the
        // drop rather than from the old pill.
        var still = Transaction()
        still.disablesAnimations = true
        withTransaction(still) { headBlob = fromDrop }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(16))
            guard moveID == id else { return }
            withAnimation(Self.headSpring) {
                head = newValue
                showsLabel = true
                headBlob = to
            }
        }

        // Tail: the old pill shrinks into a drop, follows the head, merges.
        withAnimation(Self.shrinkSpring) {
            tailBlob = fromDrop
        } completion: {
            guard moveID == id else { return }
            withAnimation(Self.tailSpring) {
                tailBlob = toDrop
            } completion: {
                guard moveID == id else { return }
                // Park inside the new pill so the next move shrinks from a
                // full pill, not from a drop.
                withTransaction(still) { tailBlob = to }
            }
        }
    }

    /// After the label has lingered, shrink the pill back around the icon.
    /// Clearing the blobs lets them follow the resting pill again.
    private func scheduleLabelCollapse(for id: Int) {
        labelTask?.cancel()
        labelTask = Task { @MainActor in
            try? await Task.sleep(for: Self.labelLinger)
            guard !Task.isCancelled, moveID == id else { return }
            withAnimation(reduceMotion ? .easeInOut(duration: 0.25) : .spring(duration: 0.45, bounce: 0.18)) {
                showsLabel = false
                headBlob = nil
                tailBlob = nil
            }
        }
    }

    // MARK: - Tab button

    private func tabButton(_ item: Item, isSelected: Bool) -> some View {
        Button {
            guard selection != item.id else { return }
            HapticFeedback.selection()
            selection = item.id
        } label: {
            HStack(spacing: OuestTheme.Spacing.xs + 2) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: isSelected ? item.filledIcon : item.icon)
                        .font(OuestTheme.Icon.inline.weight(.semibold))
                    if item.badge > 0 {
                        Text("\(min(item.badge, 99))")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(OuestTheme.Colors.error, in: Capsule())
                            .offset(x: 10, y: -8)
                    }
                }
                if isSelected && showsLabel {
                    Text(item.label)
                        .font(OuestTheme.Typography.body.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .transition(reduceMotion ? .opacity : .blurFade)
                }
            }
            .foregroundStyle(isSelected ? OuestTheme.Colors.textInverse : OuestTheme.Colors.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.badge > 0 ? "\(item.label), \(item.badge) unread" : item.label)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Layout

    private enum SlotKind {
        case tab(Item)
        case center
    }

    private struct Slot {
        let key: String
        let kind: SlotKind
        let tabID: Int?
        let x: CGFloat
        let width: CGFloat
    }

    /// Order: tab 0, tab 1, centre, tab 2, tab 3. While labelled, the
    /// selected tab takes whatever width the others leave; otherwise every
    /// tab is `collapsed` and the leftover is spread evenly between them.
    private func slots(width: CGFloat, selected: Int, labelled: Bool) -> [Slot] {
        let fixed = collapsed * 3 + centerWidth
        let expanded = labelled ? max(collapsed, width - fixed - gap * 4) : collapsed
        let spacing = labelled ? gap : max(gap, (width - fixed - collapsed) / 4)
        var result: [Slot] = []
        var x: CGFloat = 0
        for position in 0..<5 {
            if position == 2 {
                result.append(Slot(key: "center", kind: .center, tabID: nil, x: x, width: centerWidth))
                x += centerWidth + spacing
                continue
            }
            let item = items[position < 2 ? position : position - 1]
            let w = item.id == selected ? expanded : collapsed
            result.append(Slot(key: "tab\(item.id)", kind: .tab(item), tabID: item.id, x: x, width: w))
            x += w + spacing
        }
        return result
    }
}

// MARK: - Blur transition

private struct BlurFade: ViewModifier {
    let active: Bool
    func body(content: Content) -> some View {
        content
            .blur(radius: active ? 6 : 0)
            .opacity(active ? 0 : 1)
    }
}

private extension AnyTransition {
    static var blurFade: AnyTransition {
        .modifier(active: BlurFade(active: true), identity: BlurFade(active: false))
    }
}

#Preview {
    @Previewable @State var selection = 0
    VStack {
        Spacer()
        GooeyTabBar(
            items: [
                .init(id: 0, icon: "house", filledIcon: "house.fill", label: "Home"),
                .init(id: 1, icon: "safari", filledIcon: "safari.fill", label: "Explore"),
                .init(id: 3, icon: "bell", filledIcon: "bell.fill", label: "Activity", badge: 3),
                .init(id: 4, icon: "person", filledIcon: "person.fill", label: "Profile"),
            ],
            selection: $selection
        ) {
            Circle()
                .fill(OuestTheme.Colors.inkGradient)
                .frame(width: 48, height: 48)
                .overlay(Image(systemName: "plus").foregroundStyle(.white))
        }
        .padding(.horizontal, OuestTheme.Spacing.xl)
    }
    .background(OuestTheme.Colors.background)
}
