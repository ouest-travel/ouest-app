import SwiftUI

struct TripMembersView: View {
    @Bindable var viewModel: TripDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showInvite = false

    var body: some View {
        NavigationStack {
            List {
                // Existing Members
                Section("Members (\(viewModel.members.count))") {
                    ForEach(viewModel.members) { member in
                        memberRow(member)
                    }
                }

                // Invite Section
                if viewModel.canEdit {
                    Section {
                        Button {
                            showInvite = true
                        } label: {
                            Label("Invite Someone", systemImage: "person.badge.plus")
                        }
                    }
                }
            }
            .navigationTitle("Travelers")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: ProfileDestination.self) { dest in
                UserProfileView(userId: dest.userId)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showInvite) {
                InviteMemberSheet(viewModel: viewModel)
            }
        }
    }

    private func memberRow(_ member: TripMember) -> some View {
        NavigationLink(value: ProfileDestination(userId: member.userId)) {
            HStack(spacing: 12) {
                AvatarView(url: member.profile?.avatarUrl, size: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(member.profile?.fullName ?? "Unknown")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if let handle = member.profile?.handle {
                        Text("@\(handle)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Role badge
                HStack(spacing: 4) {
                    Image(systemName: member.role.icon)
                        .font(.caption2)
                    Text(member.role.label)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundStyle(member.role == .owner ? .orange : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(member.role == .owner ? .orange.opacity(0.12) : Color(.systemGray5))
                .clipShape(Capsule())
            }
        }
        .swipeActions(edge: .trailing) {
            if viewModel.myRole == .owner && member.role != .owner {
                Button(role: .destructive) {
                    Task { _ = await viewModel.removeMember(member) }
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            }
        }
        .contextMenu {
            if viewModel.myRole == .owner && member.role != .owner {
                Menu("Change Role") {
                    Button {
                        Task { await viewModel.updateRole(member: member, to: .editor) }
                    } label: {
                        Label("Editor", systemImage: "pencil")
                    }
                    Button {
                        Task { await viewModel.updateRole(member: member, to: .viewer) }
                    } label: {
                        Label("Viewer", systemImage: "eye")
                    }
                }
            }
        }
    }
}

// MARK: - Invite Sheet

struct InviteMemberSheet: View {
    @Bindable var viewModel: TripDetailViewModel
    @Environment(\.dismiss) private var dismiss
    /// Track per-row state so each search result reflects its own pending /
    /// sent status without affecting siblings.
    @State private var sendingIds: Set<UUID> = []
    @State private var invitedIds: Set<UUID> = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search by name, handle, or email", text: $viewModel.searchQuery)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit {
                            Task { await viewModel.searchUsers() }
                        }
                        .onChange(of: viewModel.searchQuery) {
                            Task { await viewModel.searchUsers() }
                        }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
                .padding(.top, 12)

                if viewModel.isSearching {
                    ProgressView()
                        .padding(.top, 24)
                    Spacer()
                } else if viewModel.searchResults.isEmpty && viewModel.searchQuery.count >= 2 {
                    VStack(spacing: 8) {
                        Image(systemName: "person.slash")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("No users found")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 40)
                    Spacer()
                } else {
                    List(viewModel.searchResults) { profile in
                        searchResultRow(profile)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Invite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func searchResultRow(_ profile: Profile) -> some View {
        let isSending = sendingIds.contains(profile.id)
        let isInvited = invitedIds.contains(profile.id)

        return Button {
            // Whole-row tap → invite. Guards against double-tap and re-tap
            // after success, which previously did nothing visible.
            guard !isSending, !isInvited else { return }
            HapticFeedback.light()
            sendingIds.insert(profile.id)
            Task {
                let ok = await viewModel.inviteMember(profile: profile)
                sendingIds.remove(profile.id)
                if ok {
                    invitedIds.insert(profile.id)
                    HapticFeedback.success()
                }
            }
        } label: {
            HStack(spacing: 12) {
                AvatarView(url: profile.avatarUrl, size: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.fullName ?? profile.email)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    if let handle = profile.handle {
                        Text("@\(handle)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Status pill — visual mirror of the row's tap action.
                actionPill(isSending: isSending, isInvited: isInvited)
            }
            .contentShape(Rectangle()) // Ensures taps anywhere on the row register.
        }
        .buttonStyle(.plain)
        .disabled(isSending || isInvited)
    }

    @ViewBuilder
    private func actionPill(isSending: Bool, isInvited: Bool) -> some View {
        if isSending {
            ProgressView()
                .controlSize(.small)
                .tint(OuestTheme.Colors.brand)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
        } else if isInvited {
            Label("Invited", systemImage: "checkmark")
                .labelStyle(.titleAndIcon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(OuestTheme.Colors.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color(.systemGray5))
                .clipShape(Capsule())
        } else {
            // Explicit colors so the styling isn't fighting the outer Button's
            // label-tint inheritance (which was wiping the text in light mode).
            Text("Invite")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(OuestTheme.Colors.brand)
                .clipShape(Capsule())
        }
    }
}

#Preview {
    TripMembersView(viewModel: TripDetailViewModel())
}
