//
//  RecurringTransactionManager.swift
//  MoneyTracker
//
//  Created on 2026-01-06.
//

import Foundation
import SwiftData

@MainActor
class RecurringTransactionManager {
    static let shared = RecurringTransactionManager()

    private init() {}

    // MARK: - Generate Recurring Instances

    // Lock per evitare chiamate sovrapposte
    private var isGenerating = false

    /// Genera le prossime transazione per tutte le transazioni ricorrenti
    func generateRecurringInstances(modelContext: ModelContext, monthsAhead: Int = 12) async {
        // Evita chiamate sovrapposte che creerebbero duplicati
        guard !isGenerating else {
            LogManager.shared.warning("Already generating recurring instances, skipping...", category: "RecurringTransactions")
            return
        }

        isGenerating = true
        defer { isGenerating = false }

        LogManager.shared.info("Generating recurring transaction instances...", category: "RecurringTransactions")

        let descriptor = FetchDescriptor<Transaction>()

        do {
            let allTransactions = try modelContext.fetch(descriptor)

            // Trova tutte le transazioni ricorrenti template (parent)
            let recurringTemplates = allTransactions.filter { transaction in
                transaction.isRecurring &&
                transaction.parentRecurringTransactionId == nil  // Solo template, non transazione
            }

            LogManager.shared.info("Found \(recurringTemplates.count) recurring transaction templates", category: "RecurringTransactions")

            for template in recurringTemplates {
                await generateInstances(for: template, monthsAhead: monthsAhead, modelContext: modelContext)
                // Salva dopo ogni template per evitare duplicati da chiamate sovrapposte
                try modelContext.save()
            }

            LogManager.shared.success("Recurring instances generated successfully", category: "RecurringTransactions")

        } catch {
            LogManager.shared.error("Error generating recurring instances: \(error.localizedDescription)", category: "RecurringTransactions")
        }
    }

    /// Genera transazione per una specifica transazione ricorrente
    func generateInstances(
        for template: Transaction,
        monthsAhead: Int,
        modelContext: ModelContext
    ) async {
        guard let rule = template.recurrenceRule else {
            return
        }

        let firstDate = template.date

        // Calcola fino a quale data generare transazione
        let endDate = template.recurrenceEndDate ?? Calendar.current.date(
            byAdding: .month,
            value: monthsAhead,
            to: Date()
        ) ?? Date()

        // Trova l'ultima transaziona già generata (incluse quelle già eseguite)
        let descriptor = FetchDescriptor<Transaction>()
        let allTransactions = try? modelContext.fetch(descriptor)

        // Include TUTTE le istanze: pending, executed, failed, cancelled
        let existingInstances = allTransactions?.filter {
            $0.parentRecurringTransactionId == template.id
        }.sorted { $0.date < $1.date } ?? []

        // Determina da quale data iniziare a generare
        let lastInstanceDate = existingInstances.last?.date

        var generatedCount = 0

        if lastInstanceDate == nil {
            // Prima volta - genera anche l'transaziona iniziale (quella di oggi/prima data)
            let alreadyExists = existingInstances.contains { instance in
                return Calendar.current.isDate(instance.date, inSameDayAs: firstDate)
            }

            if !alreadyExists && firstDate <= endDate {
                createInstance(from: template, forDate: firstDate, modelContext: modelContext)
                generatedCount += 1
            }
        }

        // Genera le prossime occorrenze
        let startDate = lastInstanceDate ?? firstDate
        var currentDate = startDate

        while let nextDate = rule.nextOccurrence(from: currentDate), nextDate <= endDate {
            // Controlla se esiste già un'transaziona per questa data
            let alreadyExists = existingInstances.contains { instance in
                return Calendar.current.isDate(instance.date, inSameDayAs: nextDate)
            }

            if !alreadyExists {
                createInstance(from: template, forDate: nextDate, modelContext: modelContext)
                generatedCount += 1
            }

            currentDate = nextDate
        }

        if generatedCount > 0 {
            LogManager.shared.info("Generated \(generatedCount) instances for recurring template", category: "RecurringTransactions")
        }
    }

    /// Crea una singola transaziona da un template
    private func createInstance(
        from template: Transaction,
        forDate instanceDate: Date,
        modelContext: ModelContext
    ) {
        // Adjust to working day if needed
        var finalDate = instanceDate
        if template.adjustToWorkingDay {
            finalDate = adjustToNextWorkingDay(instanceDate)
        }

        let instance = Transaction(
            transactionType: template.transactionType,
            amount: template.amount,
            currency: template.currency,
            date: finalDate,
            notes: template.notes,
            account: template.account,
            category: template.category,
            destinationAccount: template.destinationAccount
        )

        // Copia valuta SwiftData
        instance.currencyRecord = template.currencyRecord

        // Copia impostazioni programmazione
        instance.isScheduled = true
        instance.isAutomatic = template.isAutomatic
        instance.status = .pending

        // NON è ricorrente (è un'transaziona)
        instance.isRecurring = false

        // Link al parent
        instance.parentRecurringTransactionId = template.id

        // Copy working day adjustment setting
        instance.adjustToWorkingDay = template.adjustToWorkingDay

        // Copia destinationAmount per trasferimenti
        if template.transactionType == .transfer {
            instance.destinationAmount = template.destinationAmount
        }

        modelContext.insert(instance)

        // Schedula notifica locale
        Task {
            await LocalNotificationManager.shared.scheduleNotification(for: instance)
        }
    }

    /// Adjusts a date to the next working day (Monday-Friday) if it falls on a weekend
    private func adjustToNextWorkingDay(_ date: Date) -> Date {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)

        // In Calendar: 1 = Sunday, 7 = Saturday
        switch weekday {
        case 1:  // Sunday -> Monday (+1 day)
            return calendar.date(byAdding: .day, value: 1, to: date) ?? date
        case 7:  // Saturday -> Monday (+2 days)
            return calendar.date(byAdding: .day, value: 2, to: date) ?? date
        default:
            return date  // Already a weekday
        }
    }

    // MARK: - Delete Recurring Transactions

    func deleteRecurring(
        transaction: Transaction,
        option: RecurringDeletionOption,
        modelContext: ModelContext
    ) {
        let descriptor = FetchDescriptor<Transaction>()
        guard let allTransactions = try? modelContext.fetch(descriptor) else { return }

        let templateId = transaction.parentRecurringTransactionId ?? transaction.id

        switch option {
        case .thisOnly:
            let transactionId = transaction.id
            LocalNotificationManager.shared.cancelNotification(transactionId: transactionId)
            modelContext.delete(transaction)

        case .thisAndFuture:
            let thisDate = transaction.date
            let transactionsToDelete = allTransactions.filter { t in
                guard t.parentRecurringTransactionId == templateId else {
                    return false
                }
                return t.date >= thisDate
            }

            for t in transactionsToDelete {
                let tId = t.id
                LocalNotificationManager.shared.cancelNotification(transactionId: tId)
                modelContext.delete(t)
            }

            if transaction.id == templateId {
                modelContext.delete(transaction)
            }

        case .all:
            let allRelated = allTransactions.filter {
                $0.id == templateId || $0.parentRecurringTransactionId == templateId
            }

            for t in allRelated {
                let tId = t.id
                LocalNotificationManager.shared.cancelNotification(transactionId: tId)
                modelContext.delete(t)
            }
        }

        try? modelContext.save()
        LogManager.shared.info("Recurring transaction deleted with option: \(option.rawValue)", category: "RecurringTransactions")
    }
}
