//
//  ExchangeRatesView.swift
//  MoneyTracker
//
//  Created on 2026-01-01.
//

import SwiftUI

struct ExchangeRatesView: View {
    @State private var selectedFromCurrency: Currency = .EUR
    @State private var selectedToCurrency: Currency = .USD
    @State private var customRate = ""
    @State private var showingUpdateAlert = false

    var currentRate: Decimal? {
        CurrencyConverter.shared.getExchangeRate(from: selectedFromCurrency, to: selectedToCurrency)
    }

    var body: some View {
        Form(content: {
            Section {
                Picker("Da", selection: $selectedFromCurrency) {
                    ForEach(Currency.allCases, id: \.self) { currency in
                        Text(currency.displayName)
                            .tag(currency)
                    }
                }

                Picker("A", selection: $selectedToCurrency) {
                    ForEach(Currency.allCases, id: \.self) { currency in
                        Text(currency.displayName)
                            .tag(currency)
                    }
                }
            } header: {
                Text("Seleziona Valute")
            } footer: {
                Text("\(selectedFromCurrency.fullName) → \(selectedToCurrency.fullName)")
            }

            Section {
                if selectedFromCurrency == selectedToCurrency {
                    Text("Le valute devono essere diverse")
                        .foregroundStyle(.secondary)
                } else {
                    HStack {
                        Text("1 \(selectedFromCurrency.rawValue)")
                        Spacer()
                        if let rate = currentRate {
                            Text("= \(formatRate(rate)) \(selectedToCurrency.rawValue)")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Non disponibile")
                                .foregroundStyle(.secondary)
                        }
                    }
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
                .disabled(customRate.isEmpty || selectedFromCurrency == selectedToCurrency)
            } header: {
                Text("Aggiorna Tasso")
            } footer: {
                Text("Inserisci il tasso di cambio personalizzato. Ad esempio, se 1 EUR = 1.10 USD, inserisci 1.10")
            }

            Section {
                ForEach(Currency.allCases, id: \.self) { currency in
                    if currency != selectedFromCurrency {
                        HStack {
                            HStack(spacing: 8) {
                                Text(currency.flag)
                                Text(currency.rawValue)
                            }

                            Spacer()

                            if let rate = CurrencyConverter.shared.getExchangeRate(from: selectedFromCurrency, to: currency) {
                                Text(formatRate(rate))
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("N/A")
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            } header: {
                Text("1 \(selectedFromCurrency.rawValue) =")
            }
        })
        .navigationTitle("Tassi di Cambio")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Tasso Aggiornato", isPresented: $showingUpdateAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Il tasso di cambio è stato aggiornato con successo")
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
        guard let rate = Decimal(string: customRate.replacingOccurrences(of: ",", with: ".")) else {
            return
        }

        CurrencyConverter.shared.updateExchangeRate(
            from: selectedFromCurrency,
            to: selectedToCurrency,
            rate: rate
        )

        if selectedFromCurrency != selectedToCurrency, rate != 0 {
            let inverseRate = 1 / rate
            CurrencyConverter.shared.updateExchangeRate(
                from: selectedToCurrency,
                to: selectedFromCurrency,
                rate: inverseRate
            )
        }

        customRate = ""
        showingUpdateAlert = true
    }
}

#Preview {
    NavigationStack {
        ExchangeRatesView()
    }
}
