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
            return []
        }

        // Get tracker to filter deleted transactions
        let tracker = DeletedTransactionTracker.shared

        // Filtra le transazioni eseguite negli ultimi X giorni ESCLUDENDO oggi
        // In questo modo, se hai fatto N transazioni negli ultimi giorni (senza oggi),
        // ti viene suggerita OGGI MATTINA prima che tu la inserisca
        // CRITICAL: Check tracker FIRST before accessing any transaction properties
        let recentTransactions = transactions.filter { transaction in
            !tracker.isDeleted(transaction.id) &&
            transaction.modelContext != nil &&
            transaction.status == .executed &&
            transaction.date >= startDate &&
            transaction.date < startOfToday &&  // ESCLUDE oggi!
            !transaction.isScheduled  // Esclude transazioni già programmate
        }

        // Raggruppa per categoria + account + tipo
        var patterns: [String: [Transaction]] = [:]

        for transaction in recentTransactions {
            guard let category = transaction.category,
                  let account = transaction.account else {
                continue
            }

            let key = "\(category.id.uuidString)_\(account.id.uuidString)_\(transaction.transactionType.rawValue)"

            if patterns[key] == nil {
                patterns[key] = []
            }
            patterns[key]?.append(transaction)
        }

        // Filtra solo i pattern con almeno minOccurrences occorrenze
        var detectedPatterns: [DetectedRecurringPattern] = []

        for (_, transactionsGroup) in patterns {
            guard transactionsGroup.count >= minOccurrences,
                  let firstTransaction = transactionsGroup.first,
                  let category = firstTransaction.category,
                  let account = firstTransaction.account else {
                continue
            }

            // Trova l'importo PIÙ FREQUENTE invece della media
            // Raggruppa per importo e conta le occorrenze
            var amountFrequency: [Decimal: Int] = [:]
            for transaction in transactionsGroup {
                let amount = transaction.amount
                amountFrequency[amount, default: 0] += 1
            }

            // Trova l'importo con la frequenza più alta
            let mostFrequentAmount = amountFrequency.max { a, b in
                // Se stesso numero di occorrenze, preferisci l'importo più recente
                if a.value == b.value {
                    // Conta le date per determinare quale è più recente
                    let datesA = transactionsGroup.filter { $0.amount == a.key }.map { $0.date }.max() ?? Date.distantPast
                    let datesB = transactionsGroup.filter { $0.amount == b.key }.map { $0.date }.max() ?? Date.distantPast
                    return datesA < datesB
                }
                return a.value < b.value
            }?.key ?? firstTransaction.amount

            // Trova l'ultima occorrenza
            let lastDate = transactionsGroup.map { $0.date }.max() ?? Date()

            let pattern = DetectedRecurringPattern(
                category: category,
                account: account,
                averageAmount: mostFrequentAmount,
                occurrences: transactionsGroup.count,
                lastDate: lastDate,
                transactionType: firstTransaction.transactionType
            )

            detectedPatterns.append(pattern)
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
