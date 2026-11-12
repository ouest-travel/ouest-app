import SwiftUI

/// A searchable single-select country picker for profile nationality (ISO 3166-1 alpha-3 codes).
struct NationalityPickerView: View {
    @Binding var selectedCode: String
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""

    private var filteredCountries: [CountryHelper.Country] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return CountryHelper.allCountries }
        return CountryHelper.allCountries.filter {
            $0.name.lowercased().contains(query)
            || $0.code.lowercased().contains(query)
            || $0.alpha2.lowercased().contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List(filteredCountries) { country in
                Button {
                    HapticFeedback.selection()
                    selectedCode = country.code
                    dismiss()
                } label: {
                    HStack(spacing: OuestTheme.Spacing.md) {
                        Text(country.flag)
                            .font(.title2)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(country.name)
                                .font(.body)
                                .foregroundStyle(OuestTheme.Colors.textPrimary)
                            Text(country.code)
                                .font(OuestTheme.Typography.caption)
                                .foregroundStyle(OuestTheme.Colors.textSecondary)
                        }

                        Spacer()

                        if country.code == selectedCode {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(OuestTheme.Colors.brand)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .searchable(text: $searchText, prompt: "Search countries")
            .navigationTitle("Select Country")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// Inline button that opens the nationality picker sheet.
struct NationalityPickerField: View {
    @Binding var selectedCode: String
    @State private var showPicker = false

    var body: some View {
        Button {
            showPicker = true
        } label: {
            HStack(spacing: OuestTheme.Spacing.xs) {
                Image(systemName: "flag.fill")
                    .font(.body)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
                    .frame(width: 24)

                if selectedCode.isEmpty {
                    Text("Select country")
                        .font(.body)
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                } else {
                    Text(CountryHelper.displayName(for: selectedCode) ?? selectedCode)
                        .font(.body)
                        .foregroundStyle(OuestTheme.Colors.textPrimary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
            }
            .padding(.horizontal, OuestTheme.Spacing.md)
            .frame(height: 50)
            .background(OuestTheme.Colors.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.sm))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showPicker) {
            NationalityPickerView(selectedCode: $selectedCode)
        }
    }
}
