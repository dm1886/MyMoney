//
//  IncomeVsExpensesWidget.swift
//  MoneyTracker
//
//  Created on 2026-01-27.
//

import SwiftUI
import SwiftData
import Charts

struct IncomeVsExpensesWidget: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appSettings) var appSettings
    @Query private var transactions: [Transaction]
    @Query private var allCurrencies: [CurrencyRecord]

    var preferredCurrencyRecord: CurrencyRecord? {
        allCurrencies.first { $0.code == appSettings.preferredCurrencyEnum.rawValue }
    }

    var monthlyData: [(month: String, income: Decimal, expenses: Decimal)] {
        guard let preferredCurrency = preferredCurrencyRecord else { return [] }

        let calendar = Calendar.current
        let now = Date()
        let tracker = DeletedTransactionTracker.shared

        var result: [(month: String, income: Decimal, expenses: Decimal)] = []

        for monthOffset in (0..<6).reversed() {
            guard let monthDate = calendar.date(byAdding: .month, value: -monthOffset, to: now),
                  let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate)),
                  let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: calendar.date(byAdding: .month, value: 1, to: startOfMonth)!) else { continue }

            let monthTransactions = transactions.filter { transaction in
                guard !tracker.isDeleted(transaction.id) else { return false }
                guard transaction.modelContext != nil else { return false }
                return transaction.date >= startOfMonth &&
                       transaction.date <= endOfMonth &&
                       transaction.status == .executed &&
                       (transaction.transactionType == .income || transaction.transactionType == .expense)
            }

            var income: Decimal = 0
            var expenses: Decimal = 0

            for transaction in monthTransactions {
                guard let transactionCurrency = transaction.currencyRecord else { continue }

                let converted = CurrencyService.shared.convert(
                    amount: transaction.amount,
                    from: transactionCurrency,
                    to: preferredCurrency,
                    context: modelContext
                )

                if transaction.transactionType == .income {
                    income += converted
                } else {
                    expenses += converted
                }
            }

            let formatter = DateFormatter()
            formatter.dateFormat = "MMM"
            formatter.locale = Locale(identifier: "it_IT")

            result.append((month: formatter.string(from: monthDate), income: income, expenses: expenses))
        }

        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.up.arrow.down.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.blue)

                Text("Entrate vs Uscite")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("Ultimi 6 Mesi")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            if monthlyData.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)

                    Text("Nessun dato disponibile")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                Chart {
                    ForEach(monthlyData, id: \.month) { data in
                        BarMark(
                            x: .value("Month", data.month),
                            y: .value("Amount", Double(truncating: data.income as NSDecimalNumber))
                        )
                        .foregroundStyle(.green.gradient)
                        .position(by: .value("Type", "Entrate"))

                        BarMark(
                            x: .value("Month", data.month),
                            y: .value("Amount", Double(truncating: data.expenses as NSDecimalNumber))
                        )
                        .foregroundStyle(.red.gradient)
                        .position(by: .value("Type", "Uscite"))
                    }
                }
                .frame(height: 180)
                .chartLegend(position: .bottom, spacing: 8)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        )
    }
}
