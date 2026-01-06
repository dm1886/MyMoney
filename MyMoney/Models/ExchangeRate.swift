//
//  ExchangeRate.swift
//  MoneyTracker
//
//  Created on 2026-01-06.
//

import Foundation
import SwiftData

@Model
final class ExchangeRate {
    var id: UUID

    // Relationships
    var fromCurrency: CurrencyRecord?
    var toCurrency: CurrencyRecord?

    // Exchange rate value
    var rate: Decimal

    // Metadata
    var lastUpdated: Date
    var source: RateSource      // manual, api, default
    var isCustom: Bool          // User manually edited

    init(fromCurrency: CurrencyRecord, toCurrency: CurrencyRecord, rate: Decimal, source: RateSource = .default) {
        self.id = UUID()
        self.fromCurrency = fromCurrency
        self.toCurrency = toCurrency
        self.rate = rate
        self.lastUpdated = Date()
        self.source = source
        self.isCustom = (source == .manual)
    }

    // MARK: - Computed Properties

    var displayRate: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 6
        return formatter.string(from: rate as NSDecimalNumber) ?? "0.00"
    }
}

// MARK: - Rate Source Enum

enum RateSource: String, Codable {
    case manual = "Manual"
    case api = "API"
    case `default` = "Default"
}
