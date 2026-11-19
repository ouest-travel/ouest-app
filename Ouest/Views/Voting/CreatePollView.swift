import SwiftUI

struct CreatePollView: View {
    @Bindable var viewModel: PollsViewModel
    let trip: Trip
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var fieldShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: OuestTheme.Radius.md, style: .continuous)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: OuestTheme.Layout.sectionGap) {
                    questionSection
                    optionsSection
                    settingsSection

                    if let formError = viewModel.formError {
                        Label(formError, systemImage: "exclamationmark.circle.fill")
                            .font(OuestTheme.Typography.caption)
                            .foregroundStyle(OuestTheme.Colors.errorInk)
                    }
                }
                .padding(.horizontal, OuestTheme.Layout.pageGutter)
                .padding(.vertical, OuestTheme.Spacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            // A sheet is a surface, and the fields are `fill` so they read
            // against it. On `background` the two are almost the same colour.
            .background(OuestTheme.Colors.surface)
            .navigationTitle("New poll")
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
                    .foregroundStyle(OuestTheme.Colors.brandInk)
                    .disabled(!viewModel.isFormValid || viewModel.isSaving)
                    .opacity(viewModel.isFormValid && !viewModel.isSaving ? 1 : 0.4)
                }
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(OuestTheme.Typography.sectionTitle)
            .foregroundStyle(OuestTheme.Colors.textPrimary)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Question

    private var questionSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.sm) {
            sectionTitle("Question")

            OuestTextField(text: $viewModel.pollTitle, placeholder: "Where should we eat tonight?")

            TextField("Add context (optional)", text: $viewModel.pollDescription, axis: .vertical)
                .lineLimit(2...5)
                .font(OuestTheme.Typography.body)
                .padding(.horizontal, OuestTheme.Spacing.lg)
                .padding(.vertical, OuestTheme.Spacing.md)
                .background(OuestTheme.Colors.fill, in: fieldShape)
        }
    }

    // MARK: - Options

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.sm) {
            sectionTitle("Options")

            ForEach(viewModel.optionTexts.indices, id: \.self) { index in
                HStack(spacing: OuestTheme.Spacing.sm) {
                    OuestTextField(
                        text: $viewModel.optionTexts[index],
                        placeholder: "Option \(index + 1)"
                    )

                    // Only once there are more than the two a poll needs.
                    if viewModel.optionTexts.count > 2 {
                        Button {
                            HapticFeedback.light()
                            withAnimation(reduceMotion ? nil : OuestTheme.Anim.quick) {
                                viewModel.removeOption(at: index)
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(OuestTheme.Icon.control)
                                .foregroundStyle(OuestTheme.Colors.errorInk)
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Remove option \(index + 1)")
                    }
                }
            }

            if viewModel.optionTexts.count < 10 {
                Button {
                    HapticFeedback.light()
                    withAnimation(reduceMotion ? nil : OuestTheme.Anim.quick) {
                        viewModel.addOption()
                    }
                } label: {
                    Label("Add option", systemImage: "plus.circle.fill")
                        .font(OuestTheme.Typography.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(OuestTheme.Colors.brandInk)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
            }
        }
    }

    // MARK: - Settings

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.sm) {
            sectionTitle("Settings")

            Toggle(isOn: $viewModel.allowMultiple) {
                settingLabel("Allow multiple votes", detail: "Members can vote for more than one option")
            }
            .tint(OuestTheme.Colors.brandFill)
            .padding(OuestTheme.Spacing.md)
            .background(OuestTheme.Colors.fill, in: fieldShape)

            // Side by side there is no room for the choice at the largest
            // text sizes, so it drops under its label.
            let stacked = dynamicTypeSize.isAccessibilitySize
            let row = stacked
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: OuestTheme.Spacing.sm))
                : AnyLayout(HStackLayout(spacing: OuestTheme.Spacing.sm))

            row {
                settingLabel(
                    "Voting closes",
                    detail: viewModel.deadline == .none
                        ? "Stays open until someone closes it"
                        : "Anyone who hasn't voted gets a reminder"
                )

                if !stacked {
                    Spacer(minLength: OuestTheme.Spacing.sm)
                }

                Picker("Voting closes", selection: $viewModel.deadline) {
                    ForEach(PollDeadline.allCases) { deadline in
                        Text(deadline.label).tag(deadline)
                    }
                }
                .pickerStyle(.menu)
                .tint(OuestTheme.Colors.brandInk)
                .onChange(of: viewModel.deadline) { HapticFeedback.selection() }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(OuestTheme.Spacing.md)
            .background(OuestTheme.Colors.fill, in: fieldShape)
        }
    }

    private func settingLabel(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.xxs) {
            Text(title)
                .font(OuestTheme.Typography.body)
                .foregroundStyle(OuestTheme.Colors.textPrimary)
            Text(detail)
                .font(OuestTheme.Typography.caption)
                .foregroundStyle(OuestTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
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
