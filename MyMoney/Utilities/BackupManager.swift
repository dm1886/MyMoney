//
//  BackupManager.swift
//  MoneyTracker
//
//  Created on 2026-01-01.
//  Updated on 2026-01-15 - Complete backup with all data
//

import Foundation
import SwiftData
import UniformTypeIdentifiers

struct BackupData: Codable {
    let version: String
    let createdAt: Date
    let accounts: [AccountBackup]
    let transactions: [TransactionBackup]
    let categories: [CategoryBackup]
    let categoryGroups: [CategoryGroupBackup]
    let currencyRecords: [CurrencyRecordBackup]
    let exchangeRates: [ExchangeRateBackup]
    let settings: SettingsBackup
}

struct AccountBackup: Codable {
    let id: String
    let name: String
    let accountType: String
    let currency: String  // DEPRECATED: kept for compatibility
    let currencyRecordCode: String?  // NUOVO: code della CurrencyRecord
    let initialBalance: String
    let currentBalance: String
    let creditLimit: String?  // Per carte di credito
    let icon: String
    let colorHex: String
    let imageData: String?  // Base64 encoded
    let accountDescription: String
    let createdAt: Date
}

struct TransactionBackup: Codable {
    let id: String
    let transactionType: String
    let amount: String
    let currency: String  // DEPRECATED: kept for compatibility
    let currencyRecordCode: String?  // NUOVO: code della CurrencyRecord
    let date: Date
    let notes: String
    let accountId: String
    let categoryId: String?
    let destinationAccountId: String?
    let destinationAmount: String?  // Per trasferimenti con conversione

    // Transazioni programmate
    let isScheduled: Bool
    let scheduledDate: Date?
    let isAutomatic: Bool
    let status: String

    // Transazioni ricorrenti
    let isRecurring: Bool
    let recurrenceInterval: Int?
    let recurrenceUnit: String?
    let recurrenceEndDate: Date?
    let parentRecurringTransactionId: String?
    let adjustToWorkingDay: Bool?  // If true, adjust recurring dates to next working day
}

struct CategoryBackup: Codable {
    let id: String
    let name: String
    let icon: String
    let colorHex: String
    let createdAt: Date
    let categoryGroupId: String?
    let defaultAccountId: String?
}

struct CategoryGroupBackup: Codable {
    let id: String
    let name: String
    let icon: String
    let colorHex: String
    let sortOrder: Int
    let applicability: String  // NUOVO: TransactionTypeScope
}

struct CurrencyRecordBackup: Codable {
    let code: String
    let name: String
    let symbol: String
    let countryCode: String
    let flagEmoji: String
    let usageCount: Int
    let lastUsedDate: Date?
    let isActive: Bool
    let createdAt: Date
}

struct ExchangeRateBackup: Codable {
    let id: String
    let fromCurrencyCode: String
    let toCurrencyCode: String
    let rate: String
    let lastUpdated: Date
    let source: String
    let isCustom: Bool
}

struct SettingsBackup: Codable {
    let preferredCurrency: String
    let themeMode: String
}

final class BackupManager {
    static let shared = BackupManager()

    private init() {}

    // MARK: - Export Backup

    func createBackup(
        accounts: [Account],
        transactions: [Transaction],
        categories: [Category],
        categoryGroups: [CategoryGroup],
        currencyRecords: [CurrencyRecord],
        exchangeRates: [ExchangeRate]
    ) throws -> Data {
        LogManager.shared.info("Creating backup with \(accounts.count) accounts, \(transactions.count) transactions, \(categories.count) categories, \(categoryGroups.count) groups, \(currencyRecords.count) currencies, \(exchangeRates.count) rates", category: "Backup")

        let backupData = BackupData(
            version: "2.0.0",  // Updated version
            createdAt: Date(),
            accounts: accounts.map { convertToBackup($0) },
            transactions: transactions.map { convertToBackup($0) },
            categories: categories.map { convertToBackup($0) },
            categoryGroups: categoryGroups.map { convertToBackup($0) },
            currencyRecords: currencyRecords.map { convertToBackup($0) },
            exchangeRates: exchangeRates.map { convertToBackup($0) },
            settings: SettingsBackup(
                preferredCurrency: AppSettings.shared.preferredCurrency,
                themeMode: AppSettings.shared.themeMode.rawValue
            )
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(backupData)
        LogManager.shared.success("Backup created successfully (\(data.count) bytes)", category: "Backup")
        return data
    }

    // MARK: - Import Backup

    func restoreBackup(
        from data: Data,
        modelContext: ModelContext
    ) throws -> (accounts: Int, transactions: Int, categories: Int, currencies: Int, rates: Int) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let backupData = try decoder.decode(BackupData.self, from: data)
        LogManager.shared.info("Restoring backup version \(backupData.version) from \(backupData.createdAt.formatted())", category: "Backup")

        // Elimina tutti i dati esistenti
        try deleteAllData(modelContext: modelContext)
        LogManager.shared.info("Deleted all existing data", category: "Backup")

        // ID mappings per relazioni
        var currencyRecordMap: [String: CurrencyRecord] = [:]
        var accountIdMap: [String: Account] = [:]
        var categoryIdMap: [String: Category] = [:]
        var categoryGroupIdMap: [String: CategoryGroup] = [:]

        // 1. Ripristina CurrencyRecords (prima di tutto perché gli account li usano)
        for currencyBackup in backupData.currencyRecords {
            let currency = CurrencyRecord(
                code: currencyBackup.code,
                name: currencyBackup.name,
                symbol: currencyBackup.symbol,
                countryCode: currencyBackup.countryCode,
                flagEmoji: currencyBackup.flagEmoji
            )
            currency.usageCount = currencyBackup.usageCount
            currency.lastUsedDate = currencyBackup.lastUsedDate
            currency.isActive = currencyBackup.isActive
            currency.createdAt = currencyBackup.createdAt
            modelContext.insert(currency)
            currencyRecordMap[currencyBackup.code] = currency
        }
        LogManager.shared.info("Restored \(backupData.currencyRecords.count) currency records", category: "Backup")

        // 2. Ripristina ExchangeRates
        for rateBackup in backupData.exchangeRates {
            guard let fromCurrency = currencyRecordMap[rateBackup.fromCurrencyCode],
                  let toCurrency = currencyRecordMap[rateBackup.toCurrencyCode] else {
                LogManager.shared.warning("Skipping exchange rate for missing currencies: \(rateBackup.fromCurrencyCode) -> \(rateBackup.toCurrencyCode)", category: "Backup")
                continue
            }

            let source = RateSource(rawValue: rateBackup.source) ?? .default
            let rate = ExchangeRate(
                fromCurrency: fromCurrency,
                toCurrency: toCurrency,
                rate: Decimal(string: rateBackup.rate) ?? 1,
                source: source
            )
            rate.lastUpdated = rateBackup.lastUpdated
            rate.isCustom = rateBackup.isCustom
            modelContext.insert(rate)
        }
        LogManager.shared.info("Restored \(backupData.exchangeRates.count) exchange rates", category: "Backup")

        // 3. Ripristina CategoryGroups
        for groupBackup in backupData.categoryGroups {
            let group = CategoryGroup(
                name: groupBackup.name,
                icon: groupBackup.icon,
                colorHex: groupBackup.colorHex,
                sortOrder: groupBackup.sortOrder,
                applicability: TransactionTypeScope(rawValue: groupBackup.applicability) ?? .all
            )
            modelContext.insert(group)
            categoryGroupIdMap[groupBackup.id] = group
        }
        LogManager.shared.info("Restored \(backupData.categoryGroups.count) category groups", category: "Backup")

        // 4. Ripristina Accounts
        for accountBackup in backupData.accounts {
            // Decode imageData from Base64
            var imageData: Data? = nil
            if let base64String = accountBackup.imageData {
                imageData = Data(base64Encoded: base64String)
            }

            let account = Account(
                name: accountBackup.name,
                accountType: AccountType(rawValue: accountBackup.accountType) ?? .payment,
                currency: Currency(rawValue: accountBackup.currency) ?? .EUR,
                initialBalance: Decimal(string: accountBackup.initialBalance) ?? 0,
                creditLimit: accountBackup.creditLimit.flatMap { Decimal(string: $0) },
                icon: accountBackup.icon,
                colorHex: accountBackup.colorHex,
                imageData: imageData,
                accountDescription: accountBackup.accountDescription
            )
            account.currentBalance = Decimal(string: accountBackup.currentBalance) ?? 0

            // Link currency record
            if let currencyCode = accountBackup.currencyRecordCode,
               let currencyRecord = currencyRecordMap[currencyCode] {
                account.currencyRecord = currencyRecord
            }

            modelContext.insert(account)
            accountIdMap[accountBackup.id] = account
        }
        LogManager.shared.info("Restored \(backupData.accounts.count) accounts", category: "Backup")

        // 5. Ripristina Categories
        for categoryBackup in backupData.categories {
            let category = Category(
                name: categoryBackup.name,
                icon: categoryBackup.icon,
                colorHex: categoryBackup.colorHex
            )

            if let groupId = categoryBackup.categoryGroupId {
                category.categoryGroup = categoryGroupIdMap[groupId]
            }

            if let defaultAccountId = categoryBackup.defaultAccountId {
                category.defaultAccount = accountIdMap[defaultAccountId]
            }

            modelContext.insert(category)
            categoryIdMap[categoryBackup.id] = category
        }
        LogManager.shared.info("Restored \(backupData.categories.count) categories", category: "Backup")

        // 6. Ripristina Transactions
        for transactionBackup in backupData.transactions {
            guard let account = accountIdMap[transactionBackup.accountId] else {
                LogManager.shared.warning("Skipping transaction with missing account: \(transactionBackup.id)", category: "Backup")
                continue
            }

            let transaction = Transaction(
                transactionType: TransactionType(rawValue: transactionBackup.transactionType) ?? .expense,
                amount: Decimal(string: transactionBackup.amount) ?? 0,
                currency: Currency(rawValue: transactionBackup.currency) ?? .EUR,
                date: transactionBackup.date,
                notes: transactionBackup.notes,
                account: account,
                category: transactionBackup.categoryId.flatMap { categoryIdMap[$0] },
                destinationAccount: transactionBackup.destinationAccountId.flatMap { accountIdMap[$0] }
            )

            // Link currency record
            if let currencyCode = transactionBackup.currencyRecordCode,
               let currencyRecord = currencyRecordMap[currencyCode] {
                transaction.currencyRecord = currencyRecord
            }

            // Destination amount for transfers with conversion
            if let destAmountString = transactionBackup.destinationAmount {
                transaction.destinationAmount = Decimal(string: destAmountString)
            }

            // Scheduled transaction fields
            transaction.isScheduled = transactionBackup.isScheduled
            // For backward compatibility: if old backup has scheduledDate, use it as the date
            if transactionBackup.isScheduled, let oldScheduledDate = transactionBackup.scheduledDate {
                transaction.date = oldScheduledDate
            }
            transaction.isAutomatic = transactionBackup.isAutomatic
            transaction.status = TransactionStatus(rawValue: transactionBackup.status) ?? .executed

            // Recurring transaction fields
            transaction.isRecurring = transactionBackup.isRecurring
            if let interval = transactionBackup.recurrenceInterval,
               let unitString = transactionBackup.recurrenceUnit,
               let unit = RecurrenceUnit(rawValue: unitString) {
                transaction.recurrenceRule = RecurrenceRule(interval: interval, unit: unit)
            }
            transaction.recurrenceEndDate = transactionBackup.recurrenceEndDate
            if let parentId = transactionBackup.parentRecurringTransactionId {
                transaction.parentRecurringTransactionId = UUID(uuidString: parentId)
            }
            transaction.adjustToWorkingDay = transactionBackup.adjustToWorkingDay ?? false

            modelContext.insert(transaction)
        }
        LogManager.shared.info("Restored \(backupData.transactions.count) transactions", category: "Backup")

        // 7. Ripristina Settings
        AppSettings.shared.preferredCurrency = backupData.settings.preferredCurrency
        if let theme = ThemeMode(rawValue: backupData.settings.themeMode) {
            AppSettings.shared.themeMode = theme
        }
        LogManager.shared.info("Restored app settings", category: "Backup")

        try modelContext.save()
        LogManager.shared.success("Backup restored successfully", category: "Backup")

        return (
            accounts: backupData.accounts.count,
            transactions: backupData.transactions.count,
            categories: backupData.categories.count,
            currencies: backupData.currencyRecords.count,
            rates: backupData.exchangeRates.count
        )
    }

    // MARK: - Helpers

    private func deleteAllData(modelContext: ModelContext) throws {
        // Elimina in ordine per rispettare le relazioni
        try modelContext.delete(model: Transaction.self)
        try modelContext.delete(model: Category.self)
        try modelContext.delete(model: CategoryGroup.self)
        try modelContext.delete(model: Account.self)
        try modelContext.delete(model: ExchangeRate.self)
        try modelContext.delete(model: CurrencyRecord.self)
    }

    private func convertToBackup(_ account: Account) -> AccountBackup {
        // Encode imageData to Base64
        var imageDataString: String? = nil
        if let imageData = account.imageData {
            imageDataString = imageData.base64EncodedString()
        }

        return AccountBackup(
            id: account.id.uuidString,
            name: account.name,
            accountType: account.accountType.rawValue,
            currency: account.currency.rawValue,
            currencyRecordCode: account.currencyRecord?.code,
            initialBalance: "\(account.initialBalance)",
            currentBalance: "\(account.currentBalance)",
            creditLimit: account.creditLimit.map { "\($0)" },
            icon: account.icon,
            colorHex: account.colorHex,
            imageData: imageDataString,
            accountDescription: account.accountDescription,
            createdAt: account.createdAt
        )
    }

    private func convertToBackup(_ transaction: Transaction) -> TransactionBackup {
        TransactionBackup(
            id: transaction.id.uuidString,
            transactionType: transaction.transactionType.rawValue,
            amount: "\(transaction.amount)",
            currency: transaction.currency.rawValue,
            currencyRecordCode: transaction.currencyRecord?.code,
            date: transaction.date,
            notes: transaction.notes,
            accountId: transaction.account?.id.uuidString ?? "",
            categoryId: transaction.category?.id.uuidString,
            destinationAccountId: transaction.destinationAccount?.id.uuidString,
            destinationAmount: transaction.destinationAmount.map { "\($0)" },
            isScheduled: transaction.isScheduled,
            scheduledDate: nil,  // Deprecated: kept for backward compatibility
            isAutomatic: transaction.isAutomatic,
            status: transaction.status.rawValue,
            isRecurring: transaction.isRecurring,
            recurrenceInterval: transaction.recurrenceRule?.interval,
            recurrenceUnit: transaction.recurrenceRule?.unit.rawValue,
            recurrenceEndDate: transaction.recurrenceEndDate,
            parentRecurringTransactionId: transaction.parentRecurringTransactionId?.uuidString,
            adjustToWorkingDay: transaction.adjustToWorkingDay
        )
    }

    private func convertToBackup(_ category: Category) -> CategoryBackup {
        CategoryBackup(
            id: category.id.uuidString,
            name: category.name,
            icon: category.icon,
            colorHex: category.colorHex,
            createdAt: category.createdAt,
            categoryGroupId: category.categoryGroup?.id.uuidString,
            defaultAccountId: category.defaultAccount?.id.uuidString
        )
    }

    private func convertToBackup(_ categoryGroup: CategoryGroup) -> CategoryGroupBackup {
        CategoryGroupBackup(
            id: categoryGroup.id.uuidString,
            name: categoryGroup.name,
            icon: categoryGroup.icon,
            colorHex: categoryGroup.colorHex,
            sortOrder: categoryGroup.sortOrder,
            applicability: categoryGroup.applicability.rawValue
        )
    }

    private func convertToBackup(_ currencyRecord: CurrencyRecord) -> CurrencyRecordBackup {
        CurrencyRecordBackup(
            code: currencyRecord.code,
            name: currencyRecord.name,
            symbol: currencyRecord.symbol,
            countryCode: currencyRecord.countryCode,
            flagEmoji: currencyRecord.flagEmoji,
            usageCount: currencyRecord.usageCount,
            lastUsedDate: currencyRecord.lastUsedDate,
            isActive: currencyRecord.isActive,
            createdAt: currencyRecord.createdAt
        )
    }

    private func convertToBackup(_ exchangeRate: ExchangeRate) -> ExchangeRateBackup {
        ExchangeRateBackup(
            id: exchangeRate.id.uuidString,
            fromCurrencyCode: exchangeRate.fromCurrency?.code ?? "",
            toCurrencyCode: exchangeRate.toCurrency?.code ?? "",
            rate: "\(exchangeRate.rate)",
            lastUpdated: exchangeRate.lastUpdated,
            source: exchangeRate.source.rawValue,
            isCustom: exchangeRate.isCustom
        )
    }

    // MARK: - File Management

    func getBackupFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return "MoneyTracker_Backup_\(formatter.string(from: Date())).json"
    }

    static let backupFileType = UTType(exportedAs: "com.moneytracker.backup")
}
