//
//  ExchangeRatesView.swift
//  MoneyTracker
//
//  Created on 2026-01-01.
//

import SwiftUI
import SwiftData


struct ExchangeRatesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allCurrencies: [CurrencyRecord]

    @State private var selectedFromCurrency: Currency = .EUR  // DEPRECATED
    @State private var selectedToCurrency: Currency = .USD   // DEPRECATED
    @State private var selectedFromCurrencyRecord: CurrencyRecord?
    @State private var selectedToCurrencyRecord: CurrencyRecord?
    @State private var customRate = ""
    @State private var showingUpdateAlert = false

    // Funzione helper per ottenere il tasso (query diretta solo quando serve)
    func getRate(from: CurrencyRecord, to: CurrencyRecord) -> Decimal? {
        CurrencyService.shared.getExchangeRate(from: from, to: to, context: modelContext)
    }

    var currentRate: Decimal? {
        guard let from = selectedFromCurrencyRecord, let to = selectedToCurrencyRecord else { return nil }
        return getRate(from: from, to: to)
    }

    var body: some View {
        Form(content: {
            Section {
                NavigationLink {
                    CurrencySelectionView(selectedCurrency: $selectedFromCurrencyRecord)
                } label: {
                    HStack {
                        Text("Da")
                            .foregroundStyle(.primary)

                        Spacer()

                        if let currency = selectedFromCurrencyRecord {
                            HStack(spacing: 8) {
                                Text(currency.flagEmoji)
                                Text(currency.code)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text("Seleziona")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                NavigationLink {
                    CurrencySelectionView(selectedCurrency: $selectedToCurrencyRecord)
                } label: {
                    HStack {
                        Text("A")
                            .foregroundStyle(.primary)

                        Spacer()

                        if let currency = selectedToCurrencyRecord {
                            HStack(spacing: 8) {
                                Text(currency.flagEmoji)
                                Text(currency.code)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text("Seleziona")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Seleziona Valute")
            } footer: {
                if let from = selectedFromCurrencyRecord, let to = selectedToCurrencyRecord {
                    Text("\(from.name) → \(to.name)")
                }
            }

            Section {
                if let from = selectedFromCurrencyRecord, let to = selectedToCurrencyRecord {
                    if from.code == to.code {
                        Text("Le valute devono essere diverse")
                            .foregroundStyle(.secondary)
                    } else {
                        HStack {
                            Text("1 \(from.code)")
                            Spacer()
                            if let rate = currentRate {
                                Text("= \(formatRate(rate)) \(to.code)")
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Non disponibile")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } else {
                    Text("Seleziona due valute")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Tasso di Cambio Attuale")
            }

            Section {
                HStack {
                    Text("Nuovo Tasso")
                    Spacer()
                    TextField("0.00", text: $customRate)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }

                Button {
                    updateRate()
                } label: {
                    HStack {
                        Spacer()
                        Text("Aggiorna Tasso di Cambio")
                        Spacer()
                    }
                }
                .disabled(customRate.isEmpty || selectedFromCurrencyRecord == nil || selectedToCurrencyRecord == nil || selectedFromCurrencyRecord?.code == selectedToCurrencyRecord?.code)
            } header: {
                Text("Aggiorna Tasso")
            } footer: {
                Text("Inserisci il tasso di cambio personalizzato. Ad esempio, se 1 EUR = 1.10 USD, inserisci 1.10")
            }

            // RIMOSSO: Lista completa dei tassi (troppo lenta con 140+ valute)
            // Gli utenti possono vedere i tassi nella schermata di selezione valuta
        })
        .navigationTitle("Tassi di Cambio")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Tasso Aggiornato", isPresented: $showingUpdateAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Il tasso di cambio è stato aggiornato con successo")
        }
        .onAppear {
            // Initialize with EUR and USD if not set
            if selectedFromCurrencyRecord == nil {
                selectedFromCurrencyRecord = allCurrencies.first { $0.code == "EUR" }
            }
            if selectedToCurrencyRecord == nil {
                selectedToCurrencyRecord = allCurrencies.first { $0.code == "USD" }
            }
        }
    }

    private func formatRate(_ rate: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 4
        return formatter.string(from: rate as NSDecimalNumber) ?? "0.00"
    }

    private func updateRate() {
        guard let rate = Decimal(string: customRate.replacingOccurrences(of: ",", with: ".")),
              let from = selectedFromCurrencyRecord,
              let to = selectedToCurrencyRecord else {
            return
        }

        CurrencyService.shared.updateExchangeRate(
            from: from,
            to: to,
            rate: rate,
            source: .manual,
            context: modelContext
        )

        customRate = ""
        showingUpdateAlert = true
    }
}

#Preview {
    NavigationStack {
        ExchangeRatesView()
    }
}
