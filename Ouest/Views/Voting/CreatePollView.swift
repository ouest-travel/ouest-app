import SwiftUI

struct CreatePollView: View {
    @Bindable var viewModel: PollsViewModel
    let trip: Trip
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: OuestTheme.Spacing.xxl) {
                    // Question / Title
                    titleSection

                    // Description (optional)
                    descriptionSection

                    // Options
                    optionsSection

                    // Settings
                    settingsSection
                }
                .padding(.horizontal, OuestTheme.Spacing.xl)
                .padding(.vertical, OuestTheme.Spacing.lg)
            }
            .navigationTitle("New Poll")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") {
                        Task { await save() }
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(OuestTheme.Colors.brand)
                    .disabled(!viewModel.isFormValid || viewModel.isSaving)
                    .opacity(viewModel.isFormValid && !viewModel.isSaving ? 1 : 0.4)
                }
            }
        }
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.sm) {
            HStack(spacing: OuestTheme.Spacing.xs) {
                Image(systemName: "questionmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(OuestTheme.Colors.brand)
                Text("Question")
                    .font(OuestTheme.Typography.sectionTitle)
            }

            OuestTextField(text: $viewModel.pollTitle, placeholder: "What should we decide?")
        }
    }

    // MARK: - Description Section

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.sm) {
            HStack(spacing: OuestTheme.Spacing.xs) {
                Image(systemName: "text.alignleft")
                    .font(.subheadline)
                    .foregroundStyle(OuestTheme.Colors.brand)
                Text("Description")
                    .font(OuestTheme.Typography.sectionTitle)

                Text("(optional)")
                    .font(OuestTheme.Typography.caption)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
            }

            TextEditor(text: $viewModel.pollDescription)
                .font(.subheadline)
                .frame(minHeight: 60, maxHeight: 120)
                .padding(OuestTheme.Spacing.sm)
                .background(OuestTheme.Colors.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
                .overlay(alignment: .topLeading) {
                    if viewModel.pollDescription.isEmpty {
                        Text("Add more context...")
                            .font(.subheadline)
                            .foregroundStyle(OuestTheme.Colors.textSecondary.opacity(0.5))
                            .padding(.horizontal, OuestTheme.Spacing.sm + 4)
                            .padding(.vertical, OuestTheme.Spacing.sm + 8)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    // MARK: - Options Section

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.sm) {
            HStack(spacing: OuestTheme.Spacing.xs) {
                Image(systemName: "list.bullet")
                    .font(.subheadline)
                    .foregroundStyle(OuestTheme.Colors.brand)
                Text("Options")
                    .font(OuestTheme.Typography.sectionTitle)
            }

            ForEach(viewModel.optionTexts.indices, id: \.self) { index in
                HStack(spacing: OuestTheme.Spacing.sm) {
                    // Option number
                    Text("\(index + 1)")
                        .font(OuestTheme.Typography.micro)
                        .fontWeight(.bold)
                        .foregroundStyle(OuestTheme.Colors.brand)
                        .frame(width: 20, height: 20)
                        .background(OuestTheme.Colors.brand.opacity(0.12))
                        .clipShape(Circle())

                    OuestTextField(
                        text: $viewModel.optionTexts[index],
                        placeholder: "Option \(index + 1)"
                    )

                    // Remove button (only if > 2 options)
                    if viewModel.optionTexts.count > 2 {
                        Button {
                            HapticFeedback.light()
                            withAnimation(OuestTheme.Anim.quick) {
                                viewModel.removeOption(at: index)
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.red.opacity(0.7))
                        }
                    }
                }
            }

            // Add option button
            if viewModel.optionTexts.count < 10 {
                Button {
                    HapticFeedback.light()
                    withAnimation(OuestTheme.Anim.quick) {
                        viewModel.addOption()
                    }
                } label: {
                    HStack(spacing: OuestTheme.Spacing.sm) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(OuestTheme.Colors.brand)
                        Text("Add Option")
                            .font(.subheadline)
                            .foregroundStyle(OuestTheme.Colors.brand)
                    }
                    .padding(.vertical, OuestTheme.Spacing.sm)
                }
            }
        }
    }

    // MARK: - Settings Section

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.sm) {
            HStack(spacing: OuestTheme.Spacing.xs) {
                Image(systemName: "gearshape")
                    .font(.subheadline)
                    .foregroundStyle(OuestTheme.Colors.brand)
                Text("Settings")
                    .font(OuestTheme.Typography.sectionTitle)
            }

            Toggle(isOn: $viewModel.allowMultiple) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Allow multiple votes")
                        .font(.subheadline)
                    Text("Members can vote for more than one option")
                        .font(OuestTheme.Typography.micro)
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                }
            }
            .tint(OuestTheme.Colors.brand)
            .padding(OuestTheme.Spacing.md)
            .background(OuestTheme.Colors.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
        }
    }

    // MARK: - Save

    private func save() async {
        if await viewModel.createPoll() {
            HapticFeedback.success()
            dismiss()
        } else {
            HapticFeedback.error()
        }
    }
}
