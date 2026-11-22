import SwiftUI
import MapKit

struct CreatePollView: View {
    @Bindable var viewModel: PollsViewModel
    let trip: Trip
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showPlaceSearch = false
    @ScaledMetric(relativeTo: .body) private var wellSize: CGFloat = 36

    private var fieldShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: OuestTheme.Radius.md, style: .continuous)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: OuestTheme.Layout.sectionGap) {
                    kindSection
                    questionSection
                    switch viewModel.kind {
                    case .text: optionsSection
                    case .yesNo: yesNoPlaceSection
                    case .place: placesSection
                    }
                    settingsSection

                    if let formError = viewModel.formError {
                        Label(formError, systemImage: "exclamationmark.circle.fill")
                            .font(OuestTheme.Typography.caption)
                            .foregroundStyle(OuestTheme.Colors.errorInk)
                    }
                }
                .padding(.horizontal, OuestTheme.Layout.pageGutter)
                .padding(.vertical, OuestTheme.Spacing.lg)
                .animation(reduceMotion ? nil : OuestTheme.Anim.quick, value: viewModel.kind)
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
            .sheet(isPresented: $showPlaceSearch) {
                PlaceSearchSheet(viewModel: viewModel)
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(OuestTheme.Typography.sectionTitle)
            .foregroundStyle(OuestTheme.Colors.textPrimary)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Kind

    private var kindSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.sm) {
            Picker("Poll type", selection: $viewModel.kind) {
                ForEach(PollKind.allCases) { kind in
                    Text(kind.label).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.kind) { HapticFeedback.selection() }

            Text(kindHint)
                .font(OuestTheme.Typography.caption)
                .foregroundStyle(OuestTheme.Colors.textSecondary)
        }
    }

    private var kindHint: String {
        switch viewModel.kind {
        case .text: "The group chooses from options you type."
        case .yesNo: "The group answers yes or no."
        case .place: "The group chooses between real places. The winner can go into the itinerary."
        }
    }

    private var questionPlaceholder: String {
        switch viewModel.kind {
        case .text: "What should we do on Saturday?"
        case .yesNo: "Should we book the boat tour?"
        case .place: "Where should we eat tonight?"
        }
    }

    // MARK: - Question

    private var questionSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.sm) {
            sectionTitle("Question")

            OuestTextField(text: $viewModel.pollTitle, placeholder: questionPlaceholder)

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

    // MARK: - Places

    private var placesSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.sm) {
            sectionTitle("Places")

            ForEach(viewModel.places) { place in
                placeRow(place) {
                    withAnimation(reduceMotion ? nil : OuestTheme.Anim.quick) {
                        viewModel.removePlace(place)
                    }
                }
            }

            if viewModel.canAddPlace {
                addPlaceButton
            }

            if viewModel.places.count < 2 {
                Text("Add at least two places.")
                    .font(OuestTheme.Typography.caption)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
            }
        }
    }

    /// The one place a yes or no poll is about. Optional: plenty of yes or
    /// no questions are not about a place at all.
    private var yesNoPlaceSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.sm) {
            sectionTitle("Place")

            if let place = viewModel.yesNoPlace {
                placeRow(place) {
                    withAnimation(reduceMotion ? nil : OuestTheme.Anim.quick) {
                        viewModel.yesNoPlace = nil
                    }
                }
            } else {
                addPlaceButton
            }

            Text("Optional. If the group says yes, the place can go straight into the itinerary.")
                .font(OuestTheme.Typography.caption)
                .foregroundStyle(OuestTheme.Colors.textSecondary)
        }
    }

    private var addPlaceButton: some View {
        Button {
            HapticFeedback.light()
            showPlaceSearch = true
        } label: {
            Label("Add a place", systemImage: "plus.circle.fill")
                .font(OuestTheme.Typography.body)
                .fontWeight(.semibold)
                .foregroundStyle(OuestTheme.Colors.brandInk)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
    }

    private func placeRow(_ place: PollPlace, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: OuestTheme.Spacing.sm) {
            Image(systemName: place.category.icon)
                .font(OuestTheme.Typography.body)
                .foregroundStyle(OuestTheme.Colors.brandInk)
                .frame(width: wellSize, height: wellSize)
                .background(
                    OuestTheme.Colors.surface,
                    in: RoundedRectangle(cornerRadius: OuestTheme.Radius.sm, style: .continuous)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: OuestTheme.Spacing.xxs) {
                Text(place.name)
                    .font(OuestTheme.Typography.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(OuestTheme.Colors.textPrimary)
                if let address = place.address {
                    Text(address)
                        .font(OuestTheme.Typography.caption)
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            Button {
                HapticFeedback.light()
                onRemove()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(OuestTheme.Icon.control)
                    .foregroundStyle(OuestTheme.Colors.errorInk)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Remove \(place.name)")
        }
        .padding(.leading, OuestTheme.Spacing.md)
        .padding(.vertical, OuestTheme.Spacing.sm)
        .background(OuestTheme.Colors.fill, in: fieldShape)
    }

    // MARK: - Settings

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.sm) {
            sectionTitle("Settings")

            // Yes or no is one answer each by definition.
            if viewModel.kind != .yesNo {
                Toggle(isOn: $viewModel.allowMultiple) {
                    settingLabel("Allow multiple votes", detail: "Members can vote for more than one option")
                }
                .tint(OuestTheme.Colors.brandFill)
                .padding(OuestTheme.Spacing.md)
                .background(OuestTheme.Colors.fill, in: fieldShape)
            }

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

// MARK: - Place Search

/// Search for a place to put in a poll. The search leans towards the trip's
/// destination, so "pizza" finds pizza there.
private struct PlaceSearchSheet: View {
    @Bindable var viewModel: PollsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchTask: Task<Void, Never>?

    private var query: String {
        viewModel.placeQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            List(viewModel.placeResults, id: \.self) { item in
                resultRow(item)
                    .listRowBackground(OuestTheme.Colors.surface)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(OuestTheme.Colors.surface)
            .overlay {
                if viewModel.placeResults.isEmpty {
                    emptyState
                }
            }
            .navigationTitle("Add a place")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $viewModel.placeQuery,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Restaurants, sights, hotels"
            )
            .autocorrectionDisabled()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                }
            }
            .onChange(of: viewModel.placeQuery) {
                searchTask?.cancel()
                searchTask = Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    guard !Task.isCancelled else { return }
                    await viewModel.searchPlaces()
                }
            }
            .onDisappear {
                searchTask?.cancel()
                viewModel.clearPlaceSearch()
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if query.count < 2 {
            OuestEmptyState(
                symbol: "mappin.and.ellipse",
                title: "Find a place",
                message: "Search by name, or by what you're after, like ramen or rooftop bar."
            )
        } else if viewModel.isSearchingPlaces {
            ProgressView()
                .accessibilityLabel("Searching")
        } else {
            ContentUnavailableView.search(text: query)
        }
    }

    private func resultRow(_ item: MKMapItem) -> some View {
        let alreadyAdded = viewModel.hasPlace(item)

        return Button {
            HapticFeedback.selection()
            viewModel.choosePlace(item)
            dismiss()
        } label: {
            HStack(spacing: OuestTheme.Spacing.sm) {
                VStack(alignment: .leading, spacing: OuestTheme.Spacing.xxs) {
                    Text(item.name ?? "Unnamed place")
                        .font(OuestTheme.Typography.body)
                        .foregroundStyle(OuestTheme.Colors.textPrimary)
                    if let address = item.placemark.title {
                        Text(address)
                            .font(OuestTheme.Typography.caption)
                            .foregroundStyle(OuestTheme.Colors.textSecondary)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if alreadyAdded {
                    Text("Added")
                        .font(OuestTheme.Typography.caption)
                        .foregroundStyle(OuestTheme.Colors.textTertiary)
                }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .disabled(alreadyAdded)
    }
}
