import SwiftUI

/// A trip's polls, split by the two questions a group has: what still needs
/// my vote, and what did we pick.
struct PollsView: View {
    let trip: Trip
    let canEdit: Bool
    @State private var viewModel: PollsViewModel
    @State private var showCreatePoll = false
    @State private var contentAppeared = false
    /// The time the two sections are sorted against. Moved forward as each
    /// deadline passes so a poll changes section when its voting stops.
    @State private var now = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(trip: Trip, canEdit: Bool = true) {
        self.trip = trip
        self.canEdit = canEdit
        _viewModel = State(initialValue: PollsViewModel(trip: trip))
    }

    private var openPolls: [Poll] { viewModel.polls.filter { $0.isOpen(at: now) } }
    private var decidedPolls: [Poll] { viewModel.polls.filter { !$0.isOpen(at: now) } }
    private var nextDeadline: Date? { openPolls.compactMap(\.closesAt).min() }

    var body: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if let failure = viewModel.failure, viewModel.polls.isEmpty {
                OuestErrorState(
                    error: failure,
                    context: "the polls",
                    detail: viewModel.failureDetail,
                    onRecover: { Task { await viewModel.loadPolls() } }
                )
            } else if viewModel.polls.isEmpty {
                emptyState
            } else {
                pollsList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OuestTheme.Colors.background)
        .navigationTitle("Polls")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if canEdit {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        createPoll()
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                            .foregroundStyle(OuestTheme.Colors.brandInk)
                    }
                    .accessibilityLabel("Create poll")
                }
            }
        }
        .sheet(isPresented: $showCreatePoll) {
            CreatePollView(viewModel: viewModel, trip: trip)
        }
        .ouestToast($viewModel.toast)
        .task {
            await viewModel.loadPolls()
            withAnimation(OuestTheme.Anim.smooth) {
                contentAppeared = true
            }
        }
        .task(id: nextDeadline) {
            guard let nextDeadline else { return }
            try? await Task.sleep(for: .seconds(max(0, nextDeadline.timeIntervalSinceNow)))
            guard !Task.isCancelled else { return }
            now = Date()
        }
        .refreshable {
            // Content stays in place; pull-to-refresh shouldn't replay the entrance.
            await viewModel.loadPolls()
            now = Date()
        }
    }

    private func createPoll() {
        HapticFeedback.light()
        viewModel.resetForm()
        showCreatePoll = true
    }

    // MARK: - Loading

    private var loadingView: some View {
        ScrollView {
            VStack(spacing: OuestTheme.Layout.stackGap) {
                ForEach(0..<2, id: \.self) { _ in
                    OuestCard {
                        VStack(alignment: .leading, spacing: OuestTheme.Spacing.md) {
                            SkeletonView(width: 180, height: 18)
                            SkeletonView(width: 120, height: 12)
                            ForEach(0..<3, id: \.self) { _ in
                                SkeletonView(
                                    height: OuestTheme.Layout.controlHeight,
                                    radius: OuestTheme.Radius.md
                                )
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.horizontal, OuestTheme.Layout.pageGutter)
            .padding(.vertical, OuestTheme.Spacing.lg)
        }
        .accessibilityLabel("Loading polls")
    }

    // MARK: - Empty State

    private var emptyState: some View {
        OuestEmptyState(
            symbol: "chart.bar",
            title: "Decide together",
            message: canEdit
                ? "Ask the group a question and see where everyone lands."
                : "Polls from the group show up here.",
            primary: canEdit ? .init("Create poll") { createPoll() } : nil
        )
    }

    // MARK: - Polls List

    private var pollsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: OuestTheme.Layout.sectionGap) {
                if !openPolls.isEmpty {
                    section("Voting now", polls: openPolls, firstIndex: 0)
                }
                if !decidedPolls.isEmpty {
                    section("Decided", polls: decidedPolls, firstIndex: openPolls.count)
                }
            }
            .padding(.horizontal, OuestTheme.Layout.pageGutter)
            .padding(.top, OuestTheme.Spacing.lg)
            // The tab bar floats over this screen.
            .padding(.bottom, OuestTheme.Layout.tabBarInset)
            // A poll slides to Decided when it closes instead of jumping.
            .animation(reduceMotion ? nil : OuestTheme.Anim.smooth, value: openPolls.map(\.id))
        }
    }

    private func section(_ title: String, polls: [Poll], firstIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: OuestTheme.Layout.stackGap) {
            Text(title)
                .font(OuestTheme.Typography.sectionTitle)
                .foregroundStyle(OuestTheme.Colors.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .appear(contentAppeared, index: firstIndex)

            ForEach(Array(polls.enumerated()), id: \.element.id) { index, poll in
                PollCardView(poll: poll, viewModel: viewModel, canEdit: canEdit)
                    .appear(contentAppeared, index: firstIndex + index)
            }
        }
    }
}
