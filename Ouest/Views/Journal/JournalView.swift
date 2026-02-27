import SwiftUI

struct JournalView: View {
    let trip: Trip
    @State private var viewModel = JournalViewModel()
    @State private var showAddEntry = false
    @State private var editingEntry: JournalEntry?
    @State private var contentAppeared = false

    var body: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if viewModel.entries.isEmpty {
                emptyState
            } else {
                timelineView
            }
        }
        .navigationTitle("Journal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    HapticFeedback.light()
                    viewModel.resetForm()
                    showAddEntry = true
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                        .foregroundStyle(OuestTheme.Colors.brand)
                }
            }
        }
        .sheet(isPresented: $showAddEntry) {
            AddJournalEntryView(viewModel: viewModel, trip: trip, entry: nil)
        }
        .sheet(item: $editingEntry) { entry in
            AddJournalEntryView(viewModel: viewModel, trip: trip, entry: entry)
        }
        .task {
            await viewModel.loadEntries(tripId: trip.id)
            withAnimation(OuestTheme.Anim.smooth) {
                contentAppeared = true
            }
        }
        .refreshable {
            await viewModel.loadEntries(tripId: trip.id)
        }
    }

    // MARK: - Timeline

    private var timelineView: some View {
        ScrollView {
            LazyVStack(spacing: OuestTheme.Spacing.lg) {
                ForEach(Array(viewModel.groupedEntries.enumerated()), id: \.element.date) { groupIndex, group in
                    // Date header
                    HStack {
                        Text(group.date.formatted_MMMdyyyy)
                            .font(OuestTheme.Typography.sectionTitle)
                            .foregroundStyle(OuestTheme.Colors.textSecondary)
                        Spacer()
                        Text("\(group.entries.count) \(group.entries.count == 1 ? "entry" : "entries")")
                            .font(OuestTheme.Typography.micro)
                            .foregroundStyle(OuestTheme.Colors.textSecondary)
                    }
                    .padding(.horizontal, OuestTheme.Spacing.xl)
                    .fadeSlideIn(isVisible: contentAppeared, delay: Double(groupIndex) * 0.06)

                    // Entries for this date
                    ForEach(Array(group.entries.enumerated()), id: \.element.id) { entryIndex, entry in
                        Button {
                            viewModel.populateFromEntry(entry)
                            editingEntry = entry
                        } label: {
                            JournalEntryCard(entry: entry)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                Task {
                                    await viewModel.deleteEntry(entry)
                                    HapticFeedback.success()
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .padding(.horizontal, OuestTheme.Spacing.xl)
                        .fadeSlideIn(
                            isVisible: contentAppeared,
                            delay: Double(groupIndex) * 0.06 + Double(entryIndex + 1) * 0.04
                        )
                    }
                }
            }
            .padding(.vertical, OuestTheme.Spacing.lg)
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        ScrollView {
            VStack(spacing: OuestTheme.Spacing.lg) {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonView(height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.lg))
                }
            }
            .padding(.horizontal, OuestTheme.Spacing.xl)
            .padding(.vertical, OuestTheme.Spacing.lg)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        EmptyStateView(
            icon: "book",
            title: "No Entries Yet",
            message: "Start capturing your travel memories — photos, thoughts, and moments from your trip."
        )
    }
}

#Preview {
    NavigationStack {
        JournalView(
            trip: Trip(
                id: UUID(), createdBy: UUID(), title: "Test Trip",
                destination: "Paris", status: .active, isPublic: false,
                createdAt: nil
            )
        )
    }
}
