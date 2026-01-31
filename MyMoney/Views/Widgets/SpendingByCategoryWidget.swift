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
    @Query private var transactions: [Transaction]
    @Query private var categories: [Category]
    @Query private var allCurrencies: [CurrencyRecord]
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
        .prefix(5)
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.pie.fill")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Spese per Categoria")
                    .font(.headline.bold())
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Spacer()
            }

            Picker("Periodo", selection: $selectedPeriod) {
                ForEach(SpendingPeriod.allCases, id: \.self) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if categorySpending.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.pie")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)

                    Text("Nessuna spesa questo mese")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                Chart {
                    ForEach(Array(categorySpending.enumerated()), id: \.offset) { index, item in
                        SectorMark(
                            angle: .value("Amount", Double(truncating: item.amount as NSDecimalNumber)),
                            innerRadius: .ratio(0.618),
                            angularInset: 1.5
                        )
                        .foregroundStyle(item.category.color)
                        .opacity(0.9)
                    }
                }
                .frame(height: 160)
                .chartLegend(.hidden)
                .drawingGroup() // Optimize rendering performance

                VStack(spacing: 8) {
                    ForEach(Array(categorySpending.enumerated()), id: \.offset) { index, item in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(item.category.color)
                                .frame(width: 12, height: 12)

                            Text(item.category.name)
                                .font(.caption)
                                .foregroundStyle(.primary)

                            Spacer()

                            Text("\(Int(item.percentage * 100))%")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)

                            Text(formatAmount(item.amount))
                                .font(.caption.bold())
                                .foregroundStyle(.primary)
                        }
                    }
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

    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        formatter.groupingSeparator = "."
        formatter.decimalSeparator = ","
        let amountString = formatter.string(from: amount as NSDecimalNumber) ?? "0"
        return "\(preferredCurrencyRecord?.flagEmoji ?? "")\(amountString)"
    }
}
