//
//  TransactionScheduler.swift
//  MoneyTracker
//
//  Created on 2026-01-06.
//

import Foundation
import SwiftData
import UserNotifications

@MainActor
class TransactionScheduler {
    static let shared = TransactionScheduler()

    private var checkTimer: Timer?
    private var modelContainer: ModelContainer?

    private init() {}

    // MARK: - Start/Stop Scheduler

    func startScheduler(container: ModelContainer) {
        self.modelContainer = container

        // Check every 5 minutes for scheduled transactions
        checkTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let container = self.modelContainer else { return }
                let context = ModelContext(container)
                await self.checkScheduledTransactions(modelContext: context)
            }
        }

        // Check immediately on start
        Task { @MainActor in
            let context = ModelContext(container)
            await checkScheduledTransactions(modelContext: context)
        }

        print("📅 TransactionScheduler started")
    }

    func stopScheduler() {
        checkTimer?.invalidate()
        checkTimer = nil
        print("📅 TransactionScheduler stopped")
    }

    // MARK: - Check Scheduled Transactions

    func checkScheduledTransactions(modelContext: ModelContext) async {
        _ = await checkScheduledTransactionsInBackground(modelContext: modelContext)
    }

    /// Returns the number of automatic transactions executed
    func checkScheduledTransactionsInBackground(modelContext: ModelContext) async -> Int {
        let now = Date()
        LogManager.shared.info("Checking scheduled transactions at \(now.formatted(date: .abbreviated, time: .shortened))", category: "TransactionScheduler")

        var automaticExecutionCount = 0

        // Query all scheduled transactions (filter in memory)
        let descriptor = FetchDescriptor<Transaction>()

        do {
            let allTransactions = try modelContext.fetch(descriptor)

            // Filter for pending scheduled transactions
            let scheduledTransactions = allTransactions.filter { transaction in
                transaction.isScheduled &&
                transaction.status == .pending &&
                transaction.scheduledDate != nil
            }

            LogManager.shared.info("Found \(scheduledTransactions.count) pending scheduled transactions", category: "TransactionScheduler")

            for transaction in scheduledTransactions {
                guard let scheduledDate = transaction.scheduledDate else { continue }

                // Check if scheduled time has passed
                if scheduledDate <= now {
                    LogManager.shared.info("Time has passed for transaction \(transaction.id). Scheduled: \(scheduledDate), Now: \(now)", category: "TransactionScheduler")

                    if transaction.isAutomatic {
                        // Execute automatically
                        LogManager.shared.info("Executing automatic transaction \(transaction.id)", category: "TransactionScheduler")
                        await executeTransaction(transaction, modelContext: modelContext)
                        automaticExecutionCount += 1
                    } else {
                        // Send notification for manual confirmation
                        LogManager.shared.info("Sending notification for manual confirmation of transaction \(transaction.id)", category: "TransactionScheduler")
                        await sendNotification(for: transaction)
                    }
                }
            }

            if scheduledTransactions.isEmpty {
                LogManager.shared.debug("No pending scheduled transactions found", category: "TransactionScheduler")
            }
        } catch {
            LogManager.shared.error("Error checking scheduled transactions: \(error.localizedDescription)", category: "TransactionScheduler")
        }

        return automaticExecutionCount
    }

    // MARK: - Execute Transaction

    func executeTransaction(_ transaction: Transaction, modelContext: ModelContext) async {
        LogManager.shared.info("Executing scheduled transaction: \(transaction.id) - Type: \(transaction.transactionType.rawValue), Amount: \(transaction.amount)", category: "TransactionScheduler")

        // Update status
        transaction.status = .executed

        // Keep the scheduled date as the transaction date (don't change to now)
        if let scheduledDate = transaction.scheduledDate {
            transaction.date = scheduledDate
        } else {
            transaction.date = Date()
        }

        LogManager.shared.debug("Status updated to: \(transaction.status.rawValue), Date: \(transaction.date.formatted(date: .abbreviated, time: .shortened))", category: "TransactionScheduler")

        // Update account balance
        if let account = transaction.account {
            print("   💰 Updating account balance: \(account.name)")
            account.updateBalance(context: modelContext)
        } else {
            print("   ⚠️ No account associated with transaction")
        }

        if let destinationAccount = transaction.destinationAccount {
            print("   💰 Updating destination account balance: \(destinationAccount.name)")
            destinationAccount.updateBalance(context: modelContext)
        }

        // Record category usage
        if let category = transaction.category {
            print("   📊 Recording category usage: \(category.name)")
            category.recordUsage()
        }

        // Save
        do {
            try modelContext.save()
            LogManager.shared.success("Transaction \(transaction.id) executed and saved successfully. Final status: \(transaction.status.rawValue)", category: "TransactionScheduler")
        } catch {
            LogManager.shared.error("Failed to execute transaction \(transaction.id): \(error.localizedDescription)", category: "TransactionScheduler")
            transaction.status = .failed
            try? modelContext.save()
        }
    }

    // MARK: - Notifications

    func sendNotification(for transaction: Transaction) async {
        let content = UNMutableNotificationContent()
        content.title = "Transazione Programmata"
        content.body = "La transazione '\(transaction.transactionType.rawValue)' di \(transaction.displayAmount) è pronta per essere confermata"
        content.sound = .default
        content.categoryIdentifier = "SCHEDULED_TRANSACTION"
        content.userInfo = ["transactionId": transaction.id.uuidString]

        let request = UNNotificationRequest(
            identifier: transaction.id.uuidString,
            content: content,
            trigger: nil  // Deliver immediately
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            print("🔔 Notification sent for transaction: \(transaction.id)")
        } catch {
            print("❌ Failed to send notification: \(error)")
        }
    }

    // MARK: - Request Notification Permission

    func requestNotificationPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            print(granted ? "✅ Notification permission granted" : "❌ Notification permission denied")
            return granted
        } catch {
            print("❌ Error requesting notification permission: \(error)")
            return false
        }
    }

    // MARK: - Manual Confirmation

    func confirmTransaction(_ transaction: Transaction, modelContext: ModelContext) {
        Task { @MainActor in
            await executeTransaction(transaction, modelContext: modelContext)
        }
    }

    func cancelTransaction(_ transaction: Transaction, modelContext: ModelContext) {
        print("🗑️ Deleting cancelled transaction: \(transaction.id)")

        modelContext.delete(transaction)

        do {
            try modelContext.save()
            print("✅ Transaction deleted")
        } catch {
            print("❌ Failed to delete transaction: \(error)")
        }
    }
}
