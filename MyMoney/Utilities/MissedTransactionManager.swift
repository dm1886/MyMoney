//
//  MissedTransactionManager.swift
//  MoneyTracker
//
//  Created on 2026-01-06.
//

import Foundation
import SwiftData

@MainActor
class MissedTransactionManager {
    static let shared = MissedTransactionManager()

    private init() {}

    // MARK: - Check for Missed Transactions on App Launch

    func checkMissedTransactions(modelContext: ModelContext) async -> (automatic: Int, manual: Int) {
        let now = Date()
        print("🔍 Checking for missed transactions at app launch...")

        let descriptor = FetchDescriptor<Transaction>()

        do {
            let allTransactions = try modelContext.fetch(descriptor)

            // Filter for pending scheduled transactions that are overdue
            let missedTransactions = allTransactions.filter { transaction in
                guard let scheduledDate = transaction.scheduledDate else { return false }
                return transaction.isScheduled &&
                       transaction.status == .pending &&
                       scheduledDate < now
            }

            print("📊 Found \(missedTransactions.count) missed transactions")

            var automaticCount = 0
            var manualCount = 0

            for transaction in missedTransactions {
                if transaction.isAutomatic {
                    // Execute automatic transactions immediately
                    print("⚡️ Auto-executing missed automatic transaction: \(transaction.id)")
                    await TransactionScheduler.shared.executeTransaction(transaction, modelContext: modelContext)
                    automaticCount += 1
                } else {
                    // Count manual transactions for alert
                    manualCount += 1
                }
            }

            if automaticCount > 0 {
                print("✅ Auto-executed \(automaticCount) missed automatic transactions")
            }

            if manualCount > 0 {
                print("⏳ Found \(manualCount) missed manual transactions requiring confirmation")
            }

            return (automatic: automaticCount, manual: manualCount)

        } catch {
            print("❌ Error checking missed transactions: \(error)")
            return (0, 0)
        }
    }

    // MARK: - Get Overdue Manual Transactions

    func getOverdueManualTransactions(modelContext: ModelContext) -> [Transaction] {
        let now = Date()
        let descriptor = FetchDescriptor<Transaction>()

        do {
            let allTransactions = try modelContext.fetch(descriptor)

            return allTransactions.filter { transaction in
                guard let scheduledDate = transaction.scheduledDate else { return false }
                return transaction.isScheduled &&
                       transaction.status == .pending &&
                       !transaction.isAutomatic &&
                       scheduledDate < now
            }
        } catch {
            print("❌ Error fetching overdue manual transactions: \(error)")
            return []
        }
    }
}
