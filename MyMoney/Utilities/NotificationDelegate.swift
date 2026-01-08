//
//  NotificationDelegate.swift
//  MoneyTracker
//
//  Created on 2026-01-06.
//

import Foundation
import UserNotifications
import SwiftData

@MainActor
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    var modelContext: ModelContext?

    // MARK: - Handle Notification Response

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        guard let transactionIdString = userInfo["transactionId"] as? String,
              let transactionId = UUID(uuidString: transactionIdString),
              let modelContext = modelContext else {
            print("⚠️ Cannot handle notification: missing transaction ID or context")
            completionHandler()
            return
        }

        print("🔔 Notification tapped: \(response.actionIdentifier)")

        Task { @MainActor in
            // Fetch transaction
            let descriptor = FetchDescriptor<Transaction>(
                predicate: #Predicate { $0.id == transactionId }
            )

            do {
                let transactions = try modelContext.fetch(descriptor)
                guard let transaction = transactions.first else {
                    print("⚠️ Transaction not found")
                    completionHandler()
                    return
                }

                switch response.actionIdentifier {
                case "CONFIRM_ACTION":
                    // User tapped "Conferma"
                    print("✅ User confirmed transaction from notification")
                    await TransactionScheduler.shared.executeTransaction(transaction, modelContext: modelContext)

                case "CANCEL_ACTION":
                    // User tapped "Annulla"
                    print("❌ User cancelled transaction from notification")
                    TransactionScheduler.shared.cancelTransaction(transaction, modelContext: modelContext)

                case UNNotificationDefaultActionIdentifier:
                    // User tapped notification body (not an action button)
                    print("👆 User tapped notification - opening app")
                    // App will open, transaction can be viewed in pending transactions

                    // If automatic transaction, execute it now
                    if let isAutomatic = userInfo["isAutomatic"] as? Bool, isAutomatic {
                        print("⚡️ Auto-executing transaction from notification tap")
                        await TransactionScheduler.shared.executeTransaction(transaction, modelContext: modelContext)
                    }

                default:
                    break
                }

                completionHandler()

            } catch {
                print("❌ Error fetching transaction: \(error)")
                completionHandler()
            }
        }
    }

    // MARK: - Handle Foreground Notification

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        print("🔔 Notification received while app in foreground")
        completionHandler([.banner, .sound, .badge])
    }
}
