import SwiftUI

struct ShareTripSheet: View {
    let trip: Trip
    @State private var viewModel = TripDetailViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRole: MemberRole = .viewer
    @State private var copied = false
    @State private var contentAppeared = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: OuestTheme.Spacing.xxl) {
                    // QR Code + Invite Link
                    inviteSection
                        .fadeSlideIn(isVisible: contentAppeared, delay: 0.05)

                    // Role Picker
                    roleSection
                        .fadeSlideIn(isVisible: contentAppeared, delay: 0.1)

                    // Share Actions
                    shareActions
                        .fadeSlideIn(isVisible: contentAppeared, delay: 0.15)

                    // Active Invites
                    if !viewModel.invites.isEmpty {
                        activeInvitesSection
                            .fadeSlideIn(isVisible: contentAppeared, delay: 0.2)
                    }
                }
                .padding(.horizontal, OuestTheme.Spacing.xl)
                .padding(.vertical, OuestTheme.Spacing.lg)
            }
            .navigationTitle("Share Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await viewModel.prepareForSharing(trip: trip)
                await viewModel.fetchInvites()
                // Auto-generate an invite if none exist
                if viewModel.activeInvite == nil {
                    await viewModel.generateInvite(role: selectedRole)
                } else if let active = viewModel.activeInvite {
                    selectedRole = active.role
                }
                withAnimation(OuestTheme.Anim.smooth) {
                    contentAppeared = true
                }
            }
        }
    }

    // MARK: - Invite Section (QR + Link)

    private var inviteSection: some View {
        VStack(spacing: OuestTheme.Spacing.lg) {
            if let invite = viewModel.activeInvite {
                // QR Code
                QRCodeView(content: invite.inviteURL.absoluteString)

                // Invite link with copy
                inviteLinkRow(invite)
            } else if viewModel.isGeneratingInvite {
                ProgressView()
                    .frame(height: 200)
            } else {
                // No active invite — prompt to generate
                VStack(spacing: OuestTheme.Spacing.md) {
                    Image(systemName: "link.badge.plus")
                        .font(.largeTitle)
                        .foregroundStyle(OuestTheme.Colors.textSecondary)

                    Text("No active invite link")
                        .font(OuestTheme.Typography.body)
                        .foregroundStyle(OuestTheme.Colors.textSecondary)

                    Button {
                        HapticFeedback.light()
                        Task { await viewModel.generateInvite(role: selectedRole) }
                    } label: {
                        Text("Generate Link")
                            .font(OuestTheme.Typography.sectionTitle)
                            .foregroundStyle(.white)
                            .padding(.horizontal, OuestTheme.Spacing.xxl)
                            .padding(.vertical, OuestTheme.Spacing.md)
                            .background(OuestTheme.Colors.brand)
                            .clipShape(Capsule())
                    }
                }
                .frame(height: 200)
            }

            if let error = viewModel.inviteError {
                Text(error)
                    .font(OuestTheme.Typography.caption)
                    .foregroundStyle(OuestTheme.Colors.error)
            }
        }
    }

    private func inviteLinkRow(_ invite: TripInvite) -> some View {
        Button {
            UIPasteboard.general.string = invite.inviteURL.absoluteString
            HapticFeedback.success()
            withAnimation(OuestTheme.Anim.quick) { copied = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation(OuestTheme.Anim.quick) { copied = false }
            }
        } label: {
            HStack(spacing: OuestTheme.Spacing.md) {
                Image(systemName: "link")
                    .font(.subheadline)
                    .foregroundStyle(OuestTheme.Colors.brand)

                Text(invite.inviteURL.absoluteString)
                    .font(OuestTheme.Typography.caption)
                    .foregroundStyle(OuestTheme.Colors.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                    .font(.subheadline)
                    .foregroundStyle(copied ? OuestTheme.Colors.success : OuestTheme.Colors.brand)
            }
            .padding(OuestTheme.Spacing.md)
            .background(OuestTheme.Colors.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Role Picker

    private var roleSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.sm) {
            Text("Invite as")
                .font(OuestTheme.Typography.sectionTitle)

            Picker("Role", selection: $selectedRole) {
                Text("Viewer").tag(MemberRole.viewer)
                Text("Editor").tag(MemberRole.editor)
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedRole) { _, newRole in
                // Check if activeInvite matches, otherwise generate a new one
                if viewModel.activeInvite?.role != newRole {
                    // Try to find an existing valid invite with this role
                    if let existing = viewModel.invites.first(where: { $0.isValid && $0.role == newRole }) {
                        viewModel.activeInvite = existing
                    } else {
                        Task { await viewModel.generateInvite(role: newRole) }
                    }
                }
            }
        }
    }

    // MARK: - Share Actions

    private var shareActions: some View {
        VStack(spacing: OuestTheme.Spacing.md) {
            if let invite = viewModel.activeInvite {
                ShareLink(
                    item: invite.shareText,
                    subject: Text(trip.title),
                    message: Text("Join my trip on Ouest!")
                ) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share to…")
                    }
                    .font(OuestTheme.Typography.sectionTitle)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, OuestTheme.Spacing.md)
                    .background(OuestTheme.Colors.brand)
                    .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
                }
            }
        }
    }

    // MARK: - Active Invites List

    private var activeInvitesSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.md) {
            Text("Active Invites")
                .font(OuestTheme.Typography.sectionTitle)

            ForEach(viewModel.invites.filter { $0.isActive }) { invite in
                HStack(spacing: OuestTheme.Spacing.md) {
                    VStack(alignment: .leading, spacing: OuestTheme.Spacing.xxs) {
                        Text(invite.code)
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.medium)
                            .foregroundStyle(OuestTheme.Colors.textPrimary)

                        HStack(spacing: OuestTheme.Spacing.sm) {
                            // Role badge
                            Text(invite.role.label)
                                .font(OuestTheme.Typography.micro)
                                .foregroundStyle(OuestTheme.Colors.textSecondary)

                            if invite.maxUses > 0 {
                                Text("· \(invite.useCount)/\(invite.maxUses) uses")
                                    .font(OuestTheme.Typography.micro)
                                    .foregroundStyle(OuestTheme.Colors.textSecondary)
                            } else if invite.useCount > 0 {
                                Text("· \(invite.useCount) joined")
                                    .font(OuestTheme.Typography.micro)
                                    .foregroundStyle(OuestTheme.Colors.textSecondary)
                            }
                        }
                    }

                    Spacer()

                    // Revoke button
                    Button {
                        HapticFeedback.light()
                        Task { await viewModel.revokeInvite(invite) }
                    } label: {
                        Text("Revoke")
                            .font(OuestTheme.Typography.micro)
                            .fontWeight(.semibold)
                            .foregroundStyle(OuestTheme.Colors.error)
                            .padding(.horizontal, OuestTheme.Spacing.md)
                            .padding(.vertical, OuestTheme.Spacing.xs)
                            .background(OuestTheme.Colors.error.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
                .padding(OuestTheme.Spacing.md)
                .background(OuestTheme.Colors.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.sm))
            }
        }
    }
}

// MARK: - QR Code View

struct QRCodeView: View {
    let content: String
    var size: CGFloat = 200

    var body: some View {
        Group {
            if let image = QRCodeGenerator.generate(from: content, size: size) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            } else {
                Image(systemName: "qrcode")
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
                    .frame(width: size, height: size)
            }
        }
        .padding(OuestTheme.Spacing.lg)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.lg))
        .shadow(OuestTheme.Shadow.md)
    }
}

#Preview {
    let json = """
    {"id":"11111111-1111-1111-1111-111111111111","created_by":"22222222-2222-2222-2222-222222222222","title":"Paris Trip","destination":"Paris, France","status":"planning","is_public":false}
    """.data(using: .utf8)!
    let trip = try! JSONDecoder().decode(Trip.self, from: json)
    ShareTripSheet(trip: trip)
}
