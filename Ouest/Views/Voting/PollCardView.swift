import SwiftUI

/// One poll in the list. An open poll shows its options as large rows that
/// fill with their share of the vote. A decided poll collapses to the group's
/// pick, and a tap opens the full result.
struct PollCardView: View {
    let poll: Poll
    let viewModel: PollsViewModel
    var canEdit: Bool = true
    @State private var isVoting = false
    @State private var showsAllVotes = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .title3) private var wellSize: CGFloat = 44

    private var currentUserId: UUID? { viewModel.currentUserId }

    var body: some View {
        OuestCard {
            if let closesAt = poll.closesAt, poll.isOpen {
                // Redraw each minute, on the deadline's own minute grid, so the
                // countdown stays current and the card closes the moment voting
                // does. A week back is past any deadline a poll can be given.
                TimelineView(.periodic(from: closesAt.addingTimeInterval(-7 * 86_400), by: 60)) { _ in
                    content
                }
            } else {
                content
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if poll.isOpen {
            openContent
        } else {
            decidedContent
        }
    }

    // MARK: - Voting now

    private var openContent: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.md) {
            // At the largest text sizes the pill would squeeze the question
            // into a column a few letters wide, so it sits above it instead.
            let stacked = dynamicTypeSize.isAccessibilitySize
            let header = stacked
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: OuestTheme.Spacing.sm))
                : AnyLayout(HStackLayout(alignment: .top, spacing: OuestTheme.Spacing.sm))

            header {
                if stacked {
                    statusPill
                }

                VStack(alignment: .leading, spacing: OuestTheme.Spacing.xxs) {
                    Text(poll.title)
                        .font(OuestTheme.Typography.cardTitle)
                        .foregroundStyle(OuestTheme.Colors.textPrimary)

                    if !byline.isEmpty {
                        Text(byline)
                            .font(OuestTheme.Typography.caption)
                            .foregroundStyle(OuestTheme.Colors.textTertiary)
                    }
                }

                if !stacked {
                    Spacer(minLength: OuestTheme.Spacing.sm)
                    statusPill
                }
            }

            if let description = poll.description, !description.isEmpty {
                Text(description)
                    .font(OuestTheme.Typography.body)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
                    .lineLimit(3)
            }

            optionRows(interactive: true)

            HStack(spacing: OuestTheme.Spacing.sm) {
                turnout
                Spacer(minLength: OuestTheme.Spacing.sm)
                actionsMenu
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// "Amara · 2h", plus a hint when more than one option can be chosen.
    private var byline: String {
        [
            poll.profile?.fullName,
            poll.createdAt?.relativeText,
            poll.allowMultiple ? "Pick any" : nil,
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }

    /// Time left when there is a deadline, otherwise that the poll is open.
    /// Each is a tint and ink pair with a word, so colour never stands alone.
    @ViewBuilder
    private var statusPill: some View {
        if let closesAt = poll.closesAt, let timeLeft = poll.timeLeftText(at: Date()) {
            pill(timeLeft, symbol: "clock", style: .planning)
                .accessibilityLabel(Text("Closes \(closesAt, format: .relative(presentation: .numeric))"))
        } else {
            pill("Open", symbol: nil, style: .active)
        }
    }

    private func pill(_ text: String, symbol: String?, style: OuestTheme.StatusStyle) -> some View {
        HStack(spacing: OuestTheme.Spacing.xs) {
            if let symbol {
                Image(systemName: symbol)
            }
            Text(text)
        }
        .font(OuestTheme.Typography.micro)
        .monospacedDigit()
        .foregroundStyle(style.ink)
        .padding(.horizontal, OuestTheme.Spacing.sm)
        .padding(.vertical, OuestTheme.Spacing.xs)
        .background(style.tint, in: Capsule())
        .fixedSize()
        .accessibilityElement(children: .combine)
    }

    // MARK: - Options

    private func optionRows(interactive: Bool) -> some View {
        VStack(spacing: OuestTheme.Spacing.sm) {
            ForEach(poll.sortedOptions) { option in
                PollOptionRow(
                    option: option,
                    share: option.votePercentage(totalVotes: poll.totalVotes),
                    isMine: currentUserId.map { option.hasVote(by: $0) } ?? false,
                    isInteractive: interactive && canEdit,
                    isBusy: isVoting
                ) {
                    isVoting = true
                    Task {
                        await viewModel.toggleVote(poll: poll, option: option)
                        isVoting = false
                    }
                }
            }
        }
    }

    // MARK: - Turnout

    /// How much of the group has voted and who it is still waiting on. Falls
    /// back to a plain count when the member list is not loaded.
    @ViewBuilder
    private var turnout: some View {
        let turnout = viewModel.turnout(for: poll)
        let total = turnout.voted.count + turnout.waiting.count

        Group {
            if total == 0 {
                Text("^[\(poll.totalVotes) vote](inflect: true)")
            } else if turnout.waiting.isEmpty {
                Label("Everyone voted", systemImage: "checkmark.circle.fill")
                    .labelStyle(.titleAndIcon)
                    .symbolEffect(.bounce, value: turnout.waiting.isEmpty)
            } else if turnout.voted.isEmpty {
                // "Waiting on" everyone says nothing a blank poll doesn't.
                Text("No votes yet")
            } else {
                HStack(spacing: OuestTheme.Spacing.sm) {
                    Text(
                        dynamicTypeSize.isAccessibilitySize
                            ? "\(turnout.voted.count) of \(total) voted"
                            : "\(turnout.voted.count) of \(total) voted · waiting on"
                    )
                    .contentTransition(.numericText(value: Double(turnout.voted.count)))

                    if !dynamicTypeSize.isAccessibilitySize {
                        avatarStack(turnout.waiting.map { $0.profile?.avatarUrl })
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(waitingLabel(voted: turnout.voted.count, total: total, waiting: turnout.waiting))
            }
        }
        .font(OuestTheme.Typography.caption)
        .monospacedDigit()
        .foregroundStyle(OuestTheme.Colors.textSecondary)
        .animation(reduceMotion ? nil : OuestTheme.Anim.quick, value: turnout.voted.count)
    }

    private func waitingLabel(voted: Int, total: Int, waiting: [TripMember]) -> String {
        let names = waiting.compactMap { $0.profile?.fullName }
        let who = names.count == waiting.count
            ? names.formatted(.list(type: .and))
            : "\(waiting.count) more"
        return "\(voted) of \(total) voted. Waiting on \(who)"
    }

    private func avatarStack(_ urls: [String?]) -> some View {
        HStack(spacing: -OuestTheme.Spacing.xs) {
            ForEach(Array(urls.prefix(3).enumerated()), id: \.offset) { _, url in
                AvatarView(url: url, size: 20)
                    .overlay(Circle().stroke(OuestTheme.Colors.surface, lineWidth: 1.5))
            }
            if urls.count > 3 {
                Text("+\(urls.count - 3)")
                    .font(OuestTheme.Typography.micro)
                    .padding(.leading, OuestTheme.Spacing.sm)
            }
        }
    }

    // MARK: - Decided

    private var decidedContent: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.md) {
            Button {
                HapticFeedback.light()
                withAnimation(reduceMotion ? nil : OuestTheme.Anim.smooth) {
                    showsAllVotes.toggle()
                }
            } label: {
                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        // At the largest text sizes the pick needs the full
                        // width, so it drops under the icon and the count
                        // under the pick.
                        VStack(alignment: .leading, spacing: OuestTheme.Spacing.sm) {
                            HStack {
                                outcomeWell
                                Spacer(minLength: OuestTheme.Spacing.sm)
                                outcomeChevron
                            }
                            outcomeText(showsDetail: true)
                        }
                    } else {
                        HStack(spacing: OuestTheme.Spacing.md) {
                            outcomeWell
                            outcomeText(showsDetail: false)
                            Spacer(minLength: OuestTheme.Spacing.sm)
                            if let outcomeDetail {
                                outcomeDetailText(outcomeDetail)
                            }
                            outcomeChevron
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityValue(showsAllVotes ? "Expanded" : "Collapsed")
            .accessibilityHint("Shows every vote")

            if showsAllVotes {
                optionRows(interactive: false)

                HStack(spacing: OuestTheme.Spacing.sm) {
                    Text("^[\(poll.totalVotes) vote](inflect: true)")
                        .font(OuestTheme.Typography.caption)
                        .monospacedDigit()
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                    Spacer(minLength: OuestTheme.Spacing.sm)
                    actionsMenu
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var outcomeWell: some View {
        Image(systemName: outcomeSymbol)
            .font(OuestTheme.Icon.control)
            .foregroundStyle(OuestTheme.Colors.brandInk)
            .frame(width: wellSize, height: wellSize)
            .background(
                OuestTheme.Colors.brandLight,
                in: RoundedRectangle(cornerRadius: OuestTheme.Radius.sm, style: .continuous)
            )
    }

    private var outcomeChevron: some View {
        Image(systemName: "chevron.down")
            .font(OuestTheme.Typography.caption)
            .foregroundStyle(OuestTheme.Colors.textTertiary)
            .rotationEffect(.degrees(showsAllVotes ? 180 : 0))
    }

    private func outcomeText(showsDetail: Bool) -> some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.xxs) {
            Text(poll.title)
                .font(OuestTheme.Typography.caption)
                .foregroundStyle(OuestTheme.Colors.textSecondary)
                .lineLimit(2)

            Text(outcomeTitle)
                .font(OuestTheme.Typography.cardTitle)
                .foregroundStyle(OuestTheme.Colors.textPrimary)

            if showsDetail, let outcomeDetail {
                outcomeDetailText(outcomeDetail)
            }
        }
        .multilineTextAlignment(.leading)
    }

    private func outcomeDetailText(_ text: String) -> some View {
        Text(text)
            .font(OuestTheme.Typography.caption)
            .monospacedDigit()
            .foregroundStyle(OuestTheme.Colors.textSecondary)
    }

    private var outcomeSymbol: String {
        switch poll.outcome {
        case .winner: "trophy.fill"
        case .tie: "equal.circle.fill"
        case .noVotes: "minus.circle"
        }
    }

    private var outcomeTitle: String {
        switch poll.outcome {
        case .winner(let option): option.title
        case .tie(let options): "Tie: " + options.map(\.title).formatted(.list(type: .and))
        case .noVotes: "No votes"
        }
    }

    private var outcomeDetail: String? {
        switch poll.outcome {
        case .winner(let option): "\(option.voteCount) of \(poll.totalVotes)"
        case .tie(let options): options.first.map { "\($0.voteCount) each" }
        case .noVotes: nil
        }
    }

    // MARK: - Actions

    /// Close and delete, for the poll's creator and the trip owner.
    @ViewBuilder
    private var actionsMenu: some View {
        if viewModel.canClose(poll) || viewModel.canDelete(poll) {
            Menu {
                if poll.isOpen && viewModel.canClose(poll) {
                    Button {
                        HapticFeedback.medium()
                        Task { await viewModel.closePoll(poll) }
                    } label: {
                        Label("Close poll", systemImage: "checkmark.seal")
                    }
                }

                if viewModel.canDelete(poll) {
                    Button(role: .destructive) {
                        HapticFeedback.medium()
                        Task { await viewModel.deletePoll(poll) }
                    } label: {
                        Label("Delete poll", systemImage: "trash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(OuestTheme.Icon.inline)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
                    .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
                    .contentShape(Rectangle())
            }
            // A full-size tap target that takes only a text line of room,
            // so the card's bottom edge stays as tight as its top.
            .padding(.vertical, -OuestTheme.Spacing.md)
            .accessibilityLabel("Poll actions")
        }
    }
}

// MARK: - Option row

/// One option. The row itself is the bar: its background fills with the
/// option's share of the vote.
///
/// Casting a vote is the moment the screen exists for, so it is rewarded: the
/// row pops, the bar springs to its new share, the tick bounces in with a
/// burst, a sheen crosses the row and the phone taps. Taking a vote back gets
/// none of that. Under Reduce Motion the pop, sheen and flying particles drop
/// away and the haptic, tick and bar still mark the vote.
private struct PollOptionRow: View {
    let option: PollOption
    /// This option's part of all votes, 0 to 1.
    let share: Double
    let isMine: Bool
    /// An open poll the viewer may vote on.
    let isInteractive: Bool
    /// A vote is on its way to the server. Taps wait so two can't cross.
    let isBusy: Bool
    let onVote: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @State private var rewardCount = 0
    @State private var burst = false

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: OuestTheme.Radius.md, style: .continuous)
    }

    var body: some View {
        Button {
            guard !isBusy else { return }
            if isMine {
                HapticFeedback.light()
            } else {
                reward()
            }
            onVote()
        } label: {
            label
        }
        .buttonStyle(ScaledButtonStyle(scale: 0.98))
        .disabled(!isInteractive)
        .keyframeAnimator(initialValue: CGFloat(1), trigger: rewardCount) { content, scale in
            content.scaleEffect(scale)
        } keyframes: { _ in
            KeyframeTrack {
                SpringKeyframe(1.035, duration: 0.14)
                SpringKeyframe(1, duration: 0.45, spring: .bouncy)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(option.title)
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(isMine ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(isInteractive ? (isMine ? "Takes your vote back" : "Votes for this option") : "")
    }

    private var accessibilityValue: String {
        let percent = share.formatted(.percent.precision(.fractionLength(0)))
        let votes = "\(option.voteCount) \(option.voteCount == 1 ? "vote" : "votes")"
        return isMine ? "\(percent), \(votes), your vote" : "\(percent), \(votes)"
    }

    private var label: some View {
        HStack(spacing: OuestTheme.Spacing.sm) {
            if isInteractive || isMine {
                Image(systemName: isMine ? "checkmark.circle.fill" : "circle")
                    .font(OuestTheme.Icon.inline)
                    .foregroundStyle(isMine ? OuestTheme.Colors.brandInk : OuestTheme.Colors.textTertiary)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, value: rewardCount)
            }

            if dynamicTypeSize.isAccessibilitySize {
                // At the largest text sizes the share goes under the title,
                // which then has the row's width and stops breaking words.
                VStack(alignment: .leading, spacing: OuestTheme.Spacing.xxs) {
                    title
                    shareText
                }
                Spacer(minLength: 0)
            } else {
                title

                Spacer(minLength: OuestTheme.Spacing.sm)

                if let votes = option.votes, !votes.isEmpty {
                    HStack(spacing: -OuestTheme.Spacing.xs) {
                        ForEach(votes.prefix(3)) { vote in
                            AvatarView(url: vote.profile?.avatarUrl, size: 20)
                                .overlay(Circle().stroke(OuestTheme.Colors.surface, lineWidth: 1.5))
                        }
                    }
                }

                shareText
            }
        }
        .padding(.horizontal, OuestTheme.Spacing.md)
        .padding(.vertical, OuestTheme.Spacing.sm)
        .frame(maxWidth: .infinity, minHeight: OuestTheme.Layout.controlHeight, alignment: .leading)
        .background { bar }
        .clipShape(shape)
        .overlay {
            if isMine {
                shape.strokeBorder(OuestTheme.Colors.brandFill, lineWidth: 1.5)
            }
        }
        // The burst sits outside the clip so its particles can leave the row.
        // The well matches where the tick is drawn.
        .overlay(alignment: .leading) {
            Color.clear
                .frame(width: 44, height: 44)
                .likeBurst(trigger: burst)
                .allowsHitTesting(false)
        }
        .contentShape(shape)
    }

    private var title: some View {
        Text(option.title)
            .font(OuestTheme.Typography.body)
            .fontWeight(isMine ? .semibold : .regular)
            .foregroundStyle(OuestTheme.Colors.textPrimary)
            .multilineTextAlignment(.leading)
    }

    private var shareText: some View {
        Text(share, format: .percent.precision(.fractionLength(0)))
            .font(OuestTheme.Typography.caption)
            .fontWeight(.semibold)
            .monospacedDigit()
            .foregroundStyle(isMine ? OuestTheme.Colors.brandInk : OuestTheme.Colors.textSecondary)
            .contentTransition(.numericText(value: share))
            .animation(reduceMotion ? nil : OuestTheme.Anim.quick, value: share)
    }

    /// The track, the option's share of the vote, and the sheen that crosses
    /// both when a vote lands.
    private var bar: some View {
        ZStack(alignment: .leading) {
            OuestTheme.Colors.fill

            // `brandOutline` is the one brand tint that stays visible on
            // `fill` in both appearances; `brandLight` disappears in dark.
            Rectangle()
                .fill(OuestTheme.Colors.brandOutline)
                .scaleEffect(x: share, anchor: .leading)
                .animation(
                    reduceMotion ? .easeInOut(duration: 0.2) : OuestTheme.Anim.bouncy,
                    value: share
                )

            GeometryReader { geo in
                let width = geo.size.width
                LinearGradient(
                    colors: [
                        .clear,
                        OuestTheme.Colors.textInverse.opacity(colorScheme == .dark ? 0.18 : 0.6),
                        .clear,
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: width * 0.4)
                .keyframeAnimator(initialValue: CGFloat(-0.5), trigger: rewardCount) { content, position in
                    content.offset(x: position * width)
                } keyframes: { _ in
                    KeyframeTrack {
                        LinearKeyframe(-0.5, duration: 0.12)
                        CubicKeyframe(1.1, duration: 0.6)
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }

    private func reward() {
        HapticFeedback.success()
        burst = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            burst = false
        }
        // The pop and the sheen are movement. The burst fades in place by
        // itself under Reduce Motion.
        if !reduceMotion {
            rewardCount += 1
        }
    }
}

// MARK: - Previews

private let previewPoll = UUID()

private func previewOption(_ title: String, votes: Int) -> PollOption {
    let id = UUID()
    return PollOption(
        id: id,
        pollId: previewPoll,
        title: title,
        votes: (0..<votes).map { _ in PollVote(pollId: previewPoll, optionId: id, userId: UUID()) }
    )
}

private struct PollOptionRowPreview: View {
    @State private var mine = 1
    private let options = [
        previewOption("Sushi Dai", votes: 3),
        previewOption("Ramen Street, the one by the station with the long queue", votes: 1),
        previewOption("Izakaya Toyo", votes: 0),
    ]

    var body: some View {
        OuestCard {
            VStack(spacing: OuestTheme.Spacing.sm) {
                ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                    PollOptionRow(
                        option: option,
                        share: Double(option.voteCount) / 4,
                        isMine: mine == index,
                        isInteractive: true,
                        isBusy: false
                    ) { mine = index }
                }
            }
        }
        .padding(OuestTheme.Layout.pageGutter)
        .frame(maxHeight: .infinity)
        .background(OuestTheme.Colors.background)
    }
}

#Preview("Option rows") {
    PollOptionRowPreview()
}

#Preview("Option rows, dark") {
    PollOptionRowPreview()
        .preferredColorScheme(.dark)
}

#Preview("Option rows, largest text") {
    PollOptionRowPreview()
        .dynamicTypeSize(.accessibility5)
}
