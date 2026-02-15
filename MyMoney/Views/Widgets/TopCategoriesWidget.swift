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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.number")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Top Categorie")
                    .font(.headline.bold())
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Spacer()

                Text("Questo Mese")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            if topCategories.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)

                    Text("Nessuna spesa questo mese")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(topCategories.enumerated()), id: \.offset) { index, item in
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.title3.bold())
                                .foregroundStyle(.tertiary)
                                .frame(width: 24)

                            ZStack {
                                Circle()
                                    .fill(item.category.color.opacity(0.15))
                                    .frame(width: 36, height: 36)

                                Image(systemName: item.category.icon)
                                    .font(.caption)
                                    .foregroundStyle(item.category.color)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.category.name)
                                    .font(.body.bold())
                                    .foregroundStyle(.primary)

                                Text("\(item.count) transazioni")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text(formatAmount(item.amount))
                                .font(.body.bold())
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: .rect(cornerRadius: 16))
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let symbol = preferredCurrencyRecord?.displaySymbol ?? "$"
        let flag = preferredCurrencyRecord?.flagEmoji ?? ""
        return "\(symbol)\(FormatterCache.formatCurrency(amount)) \(flag)"
    }
}
