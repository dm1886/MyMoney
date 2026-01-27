//
//  RecurringPatternDetector.swift
//  MoneyTracker
//
//  Created on 2026-01-11.
//

import Foundation
import SwiftData

struct DetectedRecurringPattern: Identifiable {
    let id = UUID()
    let category: Category
    let account: Account
    let averageAmount: Decimal
    let occurrences: Int
    let lastDate: Date
    let transactionType: TransactionType
}

@MainActor
class RecurringPatternDetector {
    static let shared = RecurringPatternDetector()

    private init() {}

    /// Detecta i pattern ricorrenti nelle transazioni
    /// - Parameters:
    ///   - transactions: Lista di tutte le transazioni
    ///   - daysThreshold: Numero di giorni da considerare
    ///   - minOccurrences: Numero minimo di occorrenze per considerare un pattern ricorrente (default: 3)
    /// - Returns: Lista di pattern ricorrenti rilevati
    func detectRecurringPatterns(
        from transactions: [Transaction],
        daysThreshold: Int,
        minOccurrences: Int = 3
    ) -> [DetectedRecurringPattern] {
        let calendar = Calendar.current
        let now = Date()

        // Ottieni l'inizio di oggi (00:00:00)
        let startOfToday = calendar.startOfDay(for: now)

        // Calcola la data di inizio (X giorni fa, ESCLUDENDO oggi)
        guard let startDate = calendar.date(byAdding: .day, value: -daysThreshold, to: startOfToday) else {
            LogManager.shared.debug("❌ RecurringPattern: impossibile calcolare startDate", category: "RecurringPattern")
            return []
        }

        LogManager.shared.debug("🔍 RecurringPattern: Analizzando transazioni dal \(startDate) al \(startOfToday)", category: "RecurringPattern")
        LogManager.shared.debug("🔍 RecurringPattern: Totale transazioni da analizzare: \(transactions.count)", category: "RecurringPattern")
        LogManager.shared.debug("🔍 RecurringPattern: Minimo occorrenze richieste: \(minOccurrences)", category: "RecurringPattern")

        // Get tracker to filter deleted transactions
        let tracker = DeletedTransactionTracker.shared

        // Filtra le transazioni eseguite negli ultimi X giorni ESCLUDENDO oggi
        // In questo modo, se hai fatto N transazioni negli ultimi giorni (senza oggi),
        // ti viene suggerita OGGI MATTINA prima che tu la inserisca
        // CRITICAL: Check tracker FIRST before accessing any transaction properties
        let recentTransactions = transactions.filter { transaction in
            let isDeleted = tracker.isDeleted(transaction.id)
            let hasContext = transaction.modelContext != nil
            let isExecuted = transaction.status == .executed
            let isInDateRange = transaction.date >= startDate && transaction.date < startOfToday
            let isNotScheduled = !transaction.isScheduled

            let passes = !isDeleted && hasContext && isExecuted && isInDateRange && isNotScheduled

            if !passes {
                LogManager.shared.debug("❌ Transazione \(transaction.id): deleted=\(isDeleted) context=\(hasContext) executed=\(isExecuted) inRange=\(isInDateRange) notScheduled=\(isNotScheduled)", category: "RecurringPattern")
            }

            return passes
        }

        LogManager.shared.debug("✅ RecurringPattern: Transazioni filtrate che passano i criteri: \(recentTransactions.count)", category: "RecurringPattern")

        // CRITICAL FIX: Raggruppa per categoria + account + tipo + IMPORTO
        // Questo permette di riconoscere pattern diversi per la stessa categoria ma con importi diversi
        var patterns: [String: [Transaction]] = [:]

        for transaction in recentTransactions {
            guard let category = transaction.category,
                  let account = transaction.account else {
                LogManager.shared.debug("⚠️ Transazione \(transaction.id) saltata: category=\(transaction.category?.name ?? "nil") account=\(transaction.account?.name ?? "nil")", category: "RecurringPattern")
                continue
            }

            // CRITICAL: Includi l'IMPORTO nella chiave di raggruppamento
            let key = "\(category.id.uuidString)_\(account.id.uuidString)_\(transaction.transactionType.rawValue)_\(transaction.amount)"

            if patterns[key] == nil {
                patterns[key] = []
                LogManager.shared.debug("📦 Nuovo pattern creato: \(category.name) su \(account.name) - \(transaction.amount)", category: "RecurringPattern")
            }
            patterns[key]?.append(transaction)
            LogManager.shared.debug("➕ Transazione aggiunta al pattern: \(category.name) \(transaction.amount) - Data: \(transaction.date)", category: "RecurringPattern")
        }

        LogManager.shared.debug("📊 RecurringPattern: Totale gruppi di pattern trovati: \(patterns.count)", category: "RecurringPattern")

        // Filtra solo i pattern con almeno minOccurrences occorrenze
        var detectedPatterns: [DetectedRecurringPattern] = []

        for (key, transactionsGroup) in patterns {
            LogManager.shared.debug("🔎 Analizzando pattern \(key): \(transactionsGroup.count) occorrenze", category: "RecurringPattern")

            guard transactionsGroup.count >= minOccurrences,
                  let firstTransaction = transactionsGroup.first,
                  let category = firstTransaction.category,
                  let account = firstTransaction.account else {
                LogManager.shared.debug("❌ Pattern \(key) scartato: occorrenze=\(transactionsGroup.count) minimo=\(minOccurrences)", category: "RecurringPattern")
                continue
            }

            LogManager.shared.debug("✅ Pattern \(key) VALIDO: \(category.name) - \(firstTransaction.amount) con \(transactionsGroup.count) occorrenze", category: "RecurringPattern")

            // Siccome ora raggruppiamo anche per importo, tutte le transazioni nel gruppo
            // hanno GIÀ lo stesso importo per definizione
            let patternAmount = firstTransaction.amount

            // Trova l'ultima occorrenza
            let lastDate = transactionsGroup.map { $0.date }.max() ?? Date()

            let pattern = DetectedRecurringPattern(
                category: category,
                account: account,
                averageAmount: patternAmount,
                occurrences: transactionsGroup.count,
                lastDate: lastDate,
                transactionType: firstTransaction.transactionType
            )

            detectedPatterns.append(pattern)
        }

        LogManager.shared.debug("🎯 RecurringPattern: TOTALE PATTERN RILEVATI: \(detectedPatterns.count)", category: "RecurringPattern")
        for pattern in detectedPatterns {
            LogManager.shared.debug("   📌 \(pattern.category.name) - \(pattern.averageAmount) \(pattern.account.currency.rawValue) - \(pattern.occurrences) volte", category: "RecurringPattern")
        }

        // Ordina per numero di occorrenze (decrescente)
        return detectedPatterns.sorted { $0.occurrences > $1.occurrences }
    }

    /// Crea una nuova transazione basata su un pattern rilevato
    func createTransactionFromPattern(
        _ pattern: DetectedRecurringPattern,
        modelContext: ModelContext
    ) -> Transaction {
        let transaction = Transaction(
            transactionType: pattern.transactionType,
            amount: pattern.averageAmount,
            currency: pattern.account.currency,
            date: Date(),
            notes: "Transazione ricorrente suggerita",
            account: pattern.account,
            category: pattern.category,
            destinationAccount: nil
        )

        transaction.currencyRecord = pattern.account.currencyRecord
        transaction.status = .executed

        modelContext.insert(transaction)

        // Aggiorna il saldo del conto
        pattern.account.updateBalance(context: modelContext)

        // Registra l'uso della categoria
        pattern.category.recordUsage()

        return transaction
    }
}
