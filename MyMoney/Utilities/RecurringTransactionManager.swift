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

    /// Genera le prossime transazione per tutte le transazioni ricorrenti
    func generateRecurringInstances(modelContext: ModelContext, monthsAhead: Int = 3) async {
        print("🔄 Generating recurring transaction instances...")

        let descriptor = FetchDescriptor<Transaction>()

        do {
            let allTransactions = try modelContext.fetch(descriptor)

            // Trova tutte le transazioni ricorrenti template (parent)
            let recurringTemplates = allTransactions.filter { transaction in
                transaction.isRecurring &&
                transaction.parentRecurringTransactionId == nil  // Solo template, non transazione
            }

            print("📊 Found \(recurringTemplates.count) recurring transaction templates")

            for template in recurringTemplates {
                await generateInstances(for: template, monthsAhead: monthsAhead, modelContext: modelContext)
            }

            try modelContext.save()
            print("✅ Recurring instances generated successfully")

        } catch {
            print("❌ Error generating recurring instances: \(error)")
        }
    }

    /// Genera transazione per una specifica transazione ricorrente
    func generateInstances(
        for template: Transaction,
        monthsAhead: Int,
        modelContext: ModelContext
    ) async {
        guard let rule = template.recurrenceRule,
              let firstScheduledDate = template.scheduledDate else {
            print("⚠️ Template missing recurrence rule or scheduled date")
            return
        }

        // Calcola fino a quale data generare transazione
        let endDate = template.recurrenceEndDate ?? Calendar.current.date(
            byAdding: .month,
            value: monthsAhead,
            to: Date()
        ) ?? Date()

        // Trova l'ultima transaziona già generata
        let descriptor = FetchDescriptor<Transaction>()
        let allTransactions = try? modelContext.fetch(descriptor)

        let existingInstances = allTransactions?.filter {
            $0.parentRecurringTransactionId == template.id
        }.sorted { ($0.scheduledDate ?? Date()) < ($1.scheduledDate ?? Date()) } ?? []

        // Determina da quale data iniziare a generare
        let lastInstanceDate = existingInstances.last?.scheduledDate

        var generatedCount = 0

        if lastInstanceDate == nil {
            // Prima volta - genera anche l'transaziona iniziale (quella di oggi/prima data)
            let alreadyExists = existingInstances.contains { instance in
                guard let instanceDate = instance.scheduledDate else { return false }
                return Calendar.current.isDate(instanceDate, inSameDayAs: firstScheduledDate)
            }

            if !alreadyExists && firstScheduledDate <= endDate {
                createInstance(from: template, scheduledDate: firstScheduledDate, modelContext: modelContext)
                generatedCount += 1
            }
        }

        // Genera le prossime occorrenze
        let startDate = lastInstanceDate ?? firstScheduledDate
        var currentDate = startDate

        while let nextDate = rule.nextOccurrence(from: currentDate), nextDate <= endDate {
            // Controlla se esiste già un'transaziona per questa data
            let alreadyExists = existingInstances.contains { instance in
                guard let instanceDate = instance.scheduledDate else { return false }
                return Calendar.current.isDate(instanceDate, inSameDayAs: nextDate)
            }

            if !alreadyExists {
                createInstance(from: template, scheduledDate: nextDate, modelContext: modelContext)
                generatedCount += 1
            }

            currentDate = nextDate
        }

        if generatedCount > 0 {
            print("   ✅ Generated \(generatedCount) instances for template: \(template.id)")
        }
    }

    /// Crea una singola transaziona da un template
    private func createInstance(
        from template: Transaction,
        scheduledDate: Date,
        modelContext: ModelContext
    ) {
        let instance = Transaction(
            transactionType: template.transactionType,
            amount: template.amount,
            currency: template.currency,
            date: scheduledDate,
            notes: template.notes,
            account: template.account,
            category: template.category,
            destinationAccount: template.destinationAccount
        )

        // Copia valuta SwiftData
        instance.currencyRecord = template.currencyRecord

        // Copia impostazioni programmazione
        instance.isScheduled = true
        instance.scheduledDate = scheduledDate
        instance.isAutomatic = template.isAutomatic
        instance.status = .pending

        // NON è ricorrente (è un'transaziona)
        instance.isRecurring = false

        // Link al parent
        instance.parentRecurringTransactionId = template.id

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

    // MARK: - Delete Recurring Transactions

    func deleteRecurring(
        transaction: Transaction,
        option: RecurringDeletionOption,
        modelContext: ModelContext
    ) {
        print("🗑️ Deleting recurring transaction with option: \(option.rawValue)")

        let descriptor = FetchDescriptor<Transaction>()
        guard let allTransactions = try? modelContext.fetch(descriptor) else { return }

        // Trova il template
        let templateId = transaction.parentRecurringTransactionId ?? transaction.id
        

        switch option {
        case .thisOnly:
            // Elimina solo questa transaziona
            // IMPORTANTE: Salva l'ID PRIMA di eliminare
            let transactionId = transaction.id
            LocalNotificationManager.shared.cancelNotification(transactionId: transactionId)
            modelContext.delete(transaction)
            print("   Deleted single instance: \(transactionId)")

        case .thisAndFuture:
            // Elimina questa transaziona e tutte le future
            let transactionsToDelete = allTransactions.filter { t in
                guard t.parentRecurringTransactionId == templateId,
                      let tDate = t.scheduledDate,
                      let thisDate = transaction.scheduledDate else {
                    return false
                }
                return tDate >= thisDate
            }

            for t in transactionsToDelete {
                // IMPORTANTE: Salva l'ID PRIMA di eliminare
                let tId = t.id
                LocalNotificationManager.shared.cancelNotification(transactionId: tId)
                modelContext.delete(t)
            }

            // Se eliminiamo anche il template, cancellalo
            if transaction.id == templateId {
                modelContext.delete(transaction)
            }

            print("   Deleted \(transactionsToDelete.count) future instances")

        case .all:
            // Elimina tutte le transazione + template
            let allRelated = allTransactions.filter {
                $0.id == templateId || $0.parentRecurringTransactionId == templateId
            }

            for t in allRelated {
                // IMPORTANTE: Salva l'ID PRIMA di eliminare
                let tId = t.id
                LocalNotificationManager.shared.cancelNotification(transactionId: tId)
                modelContext.delete(t)
            }

            print("   Deleted all \(allRelated.count) instances including template")
        }

        try? modelContext.save()
        print("✅ Deletion completed")
    }
}
