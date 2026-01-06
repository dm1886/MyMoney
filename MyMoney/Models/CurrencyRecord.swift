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
}
