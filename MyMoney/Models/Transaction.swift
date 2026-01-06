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

        let symbol = currencyRecord?.symbol ?? currency.symbol
        let amountString = formatter.string(from: amount as NSDecimalNumber) ?? "0.00"
        return "\(symbol)\(amountString)"
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

    var icon: String {
        switch self {
        case .expense: return "arrow.down.circle.fill"
        case .income: return "arrow.up.circle.fill"
        case .transfer: return "arrow.left.arrow.right.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .expense: return "#FF3B30"
        case .income: return "#34C759"
        case .transfer: return "#007AFF"
        }
    }
}
