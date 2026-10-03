import SwiftUI

struct CountryPickerView: View {
    @Binding var selectedCodes: [String]
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private let countries = EntryRequirementService.allCountries()

    private var filteredCountries: [(code: String, name: String)] {
        if searchText.isEmpty { return countries }
        let query = searchText.lowercased()
        return countries.filter {
            $0.name.lowercased().contains(query) || $0.code.lowercased().contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredCountries, id: \.code) { country in
                    Button {
                        HapticFeedback.selection()
                        toggleSelection(country.code)
                    } label: {
                        HStack(spacing: OuestTheme.Spacing.md) {
                            Text(EntryRequirementService.flag(for: country.code))
                                .font(.title2)

                            Text(country.name)
                                .font(.body)
                                .foregroundStyle(OuestTheme.Colors.textPrimary)

                            Spacer()

                            if selectedCodes.contains(country.code) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(OuestTheme.Colors.brand)
                                    .font(.title3)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .searchable(text: $searchText, prompt: "Search countries")
            .navigationTitle("Select Countries")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func toggleSelection(_ code: String) {
        if let index = selectedCodes.firstIndex(of: code) {
            selectedCodes.remove(at: index)
        } else {
            selectedCodes.append(code)
        }
    }
}

#Preview {
    CountryPickerView(selectedCodes: .constant(["US", "FR"]))
}
