import SwiftUI

/// V4 Apple Fitness Awards-style medal badge.
///
/// Thick metallic ring with conic gradient, dark inner disc, and bold
/// colored icon. Inspired by Apple Fitness achievement medals.
struct StickerBadgeView: View {

    let stickerType: StickerType
    let isUnlocked: Bool
    let size: BadgeSize

    enum BadgeSize {
        case small  // 36pt — profile banner
        case medium // 52pt — collection grid
        case large  // 120pt — detail view

        var diameter: CGFloat {
            switch self {
            case .small: return 36
            case .medium: return 52
            case .large: return 120
            }
        }

        /// Metallic ring thickness — ~10% of diameter
        var ringWidth: CGFloat {
            switch self {
            case .small: return 4
            case .medium: return 6
            case .large: return 13
            }
        }

        /// Icon size — ~38% of diameter
        var iconSize: CGFloat {
            switch self {
            case .small: return 14
            case .medium: return 20
            case .large: return 46
            }
        }

        var lockSize: CGFloat {
            switch self {
            case .small: return 12
            case .medium: return 16
            case .large: return 28
            }
        }
    }

    var body: some View {
        ZStack {
            if isUnlocked {
                unlockedMedal
            } else {
                lockedMedal
            }
        }
        .frame(width: size.diameter, height: size.diameter)
    }

    // MARK: - Unlocked Medal

    private var unlockedMedal: some View {
        let discDiameter = size.diameter - size.ringWidth * 2 - 2

        return ZStack {
            // 1. Thick metallic ring — conic gradient
            Circle()
                .fill(
                    AngularGradient(
                        colors: [
                            stickerType.foilDeepColor,
                            stickerType.foilColor,
                            stickerType.foilAltColor,
                            stickerType.foilColor,
                            stickerType.foilDeepColor,
                            stickerType.foilColor,
                            stickerType.foilAltColor,
                            stickerType.foilColor,
                            stickerType.foilDeepColor
                        ],
                        center: .center
                    )
                )
                .frame(width: size.diameter, height: size.diameter)
                // Embossed ring: inner highlight top + shadow bottom
                .overlay {
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.25),
                                    .clear,
                                    .clear,
                                    .black.opacity(0.2)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: size == .large ? 1.5 : 0.75
                        )
                }

            // 2. Dark inner disc
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: 0x252528),
                            Color(hex: 0x1A1A1E),
                            Color(hex: 0x111113),
                            Color(hex: 0x0E0F11)
                        ],
                        center: .init(x: 0.35, y: 0.3),
                        startRadius: 0,
                        endRadius: discDiameter * 0.8
                    )
                )
                .frame(width: discDiameter, height: discDiameter)
                // Subtle inner shadow on disc
                .overlay {
                    Circle()
                        .stroke(Color.black.opacity(0.4), lineWidth: 1)
                        .blur(radius: 1)
                }

            // 3. Bold colored icon
            Image(systemName: stickerType.icon)
                .font(.system(size: size.iconSize, weight: .semibold))
                .foregroundStyle(stickerType.foilColor)
                .shadow(color: stickerType.foilColor.opacity(0.3), radius: size == .large ? 8 : 3)
                .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
        }
        // Medal drop shadow
        .shadow(color: .black.opacity(0.5), radius: size == .large ? 8 : 3, y: size == .large ? 4 : 1)
    }

    // MARK: - Locked Medal

    private var lockedMedal: some View {
        let discDiameter = size.diameter - size.ringWidth * 2 - 2

        return ZStack {
            // Gray metallic ring
            Circle()
                .fill(
                    AngularGradient(
                        colors: [
                            Color(hex: 0x2A2A2E),
                            Color(hex: 0x4A4A4E),
                            Color(hex: 0x3A3A3E),
                            Color(hex: 0x555555),
                            Color(hex: 0x2A2A2E),
                            Color(hex: 0x4A4A4E),
                            Color(hex: 0x3A3A3E),
                            Color(hex: 0x555555),
                            Color(hex: 0x2A2A2E)
                        ],
                        center: .center
                    )
                )
                .frame(width: size.diameter, height: size.diameter)
                .overlay {
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.08), .clear, .clear, .black.opacity(0.15)],
                                startPoint: .top, endPoint: .bottom
                            ),
                            lineWidth: size == .large ? 1 : 0.5
                        )
                }

            // Dark inner disc
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: 0x222224), Color(hex: 0x1A1A1C), Color(hex: 0x131315)],
                        center: .init(x: 0.35, y: 0.3),
                        startRadius: 0,
                        endRadius: discDiameter * 0.8
                    )
                )
                .frame(width: discDiameter, height: discDiameter)

            // Dimmed icon
            Image(systemName: stickerType.icon)
                .font(.system(size: size.iconSize, weight: .semibold))
                .foregroundStyle(.white.opacity(0.15))

            // Lock badge (bottom-right)
            if size != .small {
                Image(systemName: "lock.fill")
                    .font(.system(size: size.lockSize * 0.5))
                    .foregroundStyle(Color(hex: 0x666666))
                    .frame(width: size.lockSize, height: size.lockSize)
                    .background(Color(hex: 0x0E0F11))
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(Color(hex: 0x3A3A3E), lineWidth: 1.5)
                    )
                    .offset(
                        x: size.diameter / 2 - size.lockSize / 2,
                        y: size.diameter / 2 - size.lockSize / 2
                    )
            }
        }
        .shadow(color: .black.opacity(0.3), radius: size == .large ? 6 : 2, y: 1)
    }
}

// MARK: - Preview

#Preview("V4 Medal Badges") {
    ZStack {
        Color(hex: 0x0E0F11).ignoresSafeArea()

        VStack(spacing: 32) {
            Text("Unlocked")
                .foregroundStyle(.white)
                .font(.headline)

            HStack(spacing: 20) {
                StickerBadgeView(stickerType: .og, isUnlocked: true, size: .small)
                StickerBadgeView(stickerType: .og, isUnlocked: true, size: .medium)
                StickerBadgeView(stickerType: .og, isUnlocked: true, size: .large)
            }

            Text("Locked")
                .foregroundStyle(.white)
                .font(.headline)

            HStack(spacing: 20) {
                StickerBadgeView(stickerType: .og, isUnlocked: false, size: .small)
                StickerBadgeView(stickerType: .og, isUnlocked: false, size: .medium)
                StickerBadgeView(stickerType: .og, isUnlocked: false, size: .large)
            }

            Text("All Types (Medium)")
                .foregroundStyle(.white)
                .font(.headline)

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(60)), count: 6), spacing: 16) {
                ForEach(StickerType.allCases, id: \.self) { type in
                    StickerBadgeView(stickerType: type, isUnlocked: true, size: .medium)
                }
            }
        }
        .padding()
    }
}
