//
//  BackupManager.swift
//  MoneyTracker
//
//  Created on 2026-01-01.
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
    let settings: SettingsBackup
}

struct AccountBackup: Codable {
    let id: String
    let name: String
    let accountType: String
    let currency: String
    let initialBalance: String
    let currentBalance: String
    let icon: String
    let colorHex: String
    let accountDescription: String
    let createdAt: Date
}

struct TransactionBackup: Codable {
    let id: String
    let transactionType: String
    let amount: String
    let currency: String
    let date: Date
    let notes: String
    let accountId: String
    let categoryId: String?
    let destinationAccountId: String?
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
        categoryGroups: [CategoryGroup]
    ) throws -> Data {
        let backupData = BackupData(
            version: "1.0.0",
            createdAt: Date(),
            accounts: accounts.map { convertToBackup($0) },
            transactions: transactions.map { convertToBackup($0) },
            categories: categories.map { convertToBackup($0) },
            categoryGroups: categoryGroups.map { convertToBackup($0) },
            settings: SettingsBackup(
                preferredCurrency: AppSettings.shared.preferredCurrency,
                themeMode: AppSettings.shared.themeMode.rawValue
            )
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        return try encoder.encode(backupData)
    }

    // MARK: - Import Backup

    func restoreBackup(
        from data: Data,
        modelContext: ModelContext
    ) throws -> (accounts: Int, transactions: Int, categories: Int) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let backupData = try decoder.decode(BackupData.self, from: data)

        // Elimina tutti i dati esistenti
        try deleteAllData(modelContext: modelContext)

        // ID mappings per relazioni
        var accountIdMap: [String: Account] = [:]
        var categoryIdMap: [String: Category] = [:]
        var categoryGroupIdMap: [String: CategoryGroup] = [:]

        // Ripristina CategoryGroups
        for groupBackup in backupData.categoryGroups {
            let group = CategoryGroup(
                name: groupBackup.name,
                icon: groupBackup.icon,
                colorHex: groupBackup.colorHex
            )
            modelContext.insert(group)
            categoryGroupIdMap[groupBackup.id] = group
        }

        // Ripristina Accounts
        for accountBackup in backupData.accounts {
            let account = Account(
                name: accountBackup.name,
                accountType: AccountType(rawValue: accountBackup.accountType) ?? .payment,
                currency: Currency(rawValue: accountBackup.currency) ?? .EUR,
                initialBalance: Decimal(string: accountBackup.initialBalance) ?? 0,
                icon: accountBackup.icon,
                colorHex: accountBackup.colorHex,
                imageData: nil,
                accountDescription: accountBackup.accountDescription
            )
            account.currentBalance = Decimal(string: accountBackup.currentBalance) ?? 0
            modelContext.insert(account)
            accountIdMap[accountBackup.id] = account
        }

        // Ripristina Categories
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

        // Ripristina Transactions
        for transactionBackup in backupData.transactions {
            guard let account = accountIdMap[transactionBackup.accountId] else { continue }

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

            modelContext.insert(transaction)
        }

        // Ripristina Settings
        AppSettings.shared.preferredCurrency = backupData.settings.preferredCurrency
        if let theme = ThemeMode(rawValue: backupData.settings.themeMode) {
            AppSettings.shared.themeMode = theme
        }

        try modelContext.save()

        return (
            accounts: backupData.accounts.count,
            transactions: backupData.transactions.count,
            categories: backupData.categories.count
        )
    }

    // MARK: - Helpers

    private func deleteAllData(modelContext: ModelContext) throws {
        // Elimina in ordine per rispettare le relazioni
        try modelContext.delete(model: Transaction.self)
        try modelContext.delete(model: Category.self)
        try modelContext.delete(model: CategoryGroup.self)
        try modelContext.delete(model: Account.self)
    }

    private func convertToBackup(_ account: Account) -> AccountBackup {
        AccountBackup(
            id: account.id.uuidString,
            name: account.name,
            accountType: account.accountType.rawValue,
            currency: account.currency.rawValue,
            initialBalance: "\(account.initialBalance)",
            currentBalance: "\(account.currentBalance)",
            icon: account.icon,
            colorHex: account.colorHex,
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
            date: transaction.date,
            notes: transaction.notes,
            accountId: transaction.account?.id.uuidString ?? "",
            categoryId: transaction.category?.id.uuidString,
            destinationAccountId: transaction.destinationAccount?.id.uuidString
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
            colorHex: categoryGroup.colorHex
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
