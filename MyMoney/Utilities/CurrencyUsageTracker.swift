//
//  CurrencyUsageTracker.swift
//  MoneyTracker
//
//  Created on 2026-01-01.
//

import Foundation

final class CurrencyUsageTracker {
    static let shared = CurrencyUsageTracker()

    private let usageCountKey = "currencyUsageCount"
    private let recentCurrenciesKey = "recentCurrencies"
    private let frequentThreshold = 3 // Appare in cima se usata almeno 3 volte

    private init() {}

    // MARK: - Track Usage

    func recordUsage(of currency: Currency) {
        // Incrementa il contatore
        var usageCount = getUsageCount()
        usageCount[currency.rawValue, default: 0] += 1
        saveUsageCount(usageCount)

        // Aggiorna lista recenti (max 5)
        var recent = getRecentCurrencies()
        recent.removeAll { $0 == currency.rawValue }
        recent.insert(currency.rawValue, at: 0)
        if recent.count > 5 {
            recent = Array(recent.prefix(5))
        }
        saveRecentCurrencies(recent)
    }

    // MARK: - Get Sorted Currencies

    func getSortedCurrencies() -> [Currency] {
        let usageCount = getUsageCount()
        let recent = getRecentCurrencies()

        var frequentCurrencies: [Currency] = []
        var recentCurrencies: [Currency] = []
        var otherCurrencies: [Currency] = []

        for currency in Currency.allCases {
            let count = usageCount[currency.rawValue] ?? 0

            // Frequenti (usate >= threshold volte)
            if count >= frequentThreshold {
                frequentCurrencies.append(currency)
            }
            // Recenti (ultime 5 usate)
            else if recent.contains(currency.rawValue) {
                recentCurrencies.append(currency)
            }
            // Altre
            else {
                otherCurrencies.append(currency)
            }
        }

        // Ordina frequenti per conteggio decrescente
        frequentCurrencies.sort { currency1, currency2 in
            let count1 = usageCount[currency1.rawValue] ?? 0
            let count2 = usageCount[currency2.rawValue] ?? 0
            return count1 > count2
        }

        // Ordina recenti per ordine di utilizzo
        recentCurrencies.sort { currency1, currency2 in
            let index1 = recent.firstIndex(of: currency1.rawValue) ?? Int.max
            let index2 = recent.firstIndex(of: currency2.rawValue) ?? Int.max
            return index1 < index2
        }

        // Combina: Frequenti + Recenti + Altre
        return frequentCurrencies + recentCurrencies + otherCurrencies
    }

    func getFrequentCurrencies() -> [Currency] {
        let usageCount = getUsageCount()
        return Currency.allCases.filter { currency in
            (usageCount[currency.rawValue] ?? 0) >= frequentThreshold
        }.sorted { currency1, currency2 in
            let count1 = usageCount[currency1.rawValue] ?? 0
            let count2 = usageCount[currency2.rawValue] ?? 0
            return count1 > count2
        }
    }

    func getRecentCurrenciesObjects() -> [Currency] {
        return getRecentCurrencies().compactMap { Currency(rawValue: $0) }
    }

    // MARK: - UserDefaults

    private func getUsageCount() -> [String: Int] {
        return UserDefaults.standard.dictionary(forKey: usageCountKey) as? [String: Int] ?? [:]
    }

    private func saveUsageCount(_ count: [String: Int]) {
        UserDefaults.standard.set(count, forKey: usageCountKey)
    }

    func getRecentCurrencies() -> [String] {
        return UserDefaults.standard.stringArray(forKey: recentCurrenciesKey) ?? []
    }

    private func saveRecentCurrencies(_ currencies: [String]) {
        UserDefaults.standard.set(currencies, forKey: recentCurrenciesKey)
    }

    // MARK: - Reset

    func resetUsageData() {
        UserDefaults.standard.removeObject(forKey: usageCountKey)
        UserDefaults.standard.removeObject(forKey: recentCurrenciesKey)
    }
}
