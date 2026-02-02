//
//  Account.swift
//  MoneyTracker
//
//  Created on 2026-01-01.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class Account {
    var id: UUID
    var name: String
    var accountType: AccountType
    var currency: Currency              // DEPRECATED: Mantieni per backward compatibility
    var currencyRecord: CurrencyRecord?  // NUOVO: SwiftData relationship
    var initialBalance: Decimal
    var currentBalance: Decimal
    var creditLimit: Decimal?            // For credit card accounts
    var icon: String
    var colorHex: String
    var imageData: Data?
    var accountDescription: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Transaction.account)
    var transactions: [Transaction]?

    @Relationship(deleteRule: .nullify, inverse: \Transaction.destinationAccount)
    var incomingTransfers: [Transaction]?

    @Relationship(deleteRule: .nullify, inverse: \Category.defaultAccount)
    var defaultCategories: [Category]?

    init(
        name: String,
        accountType: AccountType,
        currency: Currency,
        initialBalance: Decimal = 0,
        creditLimit: Decimal? = nil,
        icon: String = "creditcard.fill",
        colorHex: String = "#007AFF",
        imageData: Data? = nil,
        accountDescription: String = ""
    ) {
        self.id = UUID()
        self.name = name
        self.accountType = accountType
        self.currency = currency
        self.initialBalance = initialBalance
        self.currentBalance = initialBalance
        self.creditLimit = creditLimit
        self.icon = icon
        self.colorHex = colorHex
        self.imageData = imageData
        self.accountDescription = accountDescription
        self.createdAt = Date()
        self.transactions = []
        self.incomingTransfers = []
        self.defaultCategories = []
    }

    var color: Color {
        Color(hex: colorHex) ?? .blue
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

    @MainActor func updateBalance(context: ModelContext? = nil) {
        guard let transactions = transactions else {
            currentBalance = initialBalance
            return
        }

        var balance = initialBalance
        let tracker = DeletedTransactionTracker.shared

        // Only count EXECUTED transactions (not pending, cancelled, or failed)
        for transaction in transactions {
            // Check tracker FIRST (by ID only - safe)
            guard !tracker.isDeleted(transaction.id) else { continue }

            // Check modelContext SECOND before accessing ANY other property
            guard transaction.modelContext != nil else { continue }

            guard transaction.status == .executed else { continue }

            // Determina l'importo da usare in base al tipo di transazione
            var amountToUse = transaction.amount

            // Per TRANSFER: usa sempre transaction.amount (importo originale nella valuta di origine)
            // destinationAmount è solo per il conto di destinazione (gestito in incomingTransfers)
            if transaction.transactionType != .transfer {
                // Per expense/income/adjustment: usa destinationAmount se presente (conversione)
                if let destAmount = transaction.destinationAmount {
                    amountToUse = destAmount
                } else if let ctx = context,
                          let transactionCurr = transaction.currencyRecord,
                          let accountCurr = currencyRecord,
                          transactionCurr.code != accountCurr.code {
                    amountToUse = CurrencyService.shared.convert(
                        amount: transaction.amount,
                        from: transactionCurr,
                        to: accountCurr,
                        context: ctx
                    )
                }
            }

            switch transaction.transactionType {
            case .expense:
                balance -= amountToUse
            case .income:
                balance += amountToUse
            case .transfer:
                balance -= amountToUse
            case .adjustment:
                balance += amountToUse
            }
        }

        // Add incoming transfers (only executed)
        if let incoming = incomingTransfers {
            for transfer in incoming {
                guard !tracker.isDeleted(transfer.id) else { continue }
                guard transfer.modelContext != nil else { continue }
                guard transfer.status == .executed else { continue }
                guard transfer.transactionType == .transfer else { continue }

                var convertedAmount = transfer.amount

                if let destAmount = transfer.destinationAmount {
                    convertedAmount = destAmount
                } else if let snapshot = transfer.exchangeRateSnapshot {
                    // Usa snapshot del tasso se disponibile (preserva calcoli storici)
                    convertedAmount = transfer.amount * snapshot
                } else if let ctx = context,
                          let transferCurr = transfer.currencyRecord,
                          let accountCurr = currencyRecord {
                    convertedAmount = CurrencyService.shared.convert(
                        amount: transfer.amount,
                        from: transferCurr,
                        to: accountCurr,
                        context: ctx
                    )
                }

                balance += convertedAmount
            }
        }

        currentBalance = balance
    }
}

enum AccountType: String, Codable, CaseIterable {
    case payment = "Pagamento"
    case cash = "Contanti"
    case prepaidCard = "Carta Prepagata"
    case creditCard = "Carta di Credito"
    case asset = "Attività"
    case liability = "Passività"

    var icon: String {
        switch self {
        case .payment: return "creditcard.fill"
        case .cash: return "banknote.fill"
        case .prepaidCard: return "creditcard.fill"
        case .creditCard: return "creditcard.fill"
        case .asset: return "building.columns.fill"
        case .liability: return "chart.line.downtrend.xyaxis"
        }
    }
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }

    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components,
              components.count >= 3 else {
            return nil
        }

        let r = Int(components[0] * 255.0)
        let g = Int(components[1] * 255.0)
        let b = Int(components[2] * 255.0)

        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
