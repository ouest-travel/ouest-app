import SwiftUI

/// Full sticker collection grid — shows all 12 stickers with unlock state.
struct StickersCollectionView: View {

    @Bindable var viewModel: StickersViewModel
    let userName: String
    @State private var contentAppeared = false
    @State private var selectedSticker: StickerType?
    @Environment(\.dismiss) private var dismiss

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: OuestTheme.Spacing.xxl) {
                    // Header count
                    headerSection

                    // Sticker grid
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(Array(StickerType.allCases.enumerated()), id: \.element) { index, type in
                            stickerCell(type: type, index: index)
                        }
                    }
                    .padding(.horizontal, OuestTheme.Spacing.lg)
                }
                .padding(.vertical, OuestTheme.Spacing.xl)
            }
            .background(Color("Background"))
            .navigationTitle("Stickers")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(OuestTheme.Colors.brand)
                }
            }
            .sheet(item: $selectedSticker) { type in
                if let sticker = viewModel.userSticker(for: type) {
                    StickerDetailView(
                        stickerType: type,
                        userSticker: sticker,
                        userName: userName,
                        viewModel: viewModel
                    )
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                }
            }
            .task {
                if viewModel.allStickers.isEmpty {
                    await viewModel.loadStickers()
                }
                withAnimation(OuestTheme.Anim.smooth.delay(0.1)) {
                    contentAppeared = true
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: OuestTheme.Spacing.xs) {
                Text("Your Collection")
                    .font(OuestTheme.Typography.cardTitle)
                    .foregroundStyle(OuestTheme.Colors.textPrimary)

                Text("\(viewModel.unlockedCount) of \(viewModel.totalCount) unlocked")
                    .font(.subheadline)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
            }

            Spacer()

            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 3)
                    .frame(width: 44, height: 44)

                Circle()
                    .trim(from: 0, to: CGFloat(viewModel.unlockedCount) / CGFloat(viewModel.totalCount))
                    .stroke(OuestTheme.Colors.brand, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))

                Text("\(viewModel.unlockedCount)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(OuestTheme.Colors.brand)
            }
        }
        .padding(.horizontal, OuestTheme.Spacing.lg)
        .fadeSlideIn(isVisible: contentAppeared, delay: 0)
    }

    // MARK: - Sticker Cell

    private func stickerCell(type: StickerType, index: Int) -> some View {
        let unlocked = viewModel.isUnlocked(type)

        return Button {
            if unlocked {
                HapticFeedback.light()
                selectedSticker = type
            }
        } label: {
            VStack(spacing: OuestTheme.Spacing.sm) {
                StickerBadgeView(
                    stickerType: type,
                    isUnlocked: unlocked,
                    size: .medium
                )

                Text(type.displayName)
                    .font(OuestTheme.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(unlocked ? OuestTheme.Colors.textPrimary : OuestTheme.Colors.textSecondary.opacity(0.5))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(type.unlockCriteria)
                    .font(OuestTheme.Typography.micro)
                    .foregroundStyle(unlocked ? OuestTheme.Colors.textSecondary : OuestTheme.Colors.textSecondary.opacity(0.3))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(height: 28)
            }
        }
        .buttonStyle(.plain)
        .cardEntrance(isVisible: contentAppeared, delay: Double(index) * 0.04)
    }
}

// MARK: - Make StickerType Identifiable for sheet binding

extension StickerType: Identifiable {
    var id: String { rawValue }
}
