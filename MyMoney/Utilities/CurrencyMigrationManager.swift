//
//  CurrencyMigrationManager.swift
//  MoneyTracker
//
//  Created on 2026-01-06.
//

import Foundation
import SwiftData

final class CurrencyMigrationManager {
    static let shared = CurrencyMigrationManager()

    private let migrationKey = "hasMigratedToSwiftDataCurrencies_v1"

    private init() {}

    func needsMigration() -> Bool {
        !UserDefaults.standard.bool(forKey: migrationKey)
    }

    func performMigration(context: ModelContext) throws {
        print("🔄 [Migration] Starting currency migration to SwiftData...")

        // Step 1: Seed all 140+ currencies from Currency enum
        try seedCurrencies(context: context)

        // Step 2: SKIP exchange rates migration (user will download fresh rates via "Aggiorna Tassi")
        print("⏭️ [Migration] Skipping exchange rates (will be downloaded on demand)")

        // Step 3: Migrate usage statistics from CurrencyUsageTracker
        try migrateUsageStats(context: context)

        // Step 4: Migrate Account and Transaction models
        try migrateAccountsAndTransactions(context: context)

        // Mark migration complete
        UserDefaults.standard.set(true, forKey: migrationKey)
        print("✅ [Migration] Currency migration completed successfully!")
    }

    // MARK: - Step 1: Seed Currencies

    private func seedCurrencies(context: ModelContext) throws {
        print("📦 [Migration] Seeding currencies from Currency enum...")

        for currency in Currency.allCases {
            let record = CurrencyRecord(
                code: currency.rawValue,
                name: currency.fullName,
                symbol: currency.symbol,
                countryCode: CurrencyHelper.countryCode(for: currency),
                flagEmoji: currency.flag
            )
            context.insert(record)
        }

        try context.save()
        print("✅ [Migration] Seeded \(Currency.allCases.count) currencies")
    }

    // MARK: - Step 2: Migrate Exchange Rates

    private func migrateExchangeRates(context: ModelContext) throws {
        print("💱 [Migration] Migrating exchange rates from UserDefaults...")

        // Load old rates from CurrencyConverter
        let converter = CurrencyConverter.shared
        let oldRates = converter.getAllRates()

        // Fetch all currencies for lookup
        let currencies = try context.fetch(FetchDescriptor<CurrencyRecord>())
        let currencyMap = Dictionary(uniqueKeysWithValues: currencies.map { ($0.code, $0) })

        var migratedCount = 0

        for (fromEnum, toRates) in oldRates {
            guard let fromCurrency = currencyMap[fromEnum.rawValue] else { continue }

            for (toEnum, rate) in toRates {
                guard let toCurrency = currencyMap[toEnum.rawValue] else { continue }

                let exchangeRate = ExchangeRate(
                    fromCurrency: fromCurrency,
                    toCurrency: toCurrency,
                    rate: rate,
                    source: .manual  // Preserve existing rates as manual to prevent API overwrite
                )
                context.insert(exchangeRate)
                migratedCount += 1
            }
        }

        try context.save()
        print("✅ [Migration] Migrated \(migratedCount) exchange rates")
    }

    // MARK: - Step 3: Migrate Usage Statistics

    private func migrateUsageStats(context: ModelContext) throws {
        print("📊 [Migration] Migrating usage statistics...")

        let tracker = CurrencyUsageTracker.shared

        // Get usage counts and recent currencies
        let usageCounts = tracker.getUsageCounts()
        let recentCurrencies = tracker.getRecentCurrencies()

        // Fetch all currencies
        let currencies = try context.fetch(FetchDescriptor<CurrencyRecord>())

        for currency in currencies {
            // Migrate usage count
            if let count = usageCounts[currency.code] {
                currency.usageCount = count
            }

            // Migrate recent usage (estimate lastUsedDate based on position in array)
            if let recentIndex = recentCurrencies.firstIndex(of: currency.code) {
                // Most recent = today, older = subtract days
                currency.lastUsedDate = Calendar.current.date(byAdding: .day, value: -recentIndex, to: Date())
            }
        }

        try context.save()
        print("✅ [Migration] Migrated usage statistics")
    }

    // MARK: - Step 4: Migrate Account and Transaction Models

    func migrateAccountsAndTransactions(context: ModelContext) throws {
        print("🏦 [Migration] Migrating accounts and transactions...")

        // Fetch all currencies for lookup
        let currencies = try context.fetch(FetchDescriptor<CurrencyRecord>())
        let currencyMap = Dictionary(uniqueKeysWithValues: currencies.map { ($0.code, $0) })

        // Migrate accounts
        let accounts = try context.fetch(FetchDescriptor<Account>())
        var accountsMigrated = 0

        for account in accounts {
            if account.currencyRecord == nil {
                account.currencyRecord = currencyMap[account.currency.rawValue]
                accountsMigrated += 1
            }
        }

        // Migrate transactions
        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        var transactionsMigrated = 0

        for transaction in transactions {
            if transaction.currencyRecord == nil {
                transaction.currencyRecord = currencyMap[transaction.currency.rawValue]
                transactionsMigrated += 1
            }
        }

        try context.save()
        print("✅ [Migration] Migrated \(accountsMigrated) accounts and \(transactionsMigrated) transactions")
    }
}

// MARK: - Helper: CurrencyUsageTracker Access

extension CurrencyUsageTracker {
    func getUsageCounts() -> [String: Int] {
        // Access internal usage count dictionary
        // This relies on CurrencyUsageTracker having this data
        var counts: [String: Int] = [:]

        for currency in Currency.allCases {
            // Get count from tracker (if available)
            // Fallback: Check if in frequent list
            if getFrequentCurrencies().contains(currency) {
                counts[currency.rawValue] = 5  // Assume frequent = at least 5 uses
            } else if getRecentCurrencies().contains(currency.rawValue) {
                counts[currency.rawValue] = 1  // Recent but not frequent
            }
        }

        return counts
    }
}
