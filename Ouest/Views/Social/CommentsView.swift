import SwiftUI

struct CommentsView: View {
    let tripId: UUID
    /// How this view is being presented. `.sheet` (default) gives it its own
    /// NavigationStack + Done button — appropriate when shown via `.sheet(...)`.
    /// `.push` is used when the view is already pushed onto a parent
    /// NavigationStack (e.g. from a notification tap) — wrapping it in another
    /// NavigationStack would cause nested-stack issues where the destination
    /// silently fails to render.
    var presentation: Presentation = .sheet

    enum Presentation { case sheet, push }

    @Environment(\.dismiss) private var dismiss
    @State private var comments: [TripComment] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var commentText = ""
    @State private var isSending = false
    @State private var contentAppeared = false
    @State private var currentUserId: UUID?

    // MARK: - Mention State

    @State private var mentionResults: [Profile] = []
    @State private var activeMentionQuery = ""

    var body: some View {
        Group {
            if presentation == .sheet {
                NavigationStack { content }
            } else {
                content
            }
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
                // Comments list
                Group {
                    if isLoading {
                        loadingView
                    } else if let error = errorMessage, comments.isEmpty {
                        ErrorView(message: error) {
                            Task { await loadComments() }
                        }
                    } else if comments.isEmpty {
                        emptyState
                    } else {
                        commentsList
                    }
                }

                // Error toast (visible even when comments exist)
                if let error = errorMessage, !comments.isEmpty {
                    Text(error)
                        .font(OuestTheme.Typography.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, OuestTheme.Spacing.lg)
                        .padding(.vertical, OuestTheme.Spacing.sm)
                        .background(OuestTheme.Colors.error.opacity(0.9))
                        .clipShape(Capsule())
                        .padding(.vertical, OuestTheme.Spacing.xs)
                        .transition(.opacity)
                }

                Divider()

                // Mention suggestions
                if !mentionResults.isEmpty {
                    mentionSuggestions
                }

                // Input bar
                inputBar
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: ProfileDestination.self) { dest in
                UserProfileView(userId: dest.userId)
            }
            .toolbar {
                // Done button only makes sense for sheet presentation. Push
                // presentation gets the parent's back button automatically.
                if presentation == .sheet {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            }
            .task {
                do {
                    currentUserId = try await SupabaseManager.client.auth.session.user.id
                } catch {}
                await loadComments()
                withAnimation(OuestTheme.Anim.smooth) {
                    contentAppeared = true
                }
            }
            .animation(OuestTheme.Anim.quick, value: errorMessage)
    }

    // MARK: - Comments List

    private var commentsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: OuestTheme.Spacing.lg) {
                ForEach(Array(comments.enumerated()), id: \.element.id) { index, comment in
                    commentRow(comment)
                        .fadeSlideIn(isVisible: contentAppeared, delay: Double(index) * 0.04)
                        .contextMenu {
                            if isOwnComment(comment) {
                                Button(role: .destructive) {
                                    Task { await deleteComment(comment) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                }
            }
            .padding(.horizontal, OuestTheme.Spacing.lg)
            .padding(.vertical, OuestTheme.Spacing.md)
        }
    }

    private func commentRow(_ comment: TripComment) -> some View {
        HStack(alignment: .top, spacing: OuestTheme.Spacing.sm) {
            // Tappable avatar → user profile
            if let profileId = comment.profile?.id {
                NavigationLink(value: ProfileDestination(userId: profileId)) {
                    AvatarView(url: comment.profile?.avatarUrl, size: 32)
                }
                .buttonStyle(.plain)
            } else {
                AvatarView(url: comment.profile?.avatarUrl, size: 32)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: OuestTheme.Spacing.sm) {
                    if let profileId = comment.profile?.id {
                        NavigationLink(value: ProfileDestination(userId: profileId)) {
                            Text(comment.profile?.fullName ?? "Unknown")
                                .font(OuestTheme.Typography.cardTitle)
                                .foregroundStyle(OuestTheme.Colors.textPrimary)
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text(comment.profile?.fullName ?? "Unknown")
                            .font(OuestTheme.Typography.cardTitle)
                            .lineLimit(1)
                    }

                    if let handle = comment.profile?.handle {
                        Text("@\(handle)")
                            .font(OuestTheme.Typography.micro)
                            .foregroundStyle(OuestTheme.Colors.textSecondary)
                    }

                    if let created = comment.createdAt {
                        Text(created.relativeText)
                            .font(OuestTheme.Typography.micro)
                            .foregroundStyle(OuestTheme.Colors.textSecondary)
                    }
                }

                renderCommentText(comment.content)
            }

            Spacer(minLength: 0)
        }
    }

    /// Renders comment text with @mentions highlighted
    private func renderCommentText(_ text: String) -> some View {
        let parts = parseMentions(text)
        return parts.reduce(Text("")) { result, part in
            switch part {
            case .plain(let str):
                return result + Text(str)
            case .mention(let handle):
                return result + Text("@\(handle)")
                    .foregroundColor(OuestTheme.Colors.brand)
                    .fontWeight(.medium)
            }
        }
        .font(.subheadline)
        .foregroundStyle(OuestTheme.Colors.textPrimary)
    }

    // MARK: - Mention Suggestions

    private var mentionSuggestions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: OuestTheme.Spacing.sm) {
                ForEach(mentionResults) { profile in
                    Button {
                        insertMention(profile)
                    } label: {
                        HStack(spacing: OuestTheme.Spacing.xs) {
                            AvatarView(url: profile.avatarUrl, size: 24)
                            VStack(alignment: .leading, spacing: 0) {
                                if let name = profile.fullName {
                                    Text(name)
                                        .font(OuestTheme.Typography.caption)
                                        .foregroundStyle(OuestTheme.Colors.textPrimary)
                                }
                                if let handle = profile.handle {
                                    Text("@\(handle)")
                                        .font(OuestTheme.Typography.micro)
                                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                                }
                            }
                        }
                        .padding(.horizontal, OuestTheme.Spacing.sm)
                        .padding(.vertical, OuestTheme.Spacing.xs)
                        .background(OuestTheme.Colors.surfaceSecondary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, OuestTheme.Spacing.lg)
            .padding(.vertical, OuestTheme.Spacing.xs)
        }
        .background(OuestTheme.Colors.surface)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: OuestTheme.Spacing.sm) {
            TextField("Add a comment...", text: $commentText, axis: .vertical)
                .font(.body)
                .lineLimit(1...4)
                .padding(.horizontal, OuestTheme.Spacing.md)
                .padding(.vertical, OuestTheme.Spacing.sm)
                .background(OuestTheme.Colors.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.lg))
                .onChange(of: commentText) { _, newValue in
                    handleMentionInput(newValue)
                }

            Button {
                Task { await sendComment() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(
                        commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending
                            ? OuestTheme.Colors.textSecondary
                            : OuestTheme.Colors.brand
                    )
            }
            .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            .accessibilityLabel("Send comment")
        }
        .padding(.horizontal, OuestTheme.Spacing.lg)
        .padding(.vertical, OuestTheme.Spacing.sm)
        .background(OuestTheme.Colors.surface)
    }

    // MARK: - Empty & Loading

    private var emptyState: some View {
        VStack(spacing: OuestTheme.Spacing.md) {
            Spacer()
            Image(systemName: "bubble.right")
                .font(.system(size: 36))
                .foregroundStyle(OuestTheme.Colors.textSecondary)
            Text("No comments yet")
                .font(OuestTheme.Typography.cardTitle)
            Text("Be the first to comment!")
                .font(.subheadline)
                .foregroundStyle(OuestTheme.Colors.textSecondary)
            Spacer()
        }
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
            Spacer()
        }
    }

    // MARK: - Actions

    private func loadComments() async {
        isLoading = true
        errorMessage = nil
        do {
            comments = try await CommunityService.fetchComments(tripId: tripId)
        } catch {
            errorMessage = error.localizedDescription
            #if DEBUG
            print("[Comments] loadComments failed: \(error)")
            #endif
        }
        isLoading = false
    }

    private func sendComment() async {
        let content = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        isSending = true
        errorMessage = nil
        do {
            let userId = try await SupabaseManager.client.auth.session.user.id
            let comment = try await CommunityService.addComment(tripId: tripId, userId: userId, content: content)
            comments.append(comment)
            commentText = ""
            mentionResults = []
            HapticFeedback.success()
        } catch {
            errorMessage = error.localizedDescription
            HapticFeedback.error()
            #if DEBUG
            print("[Comments] sendComment failed: \(error)")
            #endif
        }
        isSending = false
    }

    private func deleteComment(_ comment: TripComment) async {
        do {
            try await CommunityService.deleteComment(id: comment.id)
            comments.removeAll { $0.id == comment.id }
            HapticFeedback.success()
        } catch {
            errorMessage = "Couldn't delete comment"
            #if DEBUG
            print("[Comments] deleteComment failed: \(error)")
            #endif
        }
    }

    private func isOwnComment(_ comment: TripComment) -> Bool {
        guard let userId = currentUserId else { return false }
        return comment.userId == userId
    }

    // MARK: - Mention Parsing

    private enum CommentPart {
        case plain(String)
        case mention(String)
    }

    private func parseMentions(_ text: String) -> [CommentPart] {
        var parts: [CommentPart] = []
        let scanner = Scanner(string: text)
        scanner.charactersToBeSkipped = nil

        while !scanner.isAtEnd {
            if let plain = scanner.scanUpToString("@") {
                if !plain.isEmpty {
                    parts.append(.plain(plain))
                }
            }

            if scanner.scanString("@") != nil {
                let handleChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_."))
                if let handle = scanner.scanCharacters(from: handleChars), !handle.isEmpty {
                    parts.append(.mention(handle))
                } else {
                    parts.append(.plain("@"))
                }
            }
        }

        return parts
    }

    // MARK: - Mention Autocomplete

    private func handleMentionInput(_ text: String) {
        guard let atIndex = text.lastIndex(of: "@") else {
            mentionResults = []
            activeMentionQuery = ""
            return
        }

        let afterAt = String(text[text.index(after: atIndex)...])

        // If there's a space after the handle text, dismiss suggestions
        if afterAt.contains(" ") {
            mentionResults = []
            activeMentionQuery = ""
            return
        }

        let query = afterAt.lowercased()
        guard query.count >= 1 else {
            mentionResults = []
            activeMentionQuery = ""
            return
        }

        activeMentionQuery = query
        Task { await searchProfiles(query: query) }
    }

    private func searchProfiles(query: String) async {
        do {
            let results: [Profile] = try await SupabaseManager.client
                .from("profiles")
                .select()
                .or("handle.ilike.%\(query)%,full_name.ilike.%\(query)%")
                .limit(5)
                .execute()
                .value

            if activeMentionQuery == query.lowercased() {
                mentionResults = results.filter { $0.handle != nil }
            }
        } catch {
            #if DEBUG
            print("[Comments] mention search failed: \(error)")
            #endif
        }
    }

    private func insertMention(_ profile: Profile) {
        guard let handle = profile.handle else { return }

        if let atIndex = commentText.lastIndex(of: "@") {
            commentText = String(commentText[..<atIndex]) + "@\(handle) "
        }

        mentionResults = []
        activeMentionQuery = ""
        HapticFeedback.selection()
    }
}

#Preview {
    CommentsView(tripId: UUID())
}
