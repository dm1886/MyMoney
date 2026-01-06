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

    func updateBalance(context: ModelContext? = nil) {
        guard let transactions = transactions else {
            currentBalance = initialBalance
            return
        }

        var balance = initialBalance

        for transaction in transactions {
            switch transaction.transactionType {
            case .expense:
                balance -= transaction.amount
            case .income:
                balance += transaction.amount
            case .transfer:
                balance -= transaction.amount
            case .adjustment:
                balance += transaction.amount  // Amount is signed (+ or -)
            }
        }

        if let incoming = incomingTransfers {
            for transfer in incoming {
                if transfer.transactionType == .transfer {
                    // Usa destinationAmount se disponibile (importo manuale o auto-convertito),
                    // altrimenti converti usando CurrencyService
                    var convertedAmount = transfer.amount

                    if let destAmount = transfer.destinationAmount {
                        // Usa l'importo di destinazione salvato
                        convertedAmount = destAmount
                    } else if let ctx = context,
                              let transferCurr = transfer.currencyRecord,
                              let accountCurr = currencyRecord {
                        // Fallback: converti automaticamente
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
        }

        currentBalance = balance
    }
}

enum AccountType: String, Codable, CaseIterable {
    case payment = "Pagamento"
    case cash = "Contanti"
    case creditCard = "Carta di Credito"
    case asset = "Attività"
    case liability = "Passività"

    var icon: String {
        switch self {
        case .payment: return "creditcard.fill"
        case .cash: return "banknote.fill"
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
