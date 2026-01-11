//
//  DatabaseDebugView.swift
//  MoneyTracker
//
//  Created on 2026-01-10.
//

import SwiftUI
import SwiftData

struct DatabaseDebugView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allTransactions: [Transaction]
    @Query private var allAccounts: [Account]
    @Query private var allCategories: [Category]
    @Query private var allCurrencies: [CurrencyRecord]

    var body: some View {
        List {
            Section {
                Text("Total: \(allTransactions.count)")
                    .font(.headline)

                ForEach(Array(allTransactions.enumerated()), id: \.element.id) { index, transaction in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("[\(index)] ID: \(transaction.id.uuidString.prefix(8))...")
                            .font(.caption.monospaced())

                        HStack {
                            Text("Type:")
                                .foregroundStyle(.secondary)
                            Text(transaction.transactionType.rawValue)
                                .bold()
                        }
                        .font(.caption)

                        HStack {
                            Text("Amount:")
                                .foregroundStyle(.secondary)
                            Text("\(transaction.amount as NSDecimalNumber)")
                                .bold()
                        }
                        .font(.caption)

                        HStack {
                            Text("Date:")
                                .foregroundStyle(.secondary)
                            Text(transaction.date.formatted())
                        }
                        .font(.caption)

                        HStack {
                            Text("Status:")
                                .foregroundStyle(.secondary)
                            Text(transaction.status.rawValue)
                                .foregroundStyle(transaction.status == .pending ? .orange : .green)
                        }
                        .font(.caption)

                        if transaction.isScheduled {
                            HStack {
                                Text("⏰ SCHEDULED:")
                                    .foregroundStyle(.orange)
                                    .bold()
                                Text(transaction.scheduledDate?.formatted() ?? "nil")
                            }
                            .font(.caption)

                            HStack {
                                Text("Auto:")
                                    .foregroundStyle(.secondary)
                                Text(transaction.isAutomatic ? "YES" : "NO")
                            }
                            .font(.caption)
                        }

                        if transaction.isRecurring {
                            HStack {
                                Text("🔄 RECURRING TEMPLATE")
                                    .foregroundStyle(.purple)
                                    .bold()
                            }
                            .font(.caption)

                            if let rule = transaction.recurrenceRule {
                                Text("Rule: \(rule.displayString)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if let endDate = transaction.recurrenceEndDate {
                                Text("End: \(endDate.formatted())")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if let parentId = transaction.parentRecurringTransactionId {
                            HStack {
                                Text("🔗 CHILD OF:")
                                    .foregroundStyle(.blue)
                                Text(parentId.uuidString.prefix(8) + "...")
                                    .font(.caption.monospaced())
                            }
                            .font(.caption)
                        }

                        HStack {
                            Text("Account:")
                                .foregroundStyle(.secondary)
                            Text(transaction.account?.name ?? "nil")
                        }
                        .font(.caption)

                        if let category = transaction.category {
                            HStack {
                                Text("Category:")
                                    .foregroundStyle(.secondary)
                                Text(category.name)
                            }
                            .font(.caption)
                        }

                        if !transaction.notes.isEmpty {
                            Text("Notes: \(transaction.notes)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Transactions")
            }

            Section {
                Text("Total: \(allAccounts.count)")
                    .font(.headline)

                ForEach(allAccounts) { account in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(account.name)
                            .font(.headline)

                        HStack {
                            Text("Balance:")
                                .foregroundStyle(.secondary)
                            Text("\(account.currentBalance as NSDecimalNumber)")
                                .bold()
                        }
                        .font(.caption)

                        HStack {
                            Text("Currency:")
                                .foregroundStyle(.secondary)
                            Text(account.currencyRecord?.code ?? "nil")
                        }
                        .font(.caption)

                        HStack {
                            Text("Transactions count:")
                                .foregroundStyle(.secondary)
                            Text("\(account.transactions?.count ?? 0)")
                        }
                        .font(.caption)
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Accounts")
            }

            Section {
                Text("Total: \(allCategories.count)")
                    .font(.headline)

                ForEach(allCategories) { category in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: category.icon)
                                .foregroundStyle(category.color)
                            Text(category.name)
                                .bold()
                        }

                        if let group = category.categoryGroup {
                            HStack {
                                Text("Group:")
                                    .foregroundStyle(.secondary)
                                Text(group.name)
                            }
                            .font(.caption)
                        }

                        HStack {
                            Text("Usage:")
                                .foregroundStyle(.secondary)
                            Text("\(category.usageCount)")
                        }
                        .font(.caption)

                        if let lastUsed = category.lastUsedDate {
                            HStack {
                                Text("Last used:")
                                    .foregroundStyle(.secondary)
                                Text(lastUsed.formatted(date: .abbreviated, time: .omitted))
                            }
                            .font(.caption)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Categories")
            }

            Section {
                Text("Total: \(allCurrencies.count)")
                    .font(.headline)

                ForEach(allCurrencies) { currency in
                    HStack {
                        Text(currency.flagEmoji)
                        Text(currency.code)
                            .bold()
                        Spacer()
                        Text(currency.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Currencies")
            }

            Section {
                Button("Print All to Console") {
                    printDatabaseToConsole()
                }

                Button("Print Scheduled Transactions") {
                    printScheduledTransactions()
                }

                Button("Print Recurring Transactions") {
                    printRecurringTransactions()
                }
            } header: {
                Text("Actions")
            }
        }
        .navigationTitle("Database Debug")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            printDatabaseSummary()
        }
    }

    private func printDatabaseSummary() {
        print("\n")
        print("=" * 80)
        print("DATABASE DEBUG VIEW - SUMMARY")
        print("=" * 80)
        print("📊 Total Transactions: \(allTransactions.count)")
        print("💰 Total Accounts: \(allAccounts.count)")
        print("🏷️  Total Categories: \(allCategories.count)")
        print("💱 Total Currencies: \(allCurrencies.count)")
        print("=" * 80)

        let scheduledCount = allTransactions.filter { $0.isScheduled }.count
        let recurringTemplates = allTransactions.filter { $0.isRecurring && $0.parentRecurringTransactionId == nil }.count
        let recurringInstances = allTransactions.filter { $0.parentRecurringTransactionId != nil }.count
        let pendingCount = allTransactions.filter { $0.status == .pending }.count
        let executedCount = allTransactions.filter { $0.status == .executed }.count

        print("⏰ Scheduled: \(scheduledCount)")
        print("🔄 Recurring Templates: \(recurringTemplates)")
        print("🔗 Recurring Instances: \(recurringInstances)")
        print("⏳ Pending: \(pendingCount)")
        print("✅ Executed: \(executedCount)")
        print("=" * 80)
        print("\n")
    }

    private func printDatabaseToConsole() {
        print("\n")
        print("=" * 80)
        print("COMPLETE DATABASE DUMP")
        print("=" * 80)

        print("\n--- TRANSACTIONS ---")
        for (index, transaction) in allTransactions.enumerated() {
            print("\n[\(index)] Transaction ID: \(transaction.id)")
            print("  Type: \(transaction.transactionType.rawValue)")
            print("  Amount: \(transaction.amount)")
            print("  Date: \(transaction.date)")
            print("  Status: \(transaction.status.rawValue)")
            print("  Account: \(transaction.account?.name ?? "nil")")
            print("  Category: \(transaction.category?.name ?? "nil")")
            print("  Notes: \(transaction.notes)")
            print("  IsScheduled: \(transaction.isScheduled)")
            if transaction.isScheduled {
                print("  ScheduledDate: \(transaction.scheduledDate?.description ?? "nil")")
                print("  IsAutomatic: \(transaction.isAutomatic)")
            }
            print("  IsRecurring: \(transaction.isRecurring)")
            if transaction.isRecurring {
                print("  RecurrenceRule: \(transaction.recurrenceRule?.displayString ?? "nil")")
                print("  RecurrenceEndDate: \(transaction.recurrenceEndDate?.description ?? "nil")")
            }
            if let parentId = transaction.parentRecurringTransactionId {
                print("  ParentRecurringID: \(parentId)")
            }
        }

        print("\n--- ACCOUNTS ---")
        for account in allAccounts {
            print("\nAccount: \(account.name)")
            print("  CurrentBalance: \(account.currentBalance)")
            print("  InitialBalance: \(account.initialBalance)")
            print("  Currency: \(account.currencyRecord?.code ?? "nil")")
            print("  Transactions: \(account.transactions?.count ?? 0)")
        }

        print("\n--- CATEGORIES ---")
        for category in allCategories {
            print("Category: \(category.name)")
            print("  Icon: \(category.icon)")
            print("  Group: \(category.categoryGroup?.name ?? "nil")")
            print("  Usage: \(category.usageCount)")
            print("  Transactions: \(category.transactions?.count ?? 0)")
        }

        print("\n" + "=" * 80)
        print("\n")
    }

    private func printScheduledTransactions() {
        let scheduled = allTransactions.filter { $0.isScheduled }

        print("\n")
        print("=" * 80)
        print("SCHEDULED TRANSACTIONS (\(scheduled.count))")
        print("=" * 80)

        for (index, transaction) in scheduled.enumerated() {
            print("\n[\(index)] ID: \(transaction.id.uuidString.prefix(8))...")
            print("  Amount: \(transaction.amount)")
            print("  ScheduledDate: \(transaction.scheduledDate?.description ?? "nil")")
            print("  Status: \(transaction.status.rawValue)")
            print("  IsAutomatic: \(transaction.isAutomatic)")
            print("  IsRecurring: \(transaction.isRecurring)")
            if let parentId = transaction.parentRecurringTransactionId {
                print("  ParentID: \(parentId.uuidString.prefix(8))...")
            }
        }

        print("\n" + "=" * 80)
        print("\n")
    }

    private func printRecurringTransactions() {
        let templates = allTransactions.filter { $0.isRecurring && $0.parentRecurringTransactionId == nil }
        let instances = allTransactions.filter { $0.parentRecurringTransactionId != nil }

        print("\n")
        print("=" * 80)
        print("RECURRING TRANSACTIONS")
        print("=" * 80)
        print("Templates: \(templates.count)")
        print("Instances: \(instances.count)")
        print("=" * 80)

        print("\n--- TEMPLATES ---")
        for (index, template) in templates.enumerated() {
            print("\n[\(index)] Template ID: \(template.id.uuidString.prefix(8))...")
            print("  Amount: \(template.amount)")
            print("  Rule: \(template.recurrenceRule?.displayString ?? "nil")")
            print("  EndDate: \(template.recurrenceEndDate?.description ?? "nil")")

            let children = instances.filter { $0.parentRecurringTransactionId == template.id }
            print("  Children: \(children.count)")
            for child in children.prefix(5) {
                print("    - \(child.id.uuidString.prefix(8))... @ \(child.scheduledDate?.description ?? "nil")")
            }
            if children.count > 5 {
                print("    ... and \(children.count - 5) more")
            }
        }

        print("\n" + "=" * 80)
        print("\n")
    }
}

private extension String {
    static func *(lhs: String, rhs: Int) -> String {
        String(repeating: lhs, count: rhs)
    }
}
