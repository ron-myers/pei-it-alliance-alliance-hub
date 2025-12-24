//
//  CountrySelectionView.swift
//  bragboard
//
//  Full-screen country selection view for Countries Served widget
//  Similar to calendar view on Apple TV
//

#if os(iOS)
import SwiftUI
import SwiftData

struct CountrySelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var widget: Widget
    @State private var searchText = ""

    private let countryService = CountryDataService.shared

    // Filter countries based on search text
    private var filteredCountries: [Country] {
        if searchText.isEmpty {
            return countryService.sortedCountries
        } else {
            return countryService.sortedCountries.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("\((widget.configuration?.countriesServed.count ?? 1)) countries selected")
                        .font(.headline)
                        .foregroundColor(.blue)
                }

                Section("All Countries") {
                    ForEach(filteredCountries) { country in
                        Button {
                            toggleCountry(country)
                        } label: {
                            HStack {
                                // Country flag emoji (if available)
                                Text(countryFlag(for: country.id))
                                    .font(.title2)
                                    .frame(width: 40)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(country.name)
                                        .font(.body)
                                        .foregroundColor(.primary)

                                    // Show default indicator
                                    if country.id == "CA" {
                                        Text("Default location: Charlottetown, PEI")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer()

                                // Checkmark if selected
                                if (widget.configuration?.countriesServed ?? ["CA"]).contains(country.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.title3)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Countries Served")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search countries")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            selectAllCountries()
                        } label: {
                            Label("Select All", systemImage: "checkmark.circle")
                        }

                        Button {
                            clearAllCountries()
                        } label: {
                            Label("Clear All", systemImage: "xmark.circle")
                        }

                        Button {
                            resetToDefault()
                        } label: {
                            Label("Reset to Default", systemImage: "arrow.counterclockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }

    // MARK: - Helper Functions

    private func toggleCountry(_ country: Country) {
        ensureConfiguration()

        var countries = widget.configuration?.countriesServed ?? ["CA"]

        if let index = countries.firstIndex(of: country.id) {
            countries.remove(at: index)
        } else {
            countries.append(country.id)
        }

        widget.configuration?.countriesServed = countries
    }

    private func selectAllCountries() {
        ensureConfiguration()
        widget.configuration?.countriesServed = countryService.allCountries.map { $0.id }
    }

    private func clearAllCountries() {
        ensureConfiguration()
        widget.configuration?.countriesServed = []
    }

    private func resetToDefault() {
        ensureConfiguration()
        widget.configuration?.countriesServed = ["CA"]
    }

    private func ensureConfiguration() {
        if widget.configuration == nil {
            widget.configuration = WidgetConfiguration()
        }
    }

    // Get country flag emoji from country code
    private func countryFlag(for countryCode: String) -> String {
        let base: UInt32 = 127397
        var emoji = ""
        for scalar in countryCode.uppercased().unicodeScalars {
            if let scalarValue = UnicodeScalar(base + scalar.value) {
                emoji.append(String(scalarValue))
            }
        }
        return emoji.isEmpty ? "🌍" : emoji
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Widget.self, configurations: config)

    let widget = Widget(type: .countriesServed)
    container.mainContext.insert(widget)

    return CountrySelectionView(widget: widget)
        .modelContainer(container)
}
#endif
