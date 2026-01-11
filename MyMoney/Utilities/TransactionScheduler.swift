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
        print("📅 Checking scheduled transactions at \(now.formatted(date: .abbreviated, time: .shortened))")

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

            print("📊 Found \(scheduledTransactions.count) pending scheduled transactions")

            for transaction in scheduledTransactions {
                guard let scheduledDate = transaction.scheduledDate else { continue }

                print("⏰ Transaction scheduled for: \(scheduledDate.formatted(date: .abbreviated, time: .shortened))")

                // Check if scheduled time has passed
                if scheduledDate <= now {
                    print("✅ Time has passed! Scheduled: \(scheduledDate), Now: \(now)")

                    if transaction.isAutomatic {
                        // Execute automatically
                        print("⚡️ Executing automatically...")
                        await executeTransaction(transaction, modelContext: modelContext)
                        automaticExecutionCount += 1
                    } else {
                        // Send notification for manual confirmation
                        print("🔔 Sending notification for manual confirmation...")
                        await sendNotification(for: transaction)
                    }
                } else {
                    let timeRemaining = scheduledDate.timeIntervalSince(now)
                    print("⏳ Not yet time. Remaining: \(Int(timeRemaining / 60)) minutes")
                }
            }

            if scheduledTransactions.isEmpty {
                print("📭 No pending scheduled transactions found")
            }
        } catch {
            print("❌ Error checking scheduled transactions: \(error)")
        }

        return automaticExecutionCount
    }

    // MARK: - Execute Transaction

    func executeTransaction(_ transaction: Transaction, modelContext: ModelContext) async {
        print("⚡️ Executing scheduled transaction: \(transaction.id)")
        print("   Type: \(transaction.transactionType.rawValue)")
        print("   Amount: \(transaction.amount)")
        print("   Current status: \(transaction.status.rawValue)")

        // Update status
        transaction.status = .executed

        // Keep the scheduled date as the transaction date (don't change to now)
        if let scheduledDate = transaction.scheduledDate {
            transaction.date = scheduledDate
        } else {
            transaction.date = Date()
        }

        print("   ✏️ Status updated to: \(transaction.status.rawValue)")
        print("   ✏️ Date updated to: \(transaction.date.formatted(date: .abbreviated, time: .shortened))")

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
            print("✅ Transaction executed and saved successfully")
            print("   Final status: \(transaction.status.rawValue)")
        } catch {
            print("❌ Failed to execute transaction: \(error)")
            print("   Error details: \(error.localizedDescription)")
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
