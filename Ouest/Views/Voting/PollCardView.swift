import SwiftUI

struct PollCardView: View {
    let poll: Poll
    let viewModel: PollsViewModel
    @State private var isVoting = false

    private var currentUserId: UUID? { viewModel.currentUserId }

    var body: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.md) {
            // Header
            headerSection

            // Description
            if let desc = poll.description, !desc.isEmpty {
                Text(desc)
                    .font(.subheadline)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
                    .lineLimit(3)
            }

            // Options
            ForEach(poll.sortedOptions) { option in
                optionRow(option)
            }

            // Footer
            footerSection
        }
        .padding(OuestTheme.Spacing.lg)
        .background(OuestTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.lg))
        .shadow(OuestTheme.Shadow.md)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top, spacing: OuestTheme.Spacing.sm) {
            VStack(alignment: .leading, spacing: OuestTheme.Spacing.xxs) {
                Text(poll.title)
                    .font(OuestTheme.Typography.cardTitle)
                    .foregroundStyle(OuestTheme.Colors.textPrimary)

                HStack(spacing: OuestTheme.Spacing.xs) {
                    if let profile = poll.profile {
                        Text(profile.fullName ?? "Unknown")
                            .font(OuestTheme.Typography.micro)
                            .foregroundStyle(OuestTheme.Colors.textSecondary)
                    }

                    if let date = poll.createdAt {
                        Text("·")
                            .font(OuestTheme.Typography.micro)
                            .foregroundStyle(OuestTheme.Colors.textSecondary)
                        Text(date.relativeText)
                            .font(OuestTheme.Typography.micro)
                            .foregroundStyle(OuestTheme.Colors.textSecondary)
                    }
                }
            }

            Spacer()

            // Status pill
            HStack(spacing: OuestTheme.Spacing.xxs) {
                Image(systemName: poll.status.icon)
                    .font(.system(size: 10))
                Text(poll.status.label)
                    .font(OuestTheme.Typography.micro)
            }
            .foregroundStyle(poll.status.color)
            .padding(.horizontal, OuestTheme.Spacing.sm)
            .padding(.vertical, OuestTheme.Spacing.xxs)
            .background(poll.status.color.opacity(0.12))
            .clipShape(Capsule())

            // Allow-multiple indicator
            if poll.allowMultiple {
                Image(systemName: "checklist")
                    .font(.caption2)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
            }
        }
    }

    // MARK: - Option Row

    private func optionRow(_ option: PollOption) -> some View {
        Button {
            guard !isVoting else { return }
            isVoting = true
            HapticFeedback.light()
            Task {
                await viewModel.toggleVote(poll: poll, option: option)
                isVoting = false
            }
        } label: {
            VStack(alignment: .leading, spacing: OuestTheme.Spacing.xs) {
                HStack(spacing: OuestTheme.Spacing.sm) {
                    // Vote indicator
                    let voted = currentUserId.map { option.hasVote(by: $0) } ?? false
                    Image(systemName: voted ? "checkmark.circle.fill" : "circle")
                        .font(.body)
                        .foregroundStyle(voted ? OuestTheme.Colors.brand : OuestTheme.Colors.textSecondary.opacity(0.5))

                    // Option title
                    Text(option.title)
                        .font(.subheadline)
                        .fontWeight(currentUserId.map { option.hasVote(by: $0) } ?? false ? .semibold : .regular)
                        .foregroundStyle(OuestTheme.Colors.textPrimary)

                    Spacer()

                    // Vote count
                    if option.voteCount > 0 {
                        Text("\(option.voteCount)")
                            .font(OuestTheme.Typography.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(OuestTheme.Colors.textSecondary)
                    }
                }

                // Percentage bar
                GeometryReader { geo in
                    let voted = currentUserId.map { option.hasVote(by: $0) } ?? false
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(OuestTheme.Colors.surfaceSecondary)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(voted ? OuestTheme.Colors.brand : OuestTheme.Colors.brand.opacity(0.35))
                            .frame(width: max(0, geo.size.width * option.votePercentage(totalVotes: poll.totalVotes)))
                            .animation(.spring(duration: 0.35, bounce: 0.1), value: option.voteCount)
                    }
                }
                .frame(height: 6)

                // Voter avatars
                if let votes = option.votes, !votes.isEmpty {
                    HStack(spacing: -4) {
                        ForEach(Array(votes.prefix(5))) { vote in
                            AvatarView(url: vote.profile?.avatarUrl, size: 20)
                                .overlay(
                                    Circle()
                                        .stroke(OuestTheme.Colors.surface, lineWidth: 1.5)
                                )
                        }
                        if votes.count > 5 {
                            Text("+\(votes.count - 5)")
                                .font(OuestTheme.Typography.micro)
                                .foregroundStyle(OuestTheme.Colors.textSecondary)
                                .padding(.leading, OuestTheme.Spacing.xs)
                        }
                    }
                }
            }
            .padding(OuestTheme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: OuestTheme.Radius.sm)
                    .fill(currentUserId.map { option.hasVote(by: $0) } ?? false
                          ? OuestTheme.Colors.brand.opacity(0.06)
                          : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .disabled(!poll.isOpen || isVoting)
        .opacity(poll.isOpen ? 1.0 : 0.7)
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            // Total votes
            HStack(spacing: OuestTheme.Spacing.xxs) {
                Image(systemName: "person.2")
                    .font(.caption2)
                Text("\(poll.totalVotes) vote\(poll.totalVotes == 1 ? "" : "s")")
                    .font(OuestTheme.Typography.micro)
            }
            .foregroundStyle(OuestTheme.Colors.textSecondary)

            Spacer()

            // Actions menu (only for creator / trip owner)
            if viewModel.canClose(poll) || viewModel.canDelete(poll) {
                Menu {
                    if poll.isOpen && viewModel.canClose(poll) {
                        Button {
                            HapticFeedback.medium()
                            Task { await viewModel.closePoll(poll) }
                        } label: {
                            Label("Close Poll", systemImage: "checkmark.seal")
                        }
                    }

                    if viewModel.canDelete(poll) {
                        Button(role: .destructive) {
                            HapticFeedback.medium()
                            Task { await viewModel.deletePoll(poll) }
                        } label: {
                            Label("Delete Poll", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.caption)
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                        .padding(OuestTheme.Spacing.xs)
                }
            }
        }
    }
}
