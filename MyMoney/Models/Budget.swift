//
//  Budget.swift
//  MoneyTracker
//
//  Created on 2026-01-08.
//

import Foundation
import SwiftData

enum BudgetPeriod: String, Codable, CaseIterable {
    case weekly = "Settimanale"
    case monthly = "Mensile"
    case yearly = "Annuale"
    case custom = "Personalizzato"
}

@Model
final class Budget {
    var id: UUID
    var amount: Decimal
    var period: BudgetPeriod
    var currencyRecord: CurrencyRecord?
    var startDate: Date
    var endDate: Date?  // nil = nessuna scadenza
    var isActive: Bool
    var createdAt: Date

    // Relazione con categoria
    var category: Category?

    // Notifiche
    var alertAt80Percent: Bool  // Alert quando raggiunge 80%
    var alertAt100Percent: Bool  // Alert quando supera il budget

    init(
        amount: Decimal,
        period: BudgetPeriod,
        currencyRecord: CurrencyRecord?,
        startDate: Date = Date(),
        endDate: Date? = nil,
        category: Category? = nil
    ) {
        self.id = UUID()
        self.amount = amount
        self.period = period
        self.currencyRecord = currencyRecord
        self.startDate = startDate
        self.endDate = endDate
        self.category = category
        self.isActive = true
        self.createdAt = Date()
        self.alertAt80Percent = true
        self.alertAt100Percent = true
    }

    // MARK: - Computed Properties

    /// Calcola la data di inizio del periodo corrente
    var currentPeriodStart: Date {
        let calendar = Calendar.current
        let now = Date()

        // Se abbiamo una endDate e siamo oltre, ritorna startDate
        if let endDate = endDate, now > endDate {
            return startDate
        }

        switch period {
        case .weekly:
            return calendar.startOfWeek(for: now) ?? now
        case .monthly:
            return calendar.startOfMonth(for: now) ?? now
        case .yearly:
            return calendar.startOfYear(for: now) ?? now
        case .custom:
            return startDate
        }
    }

    /// Calcola la data di fine del periodo corrente
    var currentPeriodEnd: Date {
        let calendar = Calendar.current
        let now = Date()

        // Se abbiamo una endDate specifica, usa quella
        if let endDate = endDate {
            return endDate
        }

        switch period {
        case .weekly:
            return calendar.endOfWeek(for: now) ?? now
        case .monthly:
            return calendar.endOfMonth(for: now) ?? now
        case .yearly:
            return calendar.endOfYear(for: now) ?? now
        case .custom:
            // Per custom senza endDate, usa 30 giorni dalla startDate
            return calendar.date(byAdding: .day, value: 30, to: startDate) ?? startDate
        }
    }

    /// Calcola quanto è stato speso nel periodo corrente
    func spent(transactions: [Transaction], context: ModelContext) -> Decimal {
        guard let category = category else { return 0 }
        guard let budgetCurrency = currencyRecord else { return 0 }

        let periodTransactions = transactions.filter { transaction in
            guard transaction.category?.id == category.id else { return false }
            guard transaction.transactionType == .expense else { return false }
            guard transaction.status == .executed else { return false }

            let transactionDate = transaction.date
            return transactionDate >= currentPeriodStart && transactionDate <= currentPeriodEnd
        }

        return periodTransactions.reduce(0) { sum, transaction in
            guard let transactionCurrency = transaction.currencyRecord else { return sum }

            let convertedAmount = CurrencyService.shared.convert(
                amount: transaction.amount,
                from: transactionCurrency,
                to: budgetCurrency,
                context: context
            )

            return sum + convertedAmount
        }
    }

    /// Percentuale del budget utilizzata
    func percentageUsed(transactions: [Transaction], context: ModelContext) -> Double {
        guard amount > 0 else { return 0 }
        let spentAmount = spent(transactions: transactions, context: context)
        return Double(truncating: (spentAmount / amount) as NSNumber) * 100
    }

    /// Importo rimanente
    func remaining(transactions: [Transaction], context: ModelContext) -> Decimal {
        return amount - spent(transactions: transactions, context: context)
    }

    /// Budget è stato superato?
    func isExceeded(transactions: [Transaction], context: ModelContext) -> Bool {
        return spent(transactions: transactions, context: context) > amount
    }
}

// MARK: - Calendar Extensions

extension Calendar {
    func startOfWeek(for date: Date) -> Date? {
        var calendar = self
        calendar.firstWeekday = 2 // Lunedì
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components)
    }

    func endOfWeek(for date: Date) -> Date? {
        guard let startOfWeek = startOfWeek(for: date) else { return nil }
        return self.date(byAdding: .day, value: 6, to: startOfWeek)
    }

    func startOfMonth(for date: Date) -> Date? {
        let components = self.dateComponents([.year, .month], from: date)
        return self.date(from: components)
    }

    func endOfMonth(for date: Date) -> Date? {
        guard let startOfMonth = startOfMonth(for: date) else { return nil }
        return self.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)
    }

    func startOfYear(for date: Date) -> Date? {
        let components = self.dateComponents([.year], from: date)
        return self.date(from: components)
    }

    func endOfYear(for date: Date) -> Date? {
        guard let startOfYear = startOfYear(for: date) else { return nil }
        return self.date(byAdding: DateComponents(year: 1, day: -1), to: startOfYear)
    }
}
