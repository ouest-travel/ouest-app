import SwiftUI

struct JoinTripView: View {
    let inviteCode: String
    var onJoined: ((UUID) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = JoinTripViewModel()
    @State private var contentAppeared = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    loadingView
                } else if let tripId = viewModel.joinedTripId {
                    successView(tripId: tripId)
                } else if let preview = viewModel.preview {
                    previewView(preview)
                } else if let error = viewModel.errorMessage {
                    errorView(error)
                }
            }
            .navigationTitle("Join Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                await viewModel.loadPreview(code: inviteCode)
                withAnimation(OuestTheme.Anim.smooth) {
                    contentAppeared = true
                }
            }
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: OuestTheme.Spacing.lg) {
            ProgressView()
            Text("Loading invite…")
                .font(OuestTheme.Typography.caption)
                .foregroundStyle(OuestTheme.Colors.textSecondary)
        }
    }

    // MARK: - Preview

    private func previewView(_ preview: InvitePreview) -> some View {
        VStack(spacing: OuestTheme.Spacing.xxl) {
            Spacer()

            // Trip card
            VStack(spacing: 0) {
                // Cover
                tripCover(preview)

                // Info
                VStack(spacing: OuestTheme.Spacing.md) {
                    Text(preview.tripTitle)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(OuestTheme.Colors.textPrimary)

                    HStack(spacing: OuestTheme.Spacing.sm) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(OuestTheme.Colors.brand)
                        Text(preview.tripDestination)
                            .font(OuestTheme.Typography.body)
                            .foregroundStyle(OuestTheme.Colors.textSecondary)
                    }

                    HStack(spacing: OuestTheme.Spacing.lg) {
                        Label("\(preview.memberCount) travelers", systemImage: "person.2.fill")
                        Label(preview.role.capitalized, systemImage: preview.role == "editor" ? "pencil" : "eye")
                    }
                    .font(OuestTheme.Typography.caption)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)

                    Text("Invited by \(preview.creatorName)")
                        .font(OuestTheme.Typography.caption)
                        .foregroundStyle(OuestTheme.Colors.textSecondary.opacity(0.7))
                }
                .padding(OuestTheme.Spacing.xl)
            }
            .background(OuestTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.xl))
            .shadow(OuestTheme.Shadow.lg)
            .padding(.horizontal, OuestTheme.Spacing.xxl)
            .fadeSlideIn(isVisible: contentAppeared, delay: 0.05)

            // Action button
            if preview.isAlreadyMember {
                VStack(spacing: OuestTheme.Spacing.md) {
                    HStack(spacing: OuestTheme.Spacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(OuestTheme.Colors.success)
                        Text("You're already a member")
                            .font(OuestTheme.Typography.body)
                            .foregroundStyle(OuestTheme.Colors.textSecondary)
                    }

                    Button {
                        onJoined?(preview.tripId)
                        dismiss()
                    } label: {
                        Text("Go to Trip")
                            .font(OuestTheme.Typography.sectionTitle)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, OuestTheme.Spacing.md)
                            .background(OuestTheme.Colors.brand)
                            .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
                    }
                    .padding(.horizontal, OuestTheme.Spacing.xxl)
                }
                .fadeSlideIn(isVisible: contentAppeared, delay: 0.15)
            } else {
                Button {
                    HapticFeedback.medium()
                    Task { await viewModel.joinTrip(code: inviteCode) }
                } label: {
                    HStack(spacing: OuestTheme.Spacing.sm) {
                        if viewModel.isJoining {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "person.badge.plus")
                        }
                        Text("Join Trip")
                    }
                    .font(OuestTheme.Typography.sectionTitle)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, OuestTheme.Spacing.md)
                    .background(OuestTheme.Colors.brand)
                    .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
                }
                .disabled(viewModel.isJoining)
                .padding(.horizontal, OuestTheme.Spacing.xxl)
                .fadeSlideIn(isVisible: contentAppeared, delay: 0.15)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(OuestTheme.Typography.caption)
                        .foregroundStyle(OuestTheme.Colors.error)
                        .padding(.horizontal, OuestTheme.Spacing.xxl)
                }
            }

            Spacer()
        }
    }

    private func tripCover(_ preview: InvitePreview) -> some View {
        Group {
            if let urlString = preview.tripCoverImageUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        gradientPlaceholder(preview.tripDestination)
                    }
                }
            } else {
                gradientPlaceholder(preview.tripDestination)
            }
        }
        .frame(height: 180)
        .clipped()
    }

    private func gradientPlaceholder(_ destination: String) -> some View {
        let hash = abs(destination.hashValue)
        let colors = OuestTheme.Colors.tripGradients[hash % OuestTheme.Colors.tripGradients.count]

        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay {
                Image(systemName: "airplane")
                    .font(.system(size: 32))
                    .foregroundStyle(.white.opacity(0.2))
            }
    }

    // MARK: - Success

    private func successView(tripId: UUID) -> some View {
        VStack(spacing: OuestTheme.Spacing.xxl) {
            Spacer()

            VStack(spacing: OuestTheme.Spacing.lg) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(OuestTheme.Colors.success)

                Text("You're in!")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("You've joined the trip successfully.")
                    .font(OuestTheme.Typography.body)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
            }

            Button {
                HapticFeedback.light()
                onJoined?(tripId)
                dismiss()
            } label: {
                Text("Go to Trip")
                    .font(OuestTheme.Typography.sectionTitle)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, OuestTheme.Spacing.md)
                    .background(OuestTheme.Colors.brand)
                    .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
            }
            .padding(.horizontal, OuestTheme.Spacing.xxl)

            Spacer()
        }
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: OuestTheme.Spacing.xxl) {
            Spacer()

            VStack(spacing: OuestTheme.Spacing.lg) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(OuestTheme.Colors.warning)

                Text("Couldn't Join")
                    .font(.title2)
                    .fontWeight(.bold)

                Text(message)
                    .font(OuestTheme.Typography.body)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, OuestTheme.Spacing.xxl)
            }

            Button {
                dismiss()
            } label: {
                Text("Close")
                    .font(OuestTheme.Typography.sectionTitle)
                    .foregroundStyle(OuestTheme.Colors.brand)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, OuestTheme.Spacing.md)
                    .background(OuestTheme.Colors.brandLight)
                    .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
            }
            .padding(.horizontal, OuestTheme.Spacing.xxl)

            Spacer()
        }
    }
}

#Preview {
    JoinTripView(inviteCode: "ABC12345")
}
