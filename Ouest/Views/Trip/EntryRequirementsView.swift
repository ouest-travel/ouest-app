import SwiftUI

struct EntryRequirementsView: View {
    let trip: Trip
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var viewModel = EntryRequirementsViewModel()
    @State private var showEditProfile = false
    @State private var showCountryPicker = false
    @State private var contentAppeared = false

    var body: some View {
        ScrollView {
            VStack(spacing: OuestTheme.Spacing.lg) {
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.needsNationality {
                    needsNationalityView
                } else if viewModel.needsCountryCodes {
                    needsCountryCodesView
                } else {
                    resultsView
                }
            }
            .padding(.horizontal, OuestTheme.Spacing.xl)
            .padding(.top, OuestTheme.Spacing.md)
            .padding(.bottom, OuestTheme.Spacing.xxxl)
        }
        .navigationTitle("Entry Requirements")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadRequirements(
                for: trip,
                userNationality: authViewModel.currentUser?.nationality
            )
            withAnimation(OuestTheme.Anim.smooth) {
                contentAppeared = true
            }
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView()
                .environment(authViewModel)
                .onDisappear {
                    Task {
                        await viewModel.loadRequirements(
                            for: trip,
                            userNationality: authViewModel.currentUser?.nationality
                        )
                    }
                }
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: OuestTheme.Spacing.xl) {
            ForEach(0..<(trip.countryCodes?.count ?? 2), id: \.self) { _ in
                SkeletonView(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.lg))
            }
        }
    }

    // MARK: - Results

    private var resultsView: some View {
        VStack(spacing: OuestTheme.Spacing.lg) {
            // Passport header
            if let passport = viewModel.passportCountry {
                passportHeader(passport)
                    .fadeSlideIn(isVisible: contentAppeared, delay: 0)
            }

            // Requirement cards
            ForEach(Array(viewModel.results.enumerated()), id: \.element.id) { index, result in
                if result.isSuccess, let data = result.response {
                    requirementCard(data)
                        .fadeSlideIn(isVisible: contentAppeared, delay: Double(index + 1) * 0.08)
                } else {
                    errorCard(result)
                        .fadeSlideIn(isVisible: contentAppeared, delay: Double(index + 1) * 0.08)
                }
            }
        }
    }

    // MARK: - Passport Header

    private func passportHeader(_ code: String) -> some View {
        HStack(spacing: OuestTheme.Spacing.md) {
            Text(EntryRequirementService.flag(for: code))
                .font(.largeTitle)

            VStack(alignment: .leading, spacing: OuestTheme.Spacing.xxs) {
                Text("Your Passport")
                    .font(OuestTheme.Typography.caption)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
                Text(EntryRequirementService.countryName(for: code))
                    .font(.headline)
            }

            Spacer()
        }
        .padding(OuestTheme.Spacing.lg)
        .background(OuestTheme.Colors.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.lg))
    }

    // MARK: - Requirement Card

    private func requirementCard(_ data: VisaCheckData) -> some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.md) {
            // Destination header
            HStack(spacing: OuestTheme.Spacing.md) {
                Text(EntryRequirementService.flag(for: data.destination.code))
                    .font(.title)

                VStack(alignment: .leading, spacing: OuestTheme.Spacing.xxs) {
                    Text(data.destination.name)
                        .font(.headline)
                    if let continent = data.destination.continent {
                        Text(continent)
                            .font(OuestTheme.Typography.caption)
                            .foregroundStyle(OuestTheme.Colors.textSecondary)
                    }
                }

                Spacer()
            }

            Divider()

            // Primary visa rule
            if let rule = data.visaRules.primaryRule {
                visaRuleBadge(rule, isPrimary: true)
            }

            // Secondary visa rule (e.g. eVisa option)
            if let rule = data.visaRules.secondaryRule {
                visaRuleBadge(rule, isPrimary: false)
            }

            // Mandatory registration
            if let registration = data.mandatoryRegistration {
                registrationBanner(registration)
            }

            // Passport validity
            if let validity = data.destination.passportValidity, !validity.isEmpty {
                HStack(spacing: OuestTheme.Spacing.sm) {
                    Image(systemName: "doc.text.fill")
                        .font(.caption)
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                    Text("Passport validity: \(validity)")
                        .font(OuestTheme.Typography.caption)
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                }
            }

            // Quick info chips
            quickInfoRow(data.destination)

            // Embassy link
            if let embassyUrl = data.destination.embassyUrl, let url = URL(string: embassyUrl) {
                Link(destination: url) {
                    HStack(spacing: OuestTheme.Spacing.sm) {
                        Image(systemName: "building.columns.fill")
                        Text("Embassy Information")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.subheadline)
                    .foregroundStyle(OuestTheme.Colors.brand)
                    .padding(OuestTheme.Spacing.md)
                    .background(OuestTheme.Colors.brandLight)
                    .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
                }
            }
        }
        .padding(OuestTheme.Spacing.lg)
        .background(OuestTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.lg))
        .shadow(OuestTheme.Shadow.md)
    }

    // MARK: - Visa Rule Badge

    private func visaRuleBadge(_ rule: VisaRule, isPrimary: Bool) -> some View {
        let visaColor = VisaColor(apiColor: rule.color)

        return HStack(spacing: OuestTheme.Spacing.md) {
            Image(systemName: visaColor.icon)
                .font(isPrimary ? .title2 : .body)
                .foregroundStyle(visaColor.swiftUIColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: OuestTheme.Spacing.xxs) {
                HStack(spacing: OuestTheme.Spacing.sm) {
                    Text(rule.name)
                        .font(isPrimary ? .subheadline : OuestTheme.Typography.caption)
                        .fontWeight(isPrimary ? .semibold : .medium)

                    if let duration = rule.duration {
                        Text(duration)
                            .font(OuestTheme.Typography.micro)
                            .fontWeight(.medium)
                            .padding(.horizontal, OuestTheme.Spacing.sm)
                            .padding(.vertical, OuestTheme.Spacing.xxs)
                            .background(visaColor.swiftUIColor.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }

                if !isPrimary {
                    Text("Alternative option")
                        .font(OuestTheme.Typography.micro)
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                }
            }

            Spacer()

            // eVisa / link button
            if let linkStr = rule.link, let url = URL(string: linkStr) {
                Link(destination: url) {
                    Text("Apply")
                        .font(OuestTheme.Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, OuestTheme.Spacing.md)
                        .padding(.vertical, OuestTheme.Spacing.sm)
                        .background(visaColor.swiftUIColor)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(OuestTheme.Spacing.md)
        .background(visaColor.swiftUIColor.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
    }

    // MARK: - Registration Banner

    private func registrationBanner(_ registration: MandatoryRegistration) -> some View {
        HStack(spacing: OuestTheme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: OuestTheme.Spacing.xxs) {
                Text(registration.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Required before travel")
                    .font(OuestTheme.Typography.micro)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
            }

            Spacer()

            if let linkStr = registration.link, let url = URL(string: linkStr) {
                Link(destination: url) {
                    Text("Register")
                        .font(OuestTheme.Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, OuestTheme.Spacing.md)
                        .padding(.vertical, OuestTheme.Spacing.sm)
                        .background(.orange)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(OuestTheme.Spacing.md)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
    }

    // MARK: - Quick Info Row

    private func quickInfoRow(_ dest: DestinationInfo) -> some View {
        let chips: [(icon: String, text: String)] = [
            dest.capital.map { ("building.2.fill", $0) },
            dest.currency.map { ("dollarsign.circle", $0) },
            dest.timezone.map { ("clock.fill", "UTC\($0)") },
            dest.phoneCode.map { ("phone.fill", $0) },
        ].compactMap { $0 }

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: OuestTheme.Spacing.sm) {
                ForEach(chips, id: \.text) { chip in
                    HStack(spacing: OuestTheme.Spacing.xs) {
                        Image(systemName: chip.icon)
                            .font(.system(size: 10))
                        Text(chip.text)
                            .font(OuestTheme.Typography.micro)
                    }
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
                    .padding(.horizontal, OuestTheme.Spacing.sm)
                    .padding(.vertical, OuestTheme.Spacing.xs)
                    .background(OuestTheme.Colors.surfaceSecondary)
                    .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Error Card

    private func errorCard(_ result: EntryRequirementResult) -> some View {
        VStack(spacing: OuestTheme.Spacing.md) {
            HStack(spacing: OuestTheme.Spacing.md) {
                Text(EntryRequirementService.flag(for: result.destinationCode))
                    .font(.title)
                VStack(alignment: .leading) {
                    Text(result.destinationName)
                        .font(.headline)
                    Text(result.error ?? "Unknown error")
                        .font(OuestTheme.Typography.caption)
                        .foregroundStyle(OuestTheme.Colors.error)
                }
                Spacer()
            }

            Button {
                Task {
                    await viewModel.loadRequirements(
                        for: trip,
                        userNationality: authViewModel.currentUser?.nationality
                    )
                }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(OuestTheme.Colors.brand)
            }
        }
        .padding(OuestTheme.Spacing.lg)
        .background(OuestTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.lg))
        .shadow(OuestTheme.Shadow.md)
    }

    // MARK: - Needs Nationality

    private var needsNationalityView: some View {
        VStack(spacing: OuestTheme.Spacing.xxl) {
            Spacer(minLength: OuestTheme.Spacing.xxxl)

            VStack(spacing: OuestTheme.Spacing.md) {
                Image(systemName: "person.text.rectangle")
                    .font(.system(size: 48))
                    .foregroundStyle(OuestTheme.Colors.brandGradient)

                Text("Set Your Nationality")
                    .font(OuestTheme.Typography.screenTitle)

                Text("We need your passport country to check visa requirements for your destinations.")
                    .font(.subheadline)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            OuestButton(title: "Edit Profile") {
                showEditProfile = true
            }
            .frame(width: 200)

            Spacer()
        }
        .padding(OuestTheme.Spacing.xl)
    }

    // MARK: - Needs Country Codes

    private var needsCountryCodesView: some View {
        VStack(spacing: OuestTheme.Spacing.xxl) {
            Spacer(minLength: OuestTheme.Spacing.xxxl)

            VStack(spacing: OuestTheme.Spacing.md) {
                Image(systemName: "globe.americas.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(OuestTheme.Colors.brandGradient)

                Text("Add Destinations")
                    .font(OuestTheme.Typography.screenTitle)

                Text("Add destination countries to your trip to see entry requirements.")
                    .font(.subheadline)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            OuestButton(title: "Edit Trip") {
                // Navigate back — the user can edit the trip from TripDetailView
            }
            .frame(width: 200)

            Spacer()
        }
        .padding(OuestTheme.Spacing.xl)
    }
}

#Preview {
    NavigationStack {
        EntryRequirementsView(
            trip: Trip(
                id: UUID(), createdBy: UUID(), title: "Test Trip",
                destination: "Paris", status: .planning, isPublic: false,
                countryCodes: ["FR", "JP"], createdAt: nil
            )
        )
        .environment(AuthViewModel())
    }
}
