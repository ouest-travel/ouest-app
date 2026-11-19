import SwiftUI

/// Quick-add sheet for one packing item: a name, a category and, optionally,
/// who's bringing it. Return adds and keeps the sheet open so a list can be
/// typed in one go.
struct AddPackingItemView: View {
    @Bindable var viewModel: PackingListViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var titleFocused: Bool
    @State private var addedCount = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: OuestTheme.Layout.sectionGap) {
                    titleSection
                    categorySection
                    if !viewModel.members.isEmpty {
                        assigneeSection
                    }
                }
                .padding(.horizontal, OuestTheme.Layout.pageGutter)
                .padding(.vertical, OuestTheme.Spacing.lg)
            }
            .background(OuestTheme.Colors.background)
            .navigationTitle(addedCount == 0 ? "Add item" : "Added \(addedCount)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(addedCount == 0 ? "Cancel" : "Done") { dismiss() }
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") { Task { await add() } }
                        .fontWeight(.semibold)
                        .foregroundStyle(OuestTheme.Colors.brandInk)
                        .disabled(!viewModel.isFormValid || viewModel.isSaving)
                        .opacity(viewModel.isFormValid && !viewModel.isSaving ? 1 : 0.4)
                }
            }
            .onAppear { titleFocused = true }
        }
    }

    // MARK: - Sections

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.sm) {
            sectionHeader("Item", icon: "checklist")
            OuestTextField(text: $viewModel.newTitle, placeholder: "Sunscreen, adapter, speaker…")
                .focused($titleFocused)
                .submitLabel(.done)
                .onSubmit { Task { await add() } }
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.sm) {
            sectionHeader("Category", icon: "square.grid.2x2")
            chipRow {
                ForEach(PackingCategory.allCases, id: \.self) { category in
                    chip(
                        label: category.label,
                        icon: category.icon,
                        isSelected: viewModel.newCategory == category
                    ) {
                        viewModel.newCategory = category
                    }
                }
            }
        }
    }

    private var assigneeSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.sm) {
            sectionHeader("Who's bringing it", icon: "person.2")
            chipRow {
                chip(label: "Anyone", icon: nil, isSelected: viewModel.newAssignee == nil) {
                    viewModel.newAssignee = nil
                }
                ForEach(viewModel.members) { member in
                    let name = member.userId == viewModel.currentUserId
                        ? "You"
                        : (member.profile?.fullName ?? member.profile?.handle ?? "Member")
                    chip(label: name, icon: nil, isSelected: viewModel.newAssignee == member.userId) {
                        viewModel.newAssignee = member.userId
                    }
                }
            }
        }
    }

    // MARK: - Pieces

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: OuestTheme.Spacing.xs) {
            Image(systemName: icon)
                .font(OuestTheme.Icon.inline)
                .foregroundStyle(OuestTheme.Colors.brandInk)
            Text(title)
                .font(OuestTheme.Typography.sectionTitle)
                .foregroundStyle(OuestTheme.Colors.textPrimary)
        }
    }

    /// Chips wrap onto new lines at large type instead of truncating.
    private func chipRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: OuestTheme.Spacing.sm) { content() }
        }
        .scrollClipDisabled()
    }

    private func chip(label: String, icon: String?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            HapticFeedback.selection()
            withAnimation(OuestTheme.Anim.quick) { action() }
        } label: {
            HStack(spacing: OuestTheme.Spacing.xs) {
                if let icon {
                    Image(systemName: icon).font(OuestTheme.Icon.inline)
                }
                Text(label)
                    .font(OuestTheme.Typography.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? OuestTheme.Colors.textInverse : OuestTheme.Colors.textPrimary)
            .padding(.horizontal, OuestTheme.Spacing.md)
            .frame(minHeight: 36)
            .background(isSelected ? OuestTheme.Colors.brandFill : OuestTheme.Colors.fill)
            .clipShape(Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Add

    private func add() async {
        guard viewModel.isFormValid, !viewModel.isSaving else { return }
        if await viewModel.addItem() {
            HapticFeedback.success()
            addedCount += 1
            titleFocused = true
        } else {
            HapticFeedback.error()
        }
    }
}
