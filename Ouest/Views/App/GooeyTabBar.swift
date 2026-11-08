import SwiftUI

/// Floating tab bar whose selected tab is a capsule that moves like liquid.
///
/// Two capsules ("head" and "tail") are drawn into one `Canvas`, blurred,
/// then cut back to a hard edge with `alphaThreshold` — the metaball trick.
/// On a tab change the head springs to the new tab quickly and the tail
/// follows on a slower spring, so for a moment they stretch into one shape
/// joined by a neck, then merge. The result masks `decorGradient`.
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

    /// Where the fast capsule (and the icons' layout) is.
    @State private var head: Int?
    /// Where the lagging capsule is. Differs from `head` only mid-move.
    @State private var tail: Int?

    // Geometry
    private let height: CGFloat = 48
    private let collapsed: CGFloat = 48
    private let centerWidth: CGFloat = 56
    private let gap: CGFloat = OuestTheme.Spacing.xs
    private let inset: CGFloat = OuestTheme.Spacing.xs
    private let blurRadius: CGFloat = 7

    private static var headSpring: Animation { .spring(duration: 0.35, bounce: 0.18) }
    private static var tailSpring: Animation { .spring(duration: 0.55, bounce: 0.08) }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width - inset * 2
            let headSel = head ?? selection
            let tailSel = tail ?? selection

            ZStack(alignment: .topLeading) {
                // Liquid capsule
                Rectangle()
                    .fill(OuestTheme.Colors.decorGradient)
                    .mask { liquid(width: width, head: headSel, tail: tailSel) }
                    .shadow(color: OuestTheme.Colors.brandFill.opacity(0.35), radius: 10, y: 2)
                    .allowsHitTesting(false)

                // Tabs and centre view
                ForEach(slots(width: width, selected: headSel), id: \.key) { slot in
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
        }
        .frame(height: height + inset * 2)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .ouestElevation(.lg, cornerRadius: (height + inset * 2) / 2)
        .onChange(of: selection) { _, newValue in move(to: newValue) }
    }

    // MARK: - Liquid

    private func liquid(width: CGFloat, head: Int, tail: Int) -> some View {
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
            blob(width: width, selected: head).tag(0)
            blob(width: width, selected: tail).tag(1)
        }
    }

    /// One capsule, laid out inside a full-width frame so its offset and
    /// width animate as ordinary view properties.
    private func blob(width: CGFloat, selected: Int) -> some View {
        let frame = slots(width: width, selected: selected).first { $0.tabID == selected }
        return ZStack(alignment: .leading) {
            Capsule()
                .frame(width: frame?.width ?? collapsed, height: height)
                .offset(x: frame?.x ?? 0)
        }
        .frame(width: width, height: height, alignment: .leading)
    }

    private func move(to newValue: Int) {
        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.25)) {
                head = newValue
                tail = newValue
            }
        } else {
            withAnimation(Self.headSpring) { head = newValue }
            withAnimation(Self.tailSpring) { tail = newValue }
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
                if isSelected {
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

    /// Order: tab 0, tab 1, centre, tab 2, tab 3. The selected tab takes
    /// whatever width the others leave.
    private func slots(width: CGFloat, selected: Int) -> [Slot] {
        let expanded = max(collapsed, width - (collapsed * 3 + centerWidth + gap * 4))
        var result: [Slot] = []
        var x: CGFloat = 0
        for position in 0..<5 {
            if position == 2 {
                result.append(Slot(key: "center", kind: .center, tabID: nil, x: x, width: centerWidth))
                x += centerWidth + gap
                continue
            }
            let item = items[position < 2 ? position : position - 1]
            let w = item.id == selected ? expanded : collapsed
            result.append(Slot(key: "tab\(item.id)", kind: .tab(item), tabID: item.id, x: x, width: w))
            x += w + gap
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
