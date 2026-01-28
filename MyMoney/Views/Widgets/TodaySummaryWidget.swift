//
//  TodaySummaryWidget.swift
//  MoneyTracker
//
//  Created on 2026-01-27.
//

import SwiftUI
import SwiftData

struct TodaySummaryWidget: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appSettings) var appSettings
    @Query private var transactions: [Transaction]
    @Query private var allCurrencies: [CurrencyRecord]
    @Query private var exchangeRates: [ExchangeRate]

    var preferredCurrencyRecord: CurrencyRecord? {
        allCurrencies.first { $0.code == appSettings.preferredCurrencyEnum.rawValue }
    }

    var todayTransactions: [Transaction] {
        let tracker = DeletedTransactionTracker.shared
        return transactions.filter { transaction in
            guard !tracker.isDeleted(transaction.id) else { return false }
            guard transaction.modelContext != nil else { return false }
            return Calendar.current.isDateInToday(transaction.date) && transaction.status != .pending
        }
    }

    var todayExpenses: Decimal {
        _ = exchangeRates.count
        guard let preferredCurrency = preferredCurrencyRecord else { return 0 }
        let tracker = DeletedTransactionTracker.shared

        return todayTransactions
            .filter { !tracker.isDeleted($0.id) && $0.modelContext != nil && $0.transactionType == .expense }
            .reduce(0) { sum, transaction in
                guard let transactionCurrency = transaction.currencyRecord else { return sum }
                let convertedAmount = CurrencyService.shared.convert(
                    amount: transaction.amount,
                    from: transactionCurrency,
                    to: preferredCurrency,
                    context: modelContext
                )
                return sum + convertedAmount
            }
    }

    var todayIncome: Decimal {
        _ = exchangeRates.count
        guard let preferredCurrency = preferredCurrencyRecord else { return 0 }
        let tracker = DeletedTransactionTracker.shared

        return todayTransactions
            .filter { !tracker.isDeleted($0.id) && $0.modelContext != nil && $0.transactionType == .income }
            .reduce(0) { sum, transaction in
                guard let transactionCurrency = transaction.currencyRecord else { return sum }
                let convertedAmount = CurrencyService.shared.convert(
                    amount: transaction.amount,
                    from: transactionCurrency,
                    to: preferredCurrency,
                    context: modelContext
                )
                return sum + convertedAmount
            }
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "calendar.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.blue)

                Text("Oggi")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            HStack(spacing: 16) {
                // Entrate
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.green)
                        Text("Entrate")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Text(formatAmount(todayIncome))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.green.opacity(0.1))
                )

                // Uscite
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.red)
                        Text("Uscite")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Text(formatAmount(todayExpenses))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.red)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.red.opacity(0.1))
                )
            }

            // Bilancio
            HStack {
                Image(systemName: todayIncome - todayExpenses >= 0 ? "checkmark.circle.fill" : "minus.circle.fill")
                    .foregroundStyle(todayIncome - todayExpenses >= 0 ? .green : .red)

                Text("Bilancio")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(formatAmount(todayIncome - todayExpenses))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(todayIncome - todayExpenses >= 0 ? .green : .red)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        )
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let amountString = formatter.string(from: amount as NSDecimalNumber) ?? "0.00"
        return "\(appSettings.preferredCurrencyEnum.symbol)\(amountString)"
    }
}
