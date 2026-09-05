import SwiftUI

/// 3D flippable medal — tap to spin and reveal the back face with "EARNED BY" text.
///
/// Used in the sticker detail view. Shows front (icon medal) and back (earned-by text)
/// with a 360° Y-axis coin flip animation on tap.
struct StickerMedalView: View {

    let stickerType: StickerType
    let userName: String
    let earnedDate: Date

    @State private var rotation: Double = 0

    /// Size of the medal (always large — 120pt)
    private let diameter: CGFloat = 120
    private let ringWidth: CGFloat = 13

    var body: some View {
        ZStack {
            // Front face — visible when rotation shows front
            frontFace
                .opacity(isFrontVisible ? 1 : 0)

            // Back face — visible when rotation shows back
            backFace
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(isFrontVisible ? 0 : 1)
        }
        .rotation3DEffect(
            .degrees(rotation),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.4
        )
        .onTapGesture {
            HapticFeedback.light()
            withAnimation(.spring(duration: 0.8, bounce: 0.15)) {
                rotation += 360
            }
        }
        .frame(width: diameter, height: diameter)
    }

    /// Determines which face to show based on current rotation
    private var isFrontVisible: Bool {
        let normalizedAngle = rotation.truncatingRemainder(dividingBy: 360)
        return normalizedAngle < 90 || normalizedAngle >= 270
    }

    // MARK: - Front Face

    private var frontFace: some View {
        StickerBadgeView(
            stickerType: stickerType,
            isUnlocked: true,
            size: .large
        )
    }

    // MARK: - Back Face

    private var backFace: some View {
        let discDiameter = diameter - ringWidth * 2 - 2

        return ZStack {
            // Metallic ring (same as front)
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
                .frame(width: diameter, height: diameter)
                .overlay {
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.25), .clear, .clear, .black.opacity(0.2)],
                                startPoint: .top, endPoint: .bottom
                            ),
                            lineWidth: 1.5
                        )
                }

            // Dark inner disc
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
                .overlay {
                    Circle()
                        .stroke(Color.black.opacity(0.4), lineWidth: 1)
                        .blur(radius: 1)
                }

            // "EARNED BY" text content
            VStack(spacing: 4) {
                // Ouest "O" logo
                Text("O")
                    .font(.custom("Fraunces", size: 18))
                    .fontWeight(.bold)
                    .foregroundStyle(stickerType.foilAltColor.opacity(0.7))

                // "EARNED BY" label
                Text("EARNED BY")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(stickerType.foilAltColor.opacity(0.5))

                // Username
                Text(userName.uppercased())
                    .font(.system(size: 13, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(stickerType.foilAltColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                // Date
                Text("ON \(earnedDate.formatted(.dateTime.month(.wide).day().year()).uppercased())")
                    .font(.system(size: 8, weight: .medium))
                    .tracking(1)
                    .foregroundStyle(stickerType.foilAltColor.opacity(0.5))
            }
            .padding(.horizontal, 16)
        }
        .frame(width: diameter, height: diameter)
        .shadow(color: .black.opacity(0.5), radius: 8, y: 4)
    }
}

// MARK: - Preview

#Preview("Medal Flip") {
    ZStack {
        Color(hex: 0x0E0F11).ignoresSafeArea()

        VStack(spacing: 32) {
            Text("Tap to flip")
                .foregroundStyle(.white.opacity(0.5))
                .font(.caption)

            StickerMedalView(
                stickerType: .og,
                userName: "TimTime",
                earnedDate: Date()
            )

            StickerMedalView(
                stickerType: .firstTrip,
                userName: "TimTime",
                earnedDate: Date()
            )
        }
    }
}
