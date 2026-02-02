//
//  FormatterCache.swift
//  MoneyTracker
//
//  Created on 2026-01-31.
//

import Foundation

/// Cached formatters for better performance
/// Creating NumberFormatter is expensive - reuse these instances
enum FormatterCache {

    // MARK: - Number Formatters

    /// Italian currency formatter: 1.234,56
    static let italianCurrency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = "."
        formatter.decimalSeparator = ","
        return formatter
    }()

    /// Italian currency with always 2 decimals: 1.234,00
    static let italianCurrencyFixed: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = "."
        formatter.decimalSeparator = ","
        return formatter
    }()

    /// Percentage formatter: 85%
    static let percentage: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    /// Decimal formatter with 2 decimals: 1.23
    static let decimal: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    // MARK: - Date Formatters

    /// Italian date formatter: 31 gen 2026
    static let italianDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateStyle = .medium
        return formatter
    }()

    /// Italian short date: 31/01/26
    static let italianDateShort: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateStyle = .short
        return formatter
    }()

    /// Month abbreviation: gen, feb, mar
    static let monthShort: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateFormat = "MMM"
        return formatter
    }()

    /// Month and year: gennaio 2026
    static let monthYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    // MARK: - Helper Functions

    /// Format a Decimal as Italian currency string
    static func formatCurrency(_ amount: Decimal) -> String {
        return italianCurrency.string(from: amount as NSDecimalNumber) ?? "0"
    }

    /// Format a Decimal as Italian currency with fixed decimals
    static func formatCurrencyFixed(_ amount: Decimal) -> String {
        return italianCurrencyFixed.string(from: amount as NSDecimalNumber) ?? "0,00"
    }

    /// Format a Double as percentage
    static func formatPercentage(_ value: Double) -> String {
        return percentage.string(from: NSNumber(value: value / 100)) ?? "0%"
    }

    /// Format a Decimal with 2 decimals
    static func formatDecimal(_ value: Decimal) -> String {
        return decimal.string(from: value as NSDecimalNumber) ?? "0.00"
    }
}
