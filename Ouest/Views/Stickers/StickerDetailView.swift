import SwiftUI

/// Detail sheet for a single sticker — shows flippable medal, description, and equip toggle.
struct StickerDetailView: View {

    let stickerType: StickerType
    let userSticker: UserSticker
    let userName: String
    @Bindable var viewModel: StickersViewModel

    @State private var appeared = false
    @Environment(\.dismiss) private var dismiss

    private var isEquipped: Bool {
        viewModel.allStickers.first(where: { $0.id == userSticker.id })?.equipped ?? false
    }

    private var canEquip: Bool {
        isEquipped || viewModel.equippedCount < 4
    }

    var body: some View {
        VStack(spacing: OuestTheme.Spacing.xxl) {
            // Drag indicator spacing
            Spacer().frame(height: 8)

            // 3D flippable medal — tap to spin
            StickerMedalView(
                stickerType: stickerType,
                userName: userName,
                earnedDate: userSticker.unlockedAt
            )
            .bouncyAppear(isVisible: appeared, delay: 0.1)

            // Name + description
            VStack(spacing: OuestTheme.Spacing.sm) {
                Text(stickerType.displayName)
                    .font(OuestTheme.Typography.screenTitle)
                    .foregroundStyle(OuestTheme.Colors.textPrimary)

                Text(stickerType.description)
                    .font(.subheadline)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, OuestTheme.Spacing.xxl)
            }
            .fadeSlideIn(isVisible: appeared, delay: 0.2)

            // Unlock date
            HStack(spacing: OuestTheme.Spacing.sm) {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)

                Text("Unlocked \(userSticker.unlockedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(OuestTheme.Typography.caption)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
            }
            .fadeSlideIn(isVisible: appeared, delay: 0.25)

            Spacer()

            // Equip toggle button
            Button {
                viewModel.toggleEquip(userSticker)
                if isEquipped {
                    // Was just unequipped
                } else {
                    HapticFeedback.success()
                }
            } label: {
                HStack(spacing: OuestTheme.Spacing.sm) {
                    Image(systemName: isEquipped ? "minus.circle" : "plus.circle")
                    Text(isEquipped ? "Remove from Profile" : "Show on Profile")
                }
                .font(.body.weight(.semibold))
                .foregroundStyle(isEquipped ? OuestTheme.Colors.textSecondary : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    isEquipped
                        ? AnyShapeStyle(Color("SurfaceSecondary"))
                        : AnyShapeStyle(OuestTheme.Colors.brandGradient)
                )
                .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
            }
            .disabled(!canEquip && !isEquipped)
            .opacity(!canEquip && !isEquipped ? 0.5 : 1)
            .padding(.horizontal, OuestTheme.Spacing.lg)
            .fadeSlideIn(isVisible: appeared, delay: 0.3)

            if !canEquip && !isEquipped {
                Text("Remove a sticker first (max 4)")
                    .font(OuestTheme.Typography.micro)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
            }

            Spacer().frame(height: OuestTheme.Spacing.lg)
        }
        .background(Color("Background"))
        .onAppear {
            withAnimation(OuestTheme.Anim.smooth) {
                appeared = true
            }
        }
    }
}
