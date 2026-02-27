import SwiftUI

struct PollsView: View {
    let trip: Trip
    @State private var viewModel: PollsViewModel
    @State private var showCreatePoll = false
    @State private var contentAppeared = false

    init(trip: Trip) {
        self.trip = trip
        _viewModel = State(initialValue: PollsViewModel(trip: trip))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if viewModel.polls.isEmpty {
                emptyState
            } else {
                pollsList
            }
        }
        .navigationTitle("Polls")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    HapticFeedback.light()
                    viewModel.resetForm()
                    showCreatePoll = true
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                        .foregroundStyle(OuestTheme.Colors.brand)
                }
            }
        }
        .sheet(isPresented: $showCreatePoll) {
            CreatePollView(viewModel: viewModel, trip: trip)
        }
        .task {
            await viewModel.loadPolls()
            withAnimation(OuestTheme.Anim.smooth) {
                contentAppeared = true
            }
        }
        .refreshable {
            contentAppeared = false
            await viewModel.loadPolls()
            withAnimation(OuestTheme.Anim.smooth) {
                contentAppeared = true
            }
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        ScrollView {
            VStack(spacing: OuestTheme.Spacing.lg) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: OuestTheme.Spacing.md) {
                        SkeletonView(width: 180, height: 18)
                        SkeletonView(width: 120, height: 12)
                        ForEach(0..<3, id: \.self) { _ in
                            VStack(alignment: .leading, spacing: OuestTheme.Spacing.xs) {
                                SkeletonView(height: 16)
                                SkeletonView(height: 6)
                            }
                        }
                    }
                    .padding(OuestTheme.Spacing.lg)
                    .background(OuestTheme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.lg))
                    .shadow(OuestTheme.Shadow.sm)
                }
            }
            .padding(.horizontal, OuestTheme.Spacing.xl)
            .padding(.vertical, OuestTheme.Spacing.lg)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        EmptyStateView(
            icon: "chart.bar",
            title: "No Polls Yet",
            message: "Create a poll to help your group decide together."
        )
    }

    // MARK: - Polls List

    private var pollsList: some View {
        ScrollView {
            LazyVStack(spacing: OuestTheme.Spacing.lg) {
                ForEach(Array(viewModel.polls.enumerated()), id: \.element.id) { index, poll in
                    PollCardView(poll: poll, viewModel: viewModel)
                        .fadeSlideIn(isVisible: contentAppeared, delay: Double(index) * 0.06)
                }
            }
            .padding(.horizontal, OuestTheme.Spacing.xl)
            .padding(.vertical, OuestTheme.Spacing.lg)
        }
    }
}
