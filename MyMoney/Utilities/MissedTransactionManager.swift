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
        LogManager.shared.info("Checking for missed transactions at app launch...", category: "MissedTransactions")

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

            LogManager.shared.info("Found \(missedTransactions.count) missed transactions", category: "MissedTransactions")

            var automaticCount = 0
            var manualCount = 0

            for transaction in missedTransactions {
                if transaction.isAutomatic {
                    // Execute automatic transactions immediately
                    LogManager.shared.info("Auto-executing missed automatic transaction: \(transaction.id)", category: "MissedTransactions")
                    await TransactionScheduler.shared.executeTransaction(transaction, modelContext: modelContext)
                    automaticCount += 1
                } else {
                    // Count manual transactions for alert
                    manualCount += 1
                }
            }

            if automaticCount > 0 {
                LogManager.shared.success("Auto-executed \(automaticCount) missed automatic transactions", category: "MissedTransactions")
            }

            if manualCount > 0 {
                LogManager.shared.warning("Found \(manualCount) missed manual transactions requiring confirmation", category: "MissedTransactions")
            }

            return (automatic: automaticCount, manual: manualCount)

        } catch {
            LogManager.shared.error("Error checking missed transactions: \(error.localizedDescription)", category: "MissedTransactions")
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
