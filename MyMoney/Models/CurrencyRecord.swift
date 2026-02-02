//
//  CurrencyRecord.swift
//  MoneyTracker
//
//  Created on 2026-01-06.
//

import Foundation
import SwiftData

@Model
final class CurrencyRecord {
    // Primary identifier - unique currency code
    @Attribute(.unique) var code: String  // EUR, USD, MOP, etc.

    // Display properties
    var name: String                      // "Euro", "Dollaro Statunitense", "Pataca Macanese"
    var symbol: String                    // "€", "$", "P"
    var countryCode: String              // "EU", "US", "MO"
    var flagEmoji: String                // "🇪🇺", "🇺🇸", "🇲🇴"

    // Usage tracking (migrated from CurrencyUsageTracker)
    var usageCount: Int = 0
    var lastUsedDate: Date?

    // Metadata
    var isActive: Bool = true            // Allow hiding/deactivating currencies
    var createdAt: Date

    // Relationships with ExchangeRate
    @Relationship(deleteRule: .cascade, inverse: \ExchangeRate.fromCurrency)
    var outgoingRates: [ExchangeRate]?

    @Relationship(deleteRule: .cascade, inverse: \ExchangeRate.toCurrency)
    var incomingRates: [ExchangeRate]?

    init(code: String, name: String, symbol: String, countryCode: String, flagEmoji: String) {
        self.code = code
        self.name = name
        self.symbol = symbol
        self.countryCode = countryCode
        self.flagEmoji = flagEmoji
        self.createdAt = Date()
        self.outgoingRates = []
        self.incomingRates = []
    }

    // MARK: - Computed Properties

    var displayName: String {
        "\(flagEmoji) \(code) - \(name)"
    }

    var isFrequent: Bool {
        usageCount >= 3  // Match CurrencyUsageTracker threshold
    }

    var isRecent: Bool {
        guard let lastUsed = lastUsedDate else { return false }
        return Date().timeIntervalSince(lastUsed) < 30 * 24 * 60 * 60  // 30 days
    }

    /// Returns the appropriate symbol for display
    /// Use "$" only for USD, otherwise use the code for currencies that have "$" in their symbol
    var displaySymbol: String {
        #if DEBUG
        print("🔍 [CurrencyRecord] displaySymbol for \(code):")
        print("   - symbol: '\(symbol)'")
        print("   - symbol.isEmpty: \(symbol.isEmpty)")
        print("   - symbol.contains('$'): \(symbol.contains("$"))")
        #endif

        if code == "USD" {
            #if DEBUG
            print("   ✅ Returning '$' (USD)")
            #endif
            return "$"
        } else if symbol.contains("$") {
            // If symbol contains $ but it's not USD (like "MOP$", "AU$", etc.), use the code
            #if DEBUG
            print("   ⚠️ Symbol contains '$' but not USD - Returning code: '\(code)'")
            #endif
            return code
        } else if !symbol.isEmpty {
            // Use the symbol for other currencies (€, £, ¥, etc.)
            #if DEBUG
            print("   ✅ Returning symbol: '\(symbol)'")
            #endif
            return symbol
        } else {
            // Fallback: use code if symbol is empty
            #if DEBUG
            print("   ⚠️ Fallback - Symbol empty, returning code: '\(code)'")
            #endif
            return code
        }
    }
}
