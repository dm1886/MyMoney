//
//  Transaction.swift
//  MoneyTracker
//
//  Created on 2026-01-01.
//

import Foundation
import SwiftData

@Model
final class Transaction {
    var id: UUID
    var transactionType: TransactionType
    var amount: Decimal
    var currency: Currency              // DEPRECATED: Mantieni per backward compatibility
    var currencyRecord: CurrencyRecord?  // NUOVO: SwiftData relationship
    var date: Date
    var notes: String

    var account: Account?
    var category: Category?
    var destinationAccount: Account?
    var destinationAmount: Decimal?     // Importo nel conto destinazione (per trasferimenti con conversione)

    // MARK: - Scheduled Transaction Fields
    var isScheduled: Bool = false
    var scheduledDate: Date?            // Data di esecuzione programmata
    var isAutomatic: Bool = false       // Se true, esegue automaticamente; se false, richiede conferma
    var status: TransactionStatus = TransactionStatus.executed  // Stato della transazione

    // MARK: - Recurring Transaction Fields
    var isRecurring: Bool = false
    var recurrenceRule: RecurrenceRule?
    var recurrenceEndDate: Date?        // Data fine ripetizione (opzionale)
    var parentRecurringTransactionId: UUID?  // Link alla transazione template se questa è una transazione generata

    init(
        transactionType: TransactionType,
        amount: Decimal,
        currency: Currency,
        date: Date = Date(),
        notes: String = "",
        account: Account? = nil,
        category: Category? = nil,
        destinationAccount: Account? = nil
    ) {
        self.id = UUID()
        self.transactionType = transactionType
        self.amount = amount
        self.currency = currency
        self.date = date
        self.notes = notes
        self.account = account
        self.category = category
        self.destinationAccount = destinationAccount
    }

    var displayAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2

        let code = currencyRecord?.code ?? currency.rawValue
        let amountString = formatter.string(from: amount as NSDecimalNumber) ?? "0.00"
        return "\(code) \(amountString)"
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    // MARK: - Currency Helpers

    /// Helper to get active currency (prefers SwiftData record, falls back to enum)
    var activeCurrency: CurrencyRecord? {
        currencyRecord
    }

    var currencySymbol: String {
        currencyRecord?.symbol ?? currency.symbol
    }

    var currencyCode: String {
        currencyRecord?.code ?? currency.rawValue
    }

    var currencyDisplayName: String {
        currencyRecord?.displayName ?? currency.displayName
    }
}

enum TransactionType: String, Codable {
    case expense = "Uscita"
    case income = "Entrata"
    case transfer = "Trasferimento"
    case adjustment = "Aggiustamento"

    var icon: String {
        switch self {
        case .expense: return "arrow.down.circle.fill"
        case .income: return "arrow.up.circle.fill"
        case .transfer: return "arrow.left.arrow.right.circle.fill"
        case .adjustment: return "slider.horizontal.3"
        }
    }

    var color: String {
        switch self {
        case .expense: return "#FF3B30"
        case .income: return "#34C759"
        case .transfer: return "#007AFF"
        case .adjustment: return "#5856D6"
        }
    }
}

enum TransactionStatus: String, Codable {
    case pending = "Da Confermare"        // Transazione programmata in attesa
    case executed = "Eseguita"            // Transazione eseguita (normale o programmata eseguita)
    case cancelled = "Annullata"          // Transazione programmata annullata
    case failed = "Fallita"               // Esecuzione automatica fallita

    var icon: String {
        switch self {
        case .pending: return "clock.badge.exclamationmark"
        case .executed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    var color: String {
        switch self {
        case .pending: return "#FF9500"    // Orange
        case .executed: return "#34C759"   // Green
        case .cancelled: return "#8E8E93"  // Gray
        case .failed: return "#FF3B30"     // Red
        }
    }
}
