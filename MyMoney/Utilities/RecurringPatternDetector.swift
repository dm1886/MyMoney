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

        // Calcola la data di inizio (X giorni fa)
        guard let startDate = calendar.date(byAdding: .day, value: -daysThreshold, to: now) else {
            return []
        }

        // Get tracker to filter deleted transactions
        let tracker = DeletedTransactionTracker.shared

        // Filtra le transazioni eseguite negli ultimi X giorni
        // CRITICAL: Check tracker FIRST before accessing any transaction properties
        let recentTransactions = transactions.filter { transaction in
            !tracker.isDeleted(transaction.id) &&
            transaction.modelContext != nil &&
            transaction.status == .executed &&
            transaction.date >= startDate &&
            transaction.date <= now &&
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

            // Calcola la media degli importi
            let totalAmount = transactionsGroup.reduce(Decimal(0)) { sum, transaction in
                sum + transaction.amount
            }
            let averageAmount = totalAmount / Decimal(transactionsGroup.count)

            // Trova l'ultima occorrenza
            let lastDate = transactionsGroup.map { $0.date }.max() ?? Date()

            let pattern = DetectedRecurringPattern(
                category: category,
                account: account,
                averageAmount: averageAmount,
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
