//
//  CurrencyService.swift
//  MoneyTracker
//
//  Created on 2026-01-06.
//

import Foundation
import SwiftData

/// Service for currency conversion using SwiftData models
/// Replaces CurrencyConverter for SwiftData-based operations
final class CurrencyService {
    static let shared = CurrencyService()

    // In-memory cache to avoid repeated database queries
    private var currencyCache: [String: CurrencyRecord] = [:]
    private var exchangeRateCache: [String: Decimal] = [:]
    private let cacheQueue = DispatchQueue(label: "com.moneytracker.currencyservice.cache")

    private init() {}

    // MARK: - Currency Conversion

    func convert(amount: Decimal, from: CurrencyRecord, to: CurrencyRecord, context: ModelContext) -> Decimal {
        if from.code == to.code {
            return amount
        }

        // Try direct conversion first
        if let rate = getExchangeRate(from: from, to: to, context: context) {
            return amount * rate
        }

        // Try cross-conversion through USD
        if let usdCurrency = getCurrency(byCode: "USD", context: context) {
            if let fromToUSD = getExchangeRate(from: from, to: usdCurrency, context: context),
               let usdToTo = getExchangeRate(from: usdCurrency, to: to, context: context) {
                return amount * fromToUSD * usdToTo
            }
        }

        // Try cross-conversion through EUR as fallback
        if let eurCurrency = getCurrency(byCode: "EUR", context: context) {
            if let fromToEUR = getExchangeRate(from: from, to: eurCurrency, context: context),
               let eurToTo = getExchangeRate(from: eurCurrency, to: to, context: context) {
                return amount * fromToEUR * eurToTo
            }
        }

        return amount  // Fallback: no conversion
    }

    // MARK: - Exchange Rate Queries

    func getExchangeRate(from: CurrencyRecord, to: CurrencyRecord, context: ModelContext) -> Decimal? {
        let cacheKey = "\(from.code)_\(to.code)"

        // Try cache first
        var cachedRate: Decimal?
        cacheQueue.sync {
            cachedRate = exchangeRateCache[cacheKey]
        }

        if let cached = cachedRate {
            return cached
        }

        // Fallback to database query
        let descriptor = FetchDescriptor<ExchangeRate>()

        do {
            let allRates = try context.fetch(descriptor)

            // Filter in Swift code
            let matchingRate = allRates.first { rate in
                guard let fromCurr = rate.fromCurrency,
                      let toCurr = rate.toCurrency else {
                    return false
                }
                return fromCurr.code == from.code && toCurr.code == to.code
            }

            if let rate = matchingRate?.rate {
                // Cache for future use
                cacheQueue.sync {
                    exchangeRateCache[cacheKey] = rate
                }
            }

            return matchingRate?.rate
        } catch {
            print("❌ [CurrencyService] Failed to fetch exchange rates: \(error)")
            return nil
        }
    }

    func getExchangeRateModel(from: CurrencyRecord, to: CurrencyRecord, context: ModelContext) -> ExchangeRate? {
        // Fetch all rates and filter in memory
        // SwiftData doesn't support force unwrap (!) operator in predicates
        let descriptor = FetchDescriptor<ExchangeRate>()

        do {
            let allRates = try context.fetch(descriptor)

            // Filter in Swift code
            return allRates.first { rate in
                guard let fromCurr = rate.fromCurrency,
                      let toCurr = rate.toCurrency else {
                    return false
                }
                return fromCurr.code == from.code && toCurr.code == to.code
            }
        } catch {
            print("❌ [CurrencyService] Failed to fetch exchange rates: \(error)")
            return nil
        }
    }

    // MARK: - Exchange Rate Updates

    func updateExchangeRate(
        from: CurrencyRecord,
        to: CurrencyRecord,
        rate: Decimal,
        source: RateSource,
        context: ModelContext,
        autoSave: Bool = true
    ) {
        // Check if rate already exists
        if let existingRate = getExchangeRateModel(from: from, to: to, context: context) {
            existingRate.rate = rate
            existingRate.lastUpdated = Date()
            existingRate.source = source
            existingRate.isCustom = (source == .manual)
        } else {
            // Create new rate
            let newRate = ExchangeRate(fromCurrency: from, toCurrency: to, rate: rate, source: source)
            context.insert(newRate)
        }

        // Update inverse rate (bidirectional)
        if from.code != to.code, rate != 0 {
            let inverseRate = 1 / rate
            if let existingInverse = getExchangeRateModel(from: to, to: from, context: context) {
                existingInverse.rate = inverseRate
                existingInverse.lastUpdated = Date()
                existingInverse.source = source
                existingInverse.isCustom = (source == .manual)
            } else {
                let newInverse = ExchangeRate(fromCurrency: to, toCurrency: from, rate: inverseRate, source: source)
                context.insert(newInverse)
            }
        }

        // Invalidate cache for updated rates
        let cacheKey = "\(from.code)_\(to.code)"
        let inverseCacheKey = "\(to.code)_\(from.code)"
        cacheQueue.sync {
            exchangeRateCache.removeValue(forKey: cacheKey)
            exchangeRateCache.removeValue(forKey: inverseCacheKey)
        }

        if autoSave {
            try? context.save()
        }
    }

    // MARK: - Cache Management

    /// Populate cache with all currencies to avoid repeated I/O
    func populateCache(context: ModelContext) {
        let descriptor = FetchDescriptor<CurrencyRecord>()
        guard let currencies = try? context.fetch(descriptor) else { return }

        cacheQueue.sync {
            for currency in currencies {
                currencyCache[currency.code] = currency
            }
        }
        print("✓ [CurrencyService] Cache populated with \(currencies.count) currencies")
    }

    /// Clear cache when data changes
    func clearCache() {
        cacheQueue.sync {
            currencyCache.removeAll()
            exchangeRateCache.removeAll()
        }
    }

    // MARK: - Currency Lookup

    func getCurrency(byCode code: String, context: ModelContext) -> CurrencyRecord? {
        // Try cache first
        var cachedCurrency: CurrencyRecord?
        cacheQueue.sync {
            cachedCurrency = currencyCache[code]
        }

        if let cached = cachedCurrency {
            return cached
        }

        // Fallback to database query
        let predicate = #Predicate<CurrencyRecord> { currency in
            currency.code == code
        }

        let descriptor = FetchDescriptor<CurrencyRecord>(predicate: predicate)
        guard let currency = try? context.fetch(descriptor).first else {
            return nil
        }

        // Cache for future use
        cacheQueue.sync {
            currencyCache[code] = currency
        }

        return currency
    }

    func getOrCreateCurrency(fromEnum currency: Currency, context: ModelContext) -> CurrencyRecord? {
        // Try to find existing
        if let existing = getCurrency(byCode: currency.rawValue, context: context) {
            return existing
        }

        // Create new (shouldn't happen after migration, but safe fallback)
        let record = CurrencyRecord(
            code: currency.rawValue,
            name: currency.fullName,
            symbol: currency.symbol,
            countryCode: CurrencyHelper.countryCode(for: currency),
            flagEmoji: currency.flag
        )
        context.insert(record)
        try? context.save()

        return record
    }

    // MARK: - Usage Tracking

    func recordUsage(of currency: CurrencyRecord, context: ModelContext) {
        currency.usageCount += 1
        currency.lastUsedDate = Date()
        try? context.save()
        print("📊 [CurrencyService] Recorded usage: \(currency.code) (count: \(currency.usageCount))")
    }

    // MARK: - Last Update Date

    func getLastUpdateDate(context: ModelContext) -> Date? {
        let descriptor = FetchDescriptor<ExchangeRate>(
            sortBy: [SortDescriptor(\.lastUpdated, order: .reverse)]
        )

        do {
            let rates = try context.fetch(descriptor)
            return rates.first?.lastUpdated
        } catch {
            print("❌ [CurrencyService] Failed to fetch last update date: \(error)")
            return nil
        }
    }
}
