//
//  TopCategoriesWidget.swift
//  MoneyTracker
//
//  Created on 2026-01-27.
//

import SwiftUI
import SwiftData

struct TopCategoriesWidget: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appSettings) var appSettings

    // PERFORMANCE: Accept data as parameters instead of @Query
    let transactions: [Transaction]
    let categories: [Category]
    let allCurrencies: [CurrencyRecord]

    var preferredCurrencyRecord: CurrencyRecord? {
        allCurrencies.first { $0.code == appSettings.preferredCurrencyEnum.rawValue }
    }

    var topCategories: [(category: Category, amount: Decimal, count: Int)] {
        guard let preferredCurrency = preferredCurrencyRecord else { return [] }

        let calendar = Calendar.current
        let now = Date()
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else { return [] }

        let tracker = DeletedTransactionTracker.shared
        let monthTransactions = transactions.filter { transaction in
            guard !tracker.isDeleted(transaction.id) else { return false }
            guard transaction.modelContext != nil else { return false }
            return transaction.date >= startOfMonth &&
                   transaction.date <= now &&
                   transaction.transactionType == .expense &&
                   transaction.status == .executed
        }

        var categoryTotals: [UUID: (amount: Decimal, count: Int)] = [:]

        for transaction in monthTransactions {
            guard let category = transaction.category,
                  let transactionCurrency = transaction.currencyRecord else { continue }

            let converted = CurrencyService.shared.convert(
                amount: transaction.amount,
                from: transactionCurrency,
                to: preferredCurrency,
                context: modelContext
            )

            let current = categoryTotals[category.id] ?? (amount: 0, count: 0)
            categoryTotals[category.id] = (amount: current.amount + converted, count: current.count + 1)
        }

        return categoryTotals.compactMap { (id, data) in
            guard let category = categories.first(where: { $0.id == id }) else { return nil }
            return (category, data.amount, data.count)
        }
        .sorted { $0.amount > $1.amount }
        .prefix(5)
        .map { $0 }
    }

    var body: some View {
        OrbCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Top categorie").font(.orbHeadline).lineLimit(1)
                if topCategories.isEmpty { Text("Nessuna spesa nel periodo").font(.orbSubheadline).foregroundStyle(Color.orbMuted) }
                OrbRankedBars(slices: topCategories.map { OrbCategorySlice(id: $0.category.id.uuidString, name: $0.category.name, amount: NSDecimalNumber(decimal: $0.amount).doubleValue, color: $0.category.color) }, symbol: preferredCurrencyRecord?.displaySymbol ?? "€")
            }
        }
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let symbol = preferredCurrencyRecord?.displaySymbol ?? "$"

        return "\(symbol) \(FormatterCache.formatCurrencyFixed(amount))"
    }
}
