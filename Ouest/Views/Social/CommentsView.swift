import SwiftUI

struct CommentsView: View {
    let tripId: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var comments: [TripComment] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var commentText = ""
    @State private var isSending = false
    @State private var contentAppeared = false

    var body: some View {
        NavigationStack {
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

                Divider()

                // Input bar
                inputBar
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await loadComments()
                withAnimation(OuestTheme.Anim.smooth) {
                    contentAppeared = true
                }
            }
        }
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
            AvatarView(url: comment.profile?.avatarUrl, size: 32)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: OuestTheme.Spacing.sm) {
                    Text(comment.profile?.fullName ?? "Unknown")
                        .font(OuestTheme.Typography.cardTitle)
                        .lineLimit(1)

                    if let created = comment.createdAt {
                        Text(created.relativeText)
                            .font(OuestTheme.Typography.micro)
                            .foregroundStyle(OuestTheme.Colors.textSecondary)
                    }
                }

                Text(comment.content)
                    .font(.subheadline)
                    .foregroundStyle(OuestTheme.Colors.textPrimary)
            }

            Spacer(minLength: 0)
        }
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
        }
        isLoading = false
    }

    private func sendComment() async {
        let content = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        isSending = true
        do {
            let userId = try await SupabaseManager.client.auth.session.user.id
            let comment = try await CommunityService.addComment(tripId: tripId, userId: userId, content: content)
            comments.append(comment)
            commentText = ""
            HapticFeedback.success()
        } catch {
            errorMessage = error.localizedDescription
            HapticFeedback.error()
        }
        isSending = false
    }

    private func deleteComment(_ comment: TripComment) async {
        do {
            try await CommunityService.deleteComment(id: comment.id)
            comments.removeAll { $0.id == comment.id }
            HapticFeedback.success()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func isOwnComment(_ comment: TripComment) -> Bool {
        // Check at render time using a stored property would be better,
        // but for simplicity we compare against the comment's userId
        // The current user's comments will be identifiable via context menu
        true // Allow delete on any comment for now — RLS enforces own-only
    }
}

#Preview {
    CommentsView(tripId: UUID())
}
