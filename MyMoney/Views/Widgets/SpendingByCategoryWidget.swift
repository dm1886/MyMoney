//
//  SpendingByCategoryWidget.swift
//  MoneyTracker
//
//  Created on 2026-01-27.
//

import SwiftUI
import SwiftData
import Charts

struct SpendingByCategoryWidget: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appSettings) var appSettings

    // PERFORMANCE: Accept data as parameters instead of @Query
    let transactions: [Transaction]
    let categories: [Category]
    let allCurrencies: [CurrencyRecord]

    @State private var selectedPeriod: SpendingPeriod = .month

    enum SpendingPeriod: String, CaseIterable {
        case today = "Oggi"
        case yesterday = "Ieri"
        case month = "Mese"
        case year = "Anno"
    }

    var preferredCurrencyRecord: CurrencyRecord? {
        allCurrencies.first { $0.code == appSettings.preferredCurrencyEnum.rawValue }
    }

    var categorySpending: [(category: Category, amount: Decimal, percentage: Double)] {
        guard let preferredCurrency = preferredCurrencyRecord else { return [] }

        let calendar = Calendar.current
        let now = Date()

        let (startDate, endDate) = getDateRange(for: selectedPeriod, calendar: calendar, now: now)
        guard let start = startDate, let end = endDate else { return [] }

        let tracker = DeletedTransactionTracker.shared
        let periodTransactions = transactions.filter { transaction in
            guard !tracker.isDeleted(transaction.id) else { return false }
            guard transaction.modelContext != nil else { return false }
            return transaction.date >= start &&
                   transaction.date <= end &&
                   transaction.transactionType == .expense &&
                   transaction.status == .executed
        }

        var categoryTotals: [UUID: Decimal] = [:]

        for transaction in periodTransactions {
            guard let category = transaction.category,
                  let transactionCurrency = transaction.currencyRecord else { continue }

            let converted = CurrencyService.shared.convert(
                amount: transaction.amount,
                from: transactionCurrency,
                to: preferredCurrency,
                context: modelContext
            )

            categoryTotals[category.id, default: 0] += converted
        }

        let total = categoryTotals.values.reduce(0, +)
        guard total > 0 else { return [] }

        return categoryTotals.compactMap { (id, amount) in
            guard let category = categories.first(where: { $0.id == id }) else { return nil }
            let percentage = Double(truncating: amount as NSDecimalNumber) / Double(truncating: total as NSDecimalNumber)
            return (category, amount, percentage)
        }
        .sorted { $0.amount > $1.amount }
        .map { $0 }
    }

    private func getDateRange(for period: SpendingPeriod, calendar: Calendar, now: Date) -> (start: Date?, end: Date?) {
        switch period {
        case .today:
            let start = calendar.startOfDay(for: now)
            return (start, now)
        case .yesterday:
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else { return (nil, nil) }
            let start = calendar.startOfDay(for: yesterday)
            let end = calendar.date(byAdding: .day, value: 1, to: start)
            return (start, end)
        case .month:
            guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else { return (nil, nil) }
            return (startOfMonth, now)
        case .year:
            guard let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now)) else { return (nil, nil) }
            return (startOfYear, now)
        }
    }

    var body: some View {
        OrbCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Spese per categoria").font(.orbHeadline).lineLimit(1)
                OrbCompactPeriod(values: SpendingPeriod.allCases, selection: $selectedPeriod)
                OrbDonutChart(slices: categorySpending.map { OrbCategorySlice(id: $0.category.id.uuidString, name: $0.category.name, amount: NSDecimalNumber(decimal: $0.amount).doubleValue, color: $0.category.color) }, symbol: preferredCurrencyRecord?.displaySymbol ?? "€")
            }
        }
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let symbol = preferredCurrencyRecord?.displaySymbol ?? "$"

        return "\(symbol) \(FormatterCache.formatCurrencyFixed(amount))"
    }
}
