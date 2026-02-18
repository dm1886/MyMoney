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

        // ⚡️ PERFORMANCE: Filtra solo i template ricorrenti con predicate SwiftData
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { transaction in
                transaction.isRecurring == true &&
                transaction.parentRecurringTransactionId == nil
            }
        )

        do {
            let recurringTemplates = try modelContext.fetch(descriptor)

            LogManager.shared.info("Found \(recurringTemplates.count) recurring transaction templates", category: "RecurringTransactions")

            for template in recurringTemplates {
                await generateInstances(for: template, monthsAhead: monthsAhead, modelContext: modelContext)
            }

            // ⚡️ PERFORMANCE: Singolo save alla fine invece che per ogni template
            try modelContext.save()

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

        // ⚡️ PERFORMANCE: Filtra solo le istanze di questo template con predicate SwiftData
        let templateId = template.id
        let instanceDescriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { transaction in
                transaction.parentRecurringTransactionId == templateId
            },
            sortBy: [SortDescriptor(\.date)]
        )
        let existingInstances = (try? modelContext.fetch(instanceDescriptor)) ?? []

        // Determina da quale data iniziare a generare
        let lastInstanceDate = existingInstances.last?.date

        var generatedCount = 0

        // NON creare la prima istanza se coincide con la data del template
        // perché il template stesso funge da prima istanza (evita duplicati)
        // La prima istanza sarà quella generata dalla ricorrenza successiva

        // Genera le prossime occorrenze
        let startDate = lastInstanceDate ?? firstDate
        var currentDate = startDate
        let includeStartDay = template.includeStartDayInCount

        while let nextDate = rule.nextOccurrence(from: currentDate, includeStartDayInCount: includeStartDay), nextDate <= endDate {
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

        // Se la data dell'istanza è nel passato, eseguila automaticamente
        // (sia automatiche che manuali, per evitare che rimangano invisibili)
        let isPastDate = finalDate < Date()
        if isPastDate {
            instance.status = .executed
            LogManager.shared.info("Auto-executing past recurring instance (date: \(finalDate), automatic: \(template.isAutomatic))", category: "RecurringTransactions")
        } else {
            instance.status = .pending
        }

        // NON è ricorrente (è un'transaziona)
        instance.isRecurring = false

        // Link al parent
        instance.parentRecurringTransactionId = template.id

        // Copy working day adjustment setting
        instance.adjustToWorkingDay = template.adjustToWorkingDay

        // Copy includeStartDayInCount setting
        instance.includeStartDayInCount = template.includeStartDayInCount

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
        let templateId = transaction.parentRecurringTransactionId ?? transaction.id

        switch option {
        case .thisOnly:
            let transactionId = transaction.id
            LocalNotificationManager.shared.cancelNotification(transactionId: transactionId)
            modelContext.delete(transaction)

        case .thisAndFuture:
            // ⚡️ PERFORMANCE: Filtra solo le istanze di questo template
            let thisDate = transaction.date
            let descriptor = FetchDescriptor<Transaction>(
                predicate: #Predicate<Transaction> { t in
                    t.parentRecurringTransactionId == templateId
                }
            )
            let relatedTransactions = (try? modelContext.fetch(descriptor)) ?? []

            for t in relatedTransactions where t.date >= thisDate {
                let tId = t.id
                LocalNotificationManager.shared.cancelNotification(transactionId: tId)
                modelContext.delete(t)
            }

            if transaction.id == templateId {
                modelContext.delete(transaction)
            }

        case .all:
            // ⚡️ PERFORMANCE: Filtra solo le istanze di questo template + il template stesso
            let descriptor = FetchDescriptor<Transaction>(
                predicate: #Predicate<Transaction> { t in
                    t.id == templateId || t.parentRecurringTransactionId == templateId
                }
            )
            let allRelated = (try? modelContext.fetch(descriptor)) ?? []

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
