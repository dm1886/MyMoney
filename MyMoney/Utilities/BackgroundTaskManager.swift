//
//  BackgroundTaskManager.swift
//  MoneyTracker
//
//  Created on 2026-01-06.
//

import Foundation
import BackgroundTasks
import SwiftData
import UserNotifications

@MainActor
class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()

    // Background task identifier
    private let scheduledTransactionTaskIdentifier = "com.moneytracker.checkscheduled"

    private init() {}

    // MARK: - Register Background Tasks

    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: scheduledTransactionTaskIdentifier,
            using: nil
        ) { task in
            Task { @MainActor in
                await self.handleScheduledTransactionCheck(task: task as! BGAppRefreshTask)
            }
        }

        print("📋 Background tasks registered")
    }

    // MARK: - Schedule Background Task

    func scheduleBackgroundTask() {
        let request = BGAppRefreshTaskRequest(identifier: scheduledTransactionTaskIdentifier)

        // Schedule for 15 minutes from now (minimum allowed)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ Background task scheduled for: \(request.earliestBeginDate?.formatted(date: .abbreviated, time: .shortened) ?? "unknown")")
        } catch {
            print("❌ Failed to schedule background task: \(error)")
        }
    }

    // MARK: - Handle Background Task

    private func handleScheduledTransactionCheck(task: BGAppRefreshTask) async {
        LogManager.shared.info("Background task started", category: "BackgroundTask")

        // Schedule the next background task
        scheduleBackgroundTask()

        // Create a ModelContext for background work
        let container = try! ModelContainer(for: Account.self, Transaction.self, Category.self, CategoryGroup.self, CurrencyRecord.self, ExchangeRate.self)
        let context = ModelContext(container)

        // Set up task expiration handler
        task.expirationHandler = {
            LogManager.shared.warning("Background task expired before completion", category: "BackgroundTask")
        }

        // Check and execute scheduled transactions
        let executedCount = await TransactionScheduler.shared.checkScheduledTransactionsInBackground(modelContext: context)

        if executedCount > 0 {
            LogManager.shared.success("Executed \(executedCount) transaction(s) in background", category: "BackgroundTask")

            // Update badge count
            await updateBadgeCount(executedCount)

            // Send notification
            await sendBackgroundExecutionNotification(count: executedCount)
        } else {
            LogManager.shared.debug("No transactions executed in background", category: "BackgroundTask")
        }

        // Mark task as completed
        task.setTaskCompleted(success: true)
        LogManager.shared.info("Background task completed. Executed \(executedCount) transactions", category: "BackgroundTask")
    }

    // MARK: - Badge Management

    func updateBadgeCount(_ count: Int) async {
        let center = UNUserNotificationCenter.current()

        do {
            // Get current badge count
            let currentBadge = await getCurrentBadgeCount()
            let newBadge = currentBadge + count

            // Update badge
            try await center.setBadgeCount(newBadge)
            print("🔴 Badge updated to: \(newBadge)")
        } catch {
            print("❌ Failed to update badge: \(error)")
        }
    }

    func clearBadge() async {
        let center = UNUserNotificationCenter.current()

        do {
            try await center.setBadgeCount(0)
            print("✅ Badge cleared")
        } catch {
            print("❌ Failed to clear badge: \(error)")
        }
    }

    private func getCurrentBadgeCount() async -> Int {
        let center = UNUserNotificationCenter.current()

        do {
            let notifications = await center.deliveredNotifications()
            return notifications.count
        } 
    }

    // MARK: - Notifications

    private func sendBackgroundExecutionNotification(count: Int) async {
        let content = UNMutableNotificationContent()
        content.title = "Transazioni Eseguite"
        content.body = count == 1
            ? "1 transazione programmata è stata eseguita automaticamente"
            : "\(count) transazioni programmate sono state eseguite automaticamente"
        content.sound = .default
        content.badge = NSNumber(value: count)
        content.categoryIdentifier = "BACKGROUND_EXECUTION"

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil  // Deliver immediately
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            print("🔔 Background execution notification sent")
        } catch {
            print("❌ Failed to send notification: \(error)")
        }
    }
}
