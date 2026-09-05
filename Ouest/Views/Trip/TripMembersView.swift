import SwiftUI

struct TripMembersView: View {
    @Bindable var viewModel: TripDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showInvite = false
    /// Member queued for destructive confirmation. Binding the alert to this
    /// keeps the confirm flow tied to a specific row.
    @State private var memberToRemove: TripMember?

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
            // Destructive confirmation as a sheet-style dialog instead of an
            // .alert. Stacking two .alert modifiers on the same view causes
            // them to fight over presentation context — the remove prompt
            // was getting swallowed by the error alert binding.
            .confirmationDialog(
                memberToRemove.flatMap { $0.profile?.fullName }.map { "Remove \($0)?" } ?? "Remove member?",
                isPresented: removeAlertBinding,
                titleVisibility: .visible,
                presenting: memberToRemove
            ) { member in
                Button("Remove from trip", role: .destructive) {
                    let m = member
                    Task {
                        _ = await viewModel.removeMember(m)
                        memberToRemove = nil
                    }
                }
                Button("Cancel", role: .cancel) { memberToRemove = nil }
            } message: { member in
                Text("\(member.profile?.fullName ?? "This person") will lose access to the trip. They can be re-invited later.")
            }
            .alert(
                "Couldn't update member",
                isPresented: errorAlertBinding,
                presenting: viewModel.errorMessage
            ) { _ in
                Button("OK", role: .cancel) { viewModel.errorMessage = nil }
            } message: { msg in
                Text(msg)
            }
        }
    }

    private var removeAlertBinding: Binding<Bool> {
        Binding(
            get: { memberToRemove != nil },
            set: { if !$0 { memberToRemove = nil } }
        )
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private func memberRow(_ member: TripMember) -> some View {
        // The owner can manage non-owner rows (change role / remove).
        let canManage = viewModel.myRole == .owner && member.role != .owner

        return HStack(spacing: 12) {
            // Tappable summary — opens the user's profile.
            NavigationLink(value: ProfileDestination(userId: member.userId)) {
                HStack(spacing: 12) {
                    AvatarView(url: member.profile?.avatarUrl, size: 44)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(member.profile?.fullName ?? "Unknown")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                        if let handle = member.profile?.handle {
                            Text("@\(handle)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
                }
            }
            .buttonStyle(.plain)

            // Role badge (always visible)
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

            // Manage menu — only when current user is the owner AND the row
            // isn't the owner themselves. Previously this was hidden behind
            // a swipe-left gesture (invisible UX); now it's a clear ellipsis
            // affordance matching the activity-card pattern.
            if canManage {
                Menu {
                    Section("Change Role") {
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

                    Button(role: .destructive) {
                        memberToRemove = member
                    } label: {
                        Label("Remove from trip", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
            }
        }
        // Backup affordances (kept for power users).
        .swipeActions(edge: .trailing) {
            if canManage {
                Button(role: .destructive) {
                    memberToRemove = member
                } label: {
                    Label("Remove", systemImage: "trash")
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
    /// Brief toast shown after a successful invite (the row itself is removed
    /// from searchResults by the viewmodel, so without this the user only
    /// sees the row disappear with no positive confirmation).
    @State private var lastInvitedName: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Toast lives inside the VStack so it appears below the nav
                // title bar (rather than behind it, which is what happens when
                // .overlay(.top) is attached to the NavigationStack itself).
                if let name = lastInvitedName {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Invited \(name)")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .ouestElevation(.sm)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

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
            .animation(OuestTheme.Anim.smooth, value: lastInvitedName)
            .alert(
                "Couldn't send invite",
                isPresented: errorAlertBinding,
                presenting: viewModel.errorMessage
            ) { _ in
                Button("OK", role: .cancel) { viewModel.errorMessage = nil }
            } message: { msg in
                Text(msg)
            }
        }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private func searchResultRow(_ profile: Profile) -> some View {
        let isSending = sendingIds.contains(profile.id)
        let isInvited = invitedIds.contains(profile.id)

        // We use .onTapGesture on the HStack rather than wrapping the row in
        // a Button. Inside a List, Button-wrapped rows can swallow taps
        // (especially when the label has its own interactive-looking pill),
        // which was the root of "tapping the row does nothing".
        return HStack(spacing: 12) {
            AvatarView(url: profile.avatarUrl, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.fullName ?? profile.email)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if let handle = profile.handle {
                    Text("@\(handle)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Visual mirror of the row's tap action.
            actionPill(isSending: isSending, isInvited: isInvited)
        }
        .contentShape(Rectangle()) // Whole row registers taps, not just text.
        .onTapGesture {
            guard !isSending, !isInvited else { return }
            HapticFeedback.light()
            sendingIds.insert(profile.id)
            Task {
                let displayName = profile.fullName ?? profile.handle.map { "@\($0)" } ?? profile.email
                let ok = await viewModel.inviteMember(profile: profile)
                sendingIds.remove(profile.id)
                if ok {
                    invitedIds.insert(profile.id)
                    HapticFeedback.success()
                    // Toast confirmation — the row itself gets removed from
                    // searchResults by the viewmodel, so this is the user's
                    // only positive feedback that the invite landed.
                    lastInvitedName = displayName
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(2.5))
                        if lastInvitedName == displayName {
                            lastInvitedName = nil
                        }
                    }
                } else {
                    HapticFeedback.error()
                    // viewModel.errorMessage is set inside inviteMember on
                    // failure; the alert binding above will catch it.
                }
            }
        }
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
