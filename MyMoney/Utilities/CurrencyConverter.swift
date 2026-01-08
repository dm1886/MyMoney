//
//  CurrencyConverter.swift
//  MoneyTracker
//
//  Created on 2026-01-01.
//

import Foundation

@Observable
class CurrencyConverter {
    static let shared = CurrencyConverter()

    // Questa proprietà notifica SwiftUI quando i tassi cambiano
    var lastUpdateTimestamp: Date = Date()

    private init() {
        loadSavedRates()
        // Se non ci sono tassi salvati, inizializza con i tassi predefiniti
        if exchangeRates.isEmpty {
            resetToDefaultRates()
        }
    }

    private var exchangeRates: [Currency: [Currency: Decimal]] = [:]

    func convert(amount: Decimal, from: Currency, to: Currency) -> Decimal {
        if from == to {
            return amount
        }

        guard let rate = exchangeRates[from]?[to] else {
            return amount
        }

        return amount * rate
    }

    func updateExchangeRate(from: Currency, to: Currency, rate: Decimal, autoSave: Bool = true) {
        if exchangeRates[from] == nil {
            exchangeRates[from] = [:]
        }
        exchangeRates[from]?[to] = rate
        if autoSave {
            saveRates()
        }
    }

    // Metodo per notificare le view dopo aggiornamenti batch
    func saveAndNotify() {
        saveRates()
    }

    func getExchangeRate(from: Currency, to: Currency) -> Decimal? {
        return exchangeRates[from]?[to]
    }

    func getAllRates() -> [Currency: [Currency: Decimal]] {
        return exchangeRates
    }

    func replaceAllRates(with newRates: [Currency: [Currency: Decimal]]) {
        exchangeRates = newRates
        saveRates()
    }

    private func saveRates() {
        var ratesDict: [String: [String: String]] = [:]

        for (fromCurrency, toRates) in exchangeRates {
            var innerDict: [String: String] = [:]
            for (toCurrency, rate) in toRates {
                innerDict[toCurrency.rawValue] = "\(rate)"
            }
            ratesDict[fromCurrency.rawValue] = innerDict
        }

        UserDefaults.standard.set(ratesDict, forKey: "exchangeRates")
        let now = Date()
        UserDefaults.standard.set(now, forKey: "lastRateUpdate")

        // Aggiorna il timestamp per notificare SwiftUI
        DispatchQueue.main.async {
            self.lastUpdateTimestamp = now
        }

        print("💾 [CurrencyConverter] Saved rates to UserDefaults. Total currencies: \(ratesDict.count)")
        print("🔔 [CurrencyConverter] Notified SwiftUI views to update")
    }

    private func loadSavedRates() {
        guard let savedRatesDict = UserDefaults.standard.dictionary(forKey: "exchangeRates") as? [String: [String: String]] else {
            print("📂 [CurrencyConverter] No saved rates found in UserDefaults")
            return
        }

        var loadedRates: [Currency: [Currency: Decimal]] = [:]

        for (fromKey, toRates) in savedRatesDict {
            guard let fromCurrency = Currency(rawValue: fromKey) else { continue }

            var innerRates: [Currency: Decimal] = [:]
            for (toKey, rateString) in toRates {
                guard let toCurrency = Currency(rawValue: toKey),
                      let rate = Decimal(string: rateString) else { continue }
                innerRates[toCurrency] = rate
            }

            loadedRates[fromCurrency] = innerRates
        }

        if !loadedRates.isEmpty {
            exchangeRates = loadedRates
            print("📂 [CurrencyConverter] Loaded \(loadedRates.count) currency rates from UserDefaults")
        }
    }

    func getLastUpdateDate() -> Date? {
        return UserDefaults.standard.object(forKey: "lastRateUpdate") as? Date
    }

    func resetToDefaultRates() {
        var rates: [Currency: [Currency: Decimal]] = [:]

        // Tassi di base da EUR (approssimativi - usa l'aggiornamento automatico per tassi reali)
        let eurRates: [Currency: Decimal] = [
            .EUR: 1.0, .USD: 1.10, .GBP: 0.86, .CHF: 0.96, .SEK: 11.50, .NOK: 11.80,
            .DKK: 7.45, .PLN: 4.35, .CZK: 24.50, .HUF: 390.0, .RON: 4.95, .BGN: 1.96,
            .HRK: 7.53, .RUB: 100.0, .TRY: 32.0, .UAH: 44.0, .CAD: 1.48, .MXN: 18.5,
            .BRL: 5.40, .ARS: 900.0, .CLP: 1050.0, .COP: 4300.0, .PEN: 4.10, .JPY: 161.0,
            .CNY: 7.85, .HKD: 8.58, .MOP: 8.85, .TWD: 34.5, .KRW: 1450.0, .SGD: 1.45,
            .THB: 38.5, .MYR: 4.90, .IDR: 17200.0, .PHP: 61.5, .VND: 27000.0, .INR: 91.5,
            .PKR: 305.0, .BDT: 120.0, .LKR: 330.0, .AED: 4.04, .SAR: 4.12, .QAR: 4.00,
            .KWD: 0.34, .BHD: 0.41, .OMR: 0.42, .ILS: 4.05, .AUD: 1.68, .NZD: 1.82,
            .ZAR: 20.0, .EGP: 54.0, .NGN: 1550.0, .KES: 140.0, .GHS: 16.5, .MAD: 10.8
        ]

        // Crea tassi incrociati per tutte le valute
        for fromCurrency in Currency.allCases {
            var fromRates: [Currency: Decimal] = [:]

            for toCurrency in Currency.allCases {
                if fromCurrency == toCurrency {
                    fromRates[toCurrency] = 1.0
                } else {
                    // Converti attraverso EUR: from -> EUR -> to
                    let fromToEur = 1.0 / (eurRates[fromCurrency] ?? 1.0)
                    let eurToTo = eurRates[toCurrency] ?? 1.0
                    fromRates[toCurrency] = fromToEur * eurToTo
                }
            }

            rates[fromCurrency] = fromRates
        }

        exchangeRates = rates
        saveRates()
    }
}
