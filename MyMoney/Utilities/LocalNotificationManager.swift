//
//  LocalNotificationManager.swift
//  MoneyTracker
//
//  Created on 2026-01-06.
//

import Foundation
import UserNotifications
import SwiftUI

@MainActor
class LocalNotificationManager: NSObject {
    static let shared = LocalNotificationManager()

    private override init() {
        super.init()
    }

    // MARK: - Setup Notification Categories

    func setupNotificationCategories() {
        let center = UNUserNotificationCenter.current()

        // Category for manual transactions with action buttons
        let confirmAction = UNNotificationAction(
            identifier: "CONFIRM_ACTION",
            title: "Conferma",
            options: [.foreground]
        )

        let cancelAction = UNNotificationAction(
            identifier: "CANCEL_ACTION",
            title: "Annulla",
            options: [.destructive]
        )

        let manualCategory = UNNotificationCategory(
            identifier: "MANUAL_TRANSACTION",
            actions: [confirmAction, cancelAction],
            intentIdentifiers: [],
            options: []
        )

        // Category for automatic transactions (no actions)
        let automaticCategory = UNNotificationCategory(
            identifier: "AUTOMATIC_TRANSACTION",
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([manualCategory, automaticCategory])
        print("✅ Notification categories configured")
    }

    // MARK: - Schedule Notification

    func scheduleNotification(for transaction: Transaction) async {
        guard transaction.isScheduled,
              let scheduledDate = transaction.scheduledDate,
              scheduledDate > Date() else {
            print("⚠️ Cannot schedule notification: invalid date or already passed")
            return
        }

        let content = UNMutableNotificationContent()

        if transaction.isAutomatic {
            // Automatic transaction notification
            content.title = "Transazione Programmata"
            content.body = "La transazione '\(transaction.category?.name ?? transaction.transactionType.rawValue)' di \(transaction.displayAmount) verrà eseguita automaticamente."
            content.categoryIdentifier = "AUTOMATIC_TRANSACTION"
            content.sound = .default
        } else {
            // Manual transaction notification
            content.title = "Conferma Transazione"
            content.body = "È il momento di confermare la transazione '\(transaction.category?.name ?? transaction.transactionType.rawValue)' di \(transaction.displayAmount)."
            content.categoryIdentifier = "MANUAL_TRANSACTION"
            content.sound = .default
        }

        // Add transaction ID to userInfo for handling
        content.userInfo = [
            "transactionId": transaction.id.uuidString,
            "isAutomatic": transaction.isAutomatic
        ]

        // Create trigger for specific date/time
        let dateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: scheduledDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        // Create request
        let request = UNNotificationRequest(
            identifier: transaction.id.uuidString,
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            print("🔔 Local notification scheduled for \(scheduledDate.formatted(date: .abbreviated, time: .shortened))")
            print("   Transaction: \(transaction.category?.name ?? transaction.transactionType.rawValue)")
            print("   Amount: \(transaction.displayAmount)")
        } catch {
            print("❌ Failed to schedule notification: \(error)")
        }
    }

    // MARK: - Cancel Notification

    func cancelNotification(for transaction: Transaction) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [transaction.id.uuidString])
        print("🗑️ Cancelled notification for transaction: \(transaction.id)")
    }

    // Versione che accetta solo l'ID per evitare problemi di "detached context"
    func cancelNotification(transactionId: UUID) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [transactionId.uuidString])
        print("🗑️ Cancelled notification for transaction: \(transactionId)")
    }

    // MARK: - Update Notification

    func updateNotification(for transaction: Transaction) async {
        // Cancel existing notification
        cancelNotification(for: transaction)

        // Schedule new notification if still valid
        if transaction.isScheduled && transaction.status == .pending {
            await scheduleNotification(for: transaction)
        }
    }

    // MARK: - Request Permission

    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            print(granted ? "✅ Local notification permission granted" : "❌ Local notification permission denied")
            return granted
        } catch {
            print("❌ Error requesting notification permission: \(error)")
            return false
        }
    }

    // MARK: - Check Pending Notifications (Debug)

    func listPendingNotifications() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()

        print("📋 Pending local notifications: \(pending.count)")
        for notification in pending {
            if let trigger = notification.trigger as? UNCalendarNotificationTrigger,
               let nextTriggerDate = trigger.nextTriggerDate() {
                print("   - \(notification.identifier): \(nextTriggerDate.formatted(date: .abbreviated, time: .shortened))")
            }
        }
    }

    // MARK: - Clear All Notifications

    func cancelAllNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        print("🗑️ All pending notifications cancelled")
    }

    // MARK: - Clean Orphan Notifications

    func cleanOrphanNotifications(validTransactionIds: Set<UUID>) async -> Int {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()

        var orphanCount = 0
        var orphanIds: [String] = []

        for notification in pending {
            if let uuid = UUID(uuidString: notification.identifier) {
                // Se l'ID della notifica non corrisponde a nessuna transazione valida
                if !validTransactionIds.contains(uuid) {
                    orphanIds.append(notification.identifier)
                    orphanCount += 1
                }
            }
        }

        if !orphanIds.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: orphanIds)
            print("🧹 Cleaned \(orphanCount) orphan notifications")
            for id in orphanIds {
                print("   - Removed: \(id)")
            }
        } else {
            print("✅ No orphan notifications found")
        }

        return orphanCount
    }
}
