import SwiftUI

/// The trip's shared packing list. Job: see what's still to pack and tick
/// it off. One primary action (add an item), grouped by category, packed
/// items sink to the bottom of their group.
struct PackingListView: View {
    let trip: Trip
    let canEdit: Bool
    @State private var viewModel: PackingListViewModel
    @State private var showAddItem = false

    init(trip: Trip, canEdit: Bool = true) {
        self.trip = trip
        self.canEdit = canEdit
        _viewModel = State(initialValue: PackingListViewModel(trip: trip))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if let failure = viewModel.failure, viewModel.items.isEmpty {
                OuestErrorState(
                    error: failure,
                    context: "the packing list",
                    detail: viewModel.failureDetail,
                    onRecover: { Task { await viewModel.load() } }
                )
            } else if viewModel.items.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .navigationTitle("Packing")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if canEdit {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticFeedback.light()
                        viewModel.resetForm(keepingCategory: true)
                        showAddItem = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                            .foregroundStyle(OuestTheme.Colors.brandInk)
                    }
                    .accessibilityLabel("Add item")
                }
            }
        }
        .sheet(isPresented: $showAddItem) {
            AddPackingItemView(viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .ouestToast($viewModel.toast)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    // MARK: - Loading

    private var loadingView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: OuestTheme.Layout.stackGap) {
                SkeletonView(width: 160, height: 14)
                SkeletonView(height: 6, radius: OuestTheme.Radius.full)
                ForEach(0..<6, id: \.self) { _ in
                    HStack(spacing: OuestTheme.Spacing.md) {
                        SkeletonView(width: 24, height: 24, radius: OuestTheme.Radius.full)
                        SkeletonView(height: 16)
                    }
                    .padding(.vertical, OuestTheme.Spacing.sm)
                }
            }
            .padding(.horizontal, OuestTheme.Layout.pageGutter)
            .padding(.vertical, OuestTheme.Spacing.lg)
        }
        .background(OuestTheme.Colors.background)
    }

    // MARK: - Empty

    private var emptyState: some View {
        OuestEmptyState(
            symbol: "checklist",
            title: "Pack together",
            message: canEdit
                ? "Add what the group needs to bring and tick things off as they're packed."
                : "Members haven't added anything to the list yet.",
            primary: canEdit ? .init("Add an item") {
                HapticFeedback.light()
                viewModel.resetForm()
                showAddItem = true
            } : nil,
            secondary: canEdit ? .init("Start with the basics") {
                HapticFeedback.light()
                Task { await viewModel.addStarterItems() }
            } : nil
        )
    }

    // MARK: - List

    private var list: some View {
        List {
            Section {
                progressRow
            }
            .listRowBackground(OuestTheme.Colors.surface)

            ForEach(viewModel.sections, id: \.category) { section in
                Section {
                    ForEach(section.items) { item in
                        PackingItemRow(item: item, viewModel: viewModel, canEdit: canEdit)
                    }
                } header: {
                    Label(section.category.label, systemImage: section.category.icon)
                        .font(OuestTheme.Typography.caption)
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                }
                .listRowBackground(OuestTheme.Colors.surface)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, OuestTheme.Layout.tabBarInset, for: .scrollContent)
        .background(OuestTheme.Colors.background)
        .animation(OuestTheme.Anim.smooth, value: viewModel.items)
    }

    private var progressRow: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.sm) {
            HStack {
                if viewModel.isEverythingPacked {
                    Label("Everything's packed", systemImage: "checkmark.seal.fill")
                        .font(OuestTheme.Typography.cardTitle)
                        .foregroundStyle(OuestTheme.Colors.successFill)
                } else {
                    Text("\(viewModel.packedCount) of \(viewModel.totalCount) packed")
                        .font(OuestTheme.Typography.cardTitle)
                        .foregroundStyle(OuestTheme.Colors.textPrimary)
                        .monospacedDigit()
                }
                Spacer()
            }
            ProgressView(value: viewModel.progress)
                .tint(viewModel.isEverythingPacked ? OuestTheme.Colors.successFill : OuestTheme.Colors.brandFill)
        }
        .padding(.vertical, OuestTheme.Spacing.xs)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Row

private struct PackingItemRow: View {
    let item: PackingItem
    let viewModel: PackingListViewModel
    let canEdit: Bool

    private var assigneeName: String? {
        guard let profile = item.assignee ?? viewModel.member(for: item.assignedTo)?.profile else { return nil }
        if profile.id == viewModel.currentUserId { return "You" }
        return profile.fullName ?? profile.handle.map { "@\($0)" }
    }

    var body: some View {
        Button {
            guard canEdit else { return }
            HapticFeedback.selection()
            Task { await viewModel.togglePacked(item) }
        } label: {
            HStack(spacing: OuestTheme.Spacing.md) {
                Image(systemName: item.isPacked ? "checkmark.circle.fill" : "circle")
                    .font(OuestTheme.Icon.control)
                    .foregroundStyle(item.isPacked ? OuestTheme.Colors.brandInk : OuestTheme.Colors.textTertiary)
                    .contentTransition(.symbolEffect(.replace))

                VStack(alignment: .leading, spacing: OuestTheme.Spacing.xxs) {
                    Text(item.title)
                        .font(OuestTheme.Typography.body)
                        .foregroundStyle(item.isPacked ? OuestTheme.Colors.textTertiary : OuestTheme.Colors.textPrimary)
                        .strikethrough(item.isPacked, color: OuestTheme.Colors.textTertiary)
                    if let assigneeName {
                        HStack(spacing: OuestTheme.Spacing.xs) {
                            AvatarView(url: item.assignee?.avatarUrl, size: 16)
                            Text(assigneeName)
                                .font(OuestTheme.Typography.micro)
                                .foregroundStyle(OuestTheme.Colors.textSecondary)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(item.isPacked ? [.isButton, .isSelected] : .isButton)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if canEdit {
                if item.assignedTo == viewModel.currentUserId {
                    Button {
                        Task { await viewModel.assign(item, to: nil) }
                    } label: {
                        Label("Unassign", systemImage: "person.slash")
                    }
                    .tint(OuestTheme.Colors.textSecondary)
                } else {
                    Button {
                        Task { await viewModel.assign(item, to: viewModel.currentUserId) }
                    } label: {
                        Label("I'll bring it", systemImage: "person.fill.checkmark")
                    }
                    .tint(OuestTheme.Colors.brandFill)
                }
            }
        }
        .swipeActions(edge: .trailing) {
            if canEdit && viewModel.canDelete(item) {
                Button(role: .destructive) {
                    Task { await viewModel.delete(item) }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .contextMenu {
            if canEdit && !viewModel.members.isEmpty {
                Menu("Who's bringing it") {
                    Button("Nobody yet") { Task { await viewModel.assign(item, to: nil) } }
                    ForEach(viewModel.members) { member in
                        Button(member.profile?.fullName ?? member.profile?.handle ?? "Member") {
                            Task { await viewModel.assign(item, to: member.userId) }
                        }
                    }
                }
            }
        }
    }

    private var accessibilityText: String {
        var parts = [item.title, item.isPacked ? "packed" : "not packed"]
        if let assigneeName { parts.append("\(assigneeName) bringing it") }
        return parts.joined(separator: ", ")
    }
}
