//
//  CurrencySelectionView.swift
//  MoneyTracker
//
//  Created on 2026-01-06.
//

import SwiftUI
import SwiftData

struct CurrencySelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appSettings) var appSettings

    @Query(sort: \CurrencyRecord.code) private var allCurrencies: [CurrencyRecord]
    @Query private var allExchangeRates: [ExchangeRate]

    @Binding var selectedCurrency: CurrencyRecord?
    @State private var searchText = ""
    @State private var ratesCache: [String: Decimal] = [:]

    // MARK: - Computed Properties

    var frequentCurrencies: [CurrencyRecord] {
        allCurrencies.filter { $0.isFrequent }
            .sorted { $0.usageCount > $1.usageCount }
    }

    var recentCurrencies: [CurrencyRecord] {
        allCurrencies.filter { $0.isRecent && !$0.isFrequent }
            .sorted { ($0.lastUsedDate ?? .distantPast) > ($1.lastUsedDate ?? .distantPast) }
    }

    var alphabeticalSections: [(String, [CurrencyRecord])] {
        let filtered = filteredCurrencies
        let grouped = Dictionary(grouping: filtered) { currency in
            String(currency.code.prefix(1))
        }
        return grouped.sorted { $0.key < $1.key }.map { ($0.key, $0.value.sorted { $0.code < $1.code }) }
    }

    var filteredCurrencies: [CurrencyRecord] {
        let baseCurrencies: [CurrencyRecord]

        if searchText.isEmpty {
            baseCurrencies = allCurrencies.filter { !$0.isFrequent && !$0.isRecent }
        } else {
            baseCurrencies = allCurrencies.filter {
                $0.code.localizedCaseInsensitiveContains(searchText) ||
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }

        return baseCurrencies
    }

    var sectionLetters: [String] {
        alphabeticalSections.map { $0.0 }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .trailing) {
                // Main list
                ScrollViewReader { proxy in
                    List {
                        // Frequent section
                        if !frequentCurrencies.isEmpty && searchText.isEmpty {
                            Section {
                                ForEach(frequentCurrencies) { currency in
                                    currencyRow(currency)
                                }
                            } header: {
                                HStack {
                                    Image(systemName: "star.fill")
                                        .foregroundStyle(.yellow)
                                    Text("Più Usate")
                                }
                            }
                        }

                        // Recent section
                        if !recentCurrencies.isEmpty && searchText.isEmpty {
                            Section {
                                ForEach(recentCurrencies) { currency in
                                    currencyRow(currency)
                                }
                            } header: {
                                HStack {
                                    Image(systemName: "clock.fill")
                                        .foregroundStyle(.blue)
                                    Text("Recenti")
                                }
                            }
                        }

                        // Alphabetical sections
                        ForEach(alphabeticalSections, id: \.0) { letter, currencies in
                            Section {
                                ForEach(currencies) { currency in
                                    currencyRow(currency)
                                }
                            } header: {
                                Text(letter)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                    .id(letter)  // For scrolling
                            }
                        }
                    }
                    .searchable(text: $searchText, prompt: "Cerca valuta")
                    .listStyle(.plain)
                }

                // A-Z Index (iOS Contacts style)
                if searchText.isEmpty && !sectionLetters.isEmpty {
                    AlphabeticalIndex(letters: sectionLetters)
                        .padding(.trailing, 8)
                }
            }
            .navigationTitle("Seleziona Valuta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                buildRatesCache()
            }
        }
    }

    // MARK: - Cache Building

    private func buildRatesCache() {
        var cache: [String: Decimal] = [:]
        for rate in allExchangeRates {
            if let from = rate.fromCurrency?.code,
               let to = rate.toCurrency?.code {
                cache["\(from)-\(to)"] = rate.rate
            }
        }
        ratesCache = cache
    }

    // MARK: - Currency Row

    @ViewBuilder
    private func currencyRow(_ currency: CurrencyRecord) -> some View {
        Button {
            selectCurrency(currency)
        } label: {
            HStack(spacing: 12) {
                // Flag
                Text(currency.flagEmoji)
                    .font(.largeTitle)

                // Code and Name
                VStack(alignment: .leading, spacing: 4) {
                    Text(currency.code)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(currency.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Exchange rate (if available and not selected currency)
                if let preferredCurrency = getPreferredCurrency(),
                   currency.code != preferredCurrency.code {
                    let key = "\(preferredCurrency.code)-\(currency.code)"
                    if let rate = ratesCache[key] {
                        Text(formatRate(rate))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                }

                // Checkmark
                if selectedCurrency?.code == currency.code {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                }
            }
        }
    }

    // MARK: - Actions

    private func selectCurrency(_ currency: CurrencyRecord) {
        // Update usage tracking
        CurrencyService.shared.recordUsage(of: currency, context: modelContext)

        selectedCurrency = currency
        dismiss()
    }

    // MARK: - Helpers

    private func getPreferredCurrency() -> CurrencyRecord? {
        // Try to get from AppSettings or fallback to EUR
        let preferredCode = appSettings.preferredCurrencyEnum.rawValue
        return allCurrencies.first { $0.code == preferredCode }
    }

    private func formatRate(_ rate: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 4
        return formatter.string(from: rate as NSDecimalNumber) ?? "0.00"
    }
}

// MARK: - Alphabetical Index

struct AlphabeticalIndex: View {
    let letters: [String]
    @State private var selectedLetter: String?

    var body: some View {
        VStack(spacing: 2) {
            ForEach(letters, id: \.self) { letter in
                Text(letter)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(selectedLetter == letter ? .blue : .secondary)
                    .frame(width: 20, height: 16)
                    .onTapGesture {
                        scrollTo(letter: letter)
                    }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }

    private func scrollTo(letter: String) {
        selectedLetter = letter

        // Visual feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        // TODO: Implement actual scroll
        // This requires ScrollViewReader which is already in parent

        // Reset selection after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            selectedLetter = nil
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CurrencySelectionView(selectedCurrency: .constant(nil))
            .environment(\.appSettings, AppSettings.shared)
            .modelContainer(for: [CurrencyRecord.self, ExchangeRate.self])
    }
}
