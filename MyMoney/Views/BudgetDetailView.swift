//
//  BudgetDetailView.swift
//  MoneyTracker
//
//  Created on 2026-01-24.
//

import SwiftUI
import SwiftData

struct BudgetDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appSettings) var appSettings
    @Query private var allTransactions: [Transaction]
    @Bindable var budget: Budget

    // Transazioni del budget nel periodo corrente
    var budgetTransactions: [Transaction] {
        guard let category = budget.category else { return [] }

        return allTransactions.filter { transaction in
            guard transaction.category?.id == category.id else { return false }
            guard transaction.transactionType == .expense else { return false }
            guard transaction.status == .executed else { return false }

            let transactionDate = transaction.date
            return transactionDate >= budget.currentPeriodStart && transactionDate <= budget.currentPeriodEnd
        }
        .sorted { $0.date > $1.date }
    }

    // Raggruppa transazioni per data
    var groupedTransactions: [(Date, [Transaction])] {
        let grouped = Dictionary(grouping: budgetTransactions) { transaction in
            Calendar.current.startOfDay(for: transaction.date)
        }
        return grouped.sorted { $0.key > $1.key }
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "0.00"
    }

    var body: some View {
        List {
            // Budget summary
            Section {
                budgetSummary
            }

            // Transactions
            if budgetTransactions.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)

                        Text("Nessuna transazione")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        Text("Non ci sono spese in questa categoria per il periodo corrente")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                }
            } else {
                ForEach(groupedTransactions, id: \.0) { date, transactions in
                    Section {
                        ForEach(transactions) { transaction in
                            transactionRow(transaction)
                        }
                    } header: {
                        Text(formatDate(date))
                            .font(.subheadline.bold())
                    }
                }
            }
        }
        .navigationTitle(budget.category?.name ?? "Budget")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Budget Summary

    private var budgetSummary: some View {
        VStack(spacing: 16) {
            // Amount info
            let spent = budget.spent(transactions: allTransactions, context: modelContext)
            let remaining = budget.remaining(transactions: allTransactions, context: modelContext)
            let percentage = budget.percentageUsed(transactions: allTransactions, context: modelContext)
            let currencySymbol = budget.currencyRecord?.symbol ?? "€"

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Speso")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(currencySymbol) \(formatAmount(spent))")
                        .font(.title2.bold())
                        .foregroundStyle(progressColor(percentage: percentage))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Budget")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(currencySymbol) \(formatAmount(budget.amount))")
                        .font(.title2.bold())
                }
            }

            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(height: 8)

                        // Progress
                        RoundedRectangle(cornerRadius: 4)
                            .fill(progressColor(percentage: percentage))
                            .frame(width: min(CGFloat(percentage / 100.0) * geometry.size.width, geometry.size.width), height: 8)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("\(Int(percentage))% utilizzato")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    if remaining > 0 {
                        Text("Rimangono \(currencySymbol) \(formatAmount(remaining))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Budget superato!")
                            .font(.caption.bold())
                            .foregroundStyle(.red)
                    }
                }
            }

            // Period info
            HStack {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(periodText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(budget.period.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(appSettings.accentColor.opacity(0.15))
                    )
                    .foregroundStyle(appSettings.accentColor)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Transaction Row

    private func transactionRow(_ transaction: Transaction) -> some View {
        HStack(spacing: 12) {
            // Time
            VStack(alignment: .leading, spacing: 2) {
                Text(formatTime(transaction.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Amount
            let currencySymbol = budget.currencyRecord?.symbol ?? "€"
            let amount = transaction.currencyRecord?.code == budget.currencyRecord?.code
                ? transaction.amount
                : (transaction.destinationAmount ?? CurrencyService.shared.convert(
                    amount: transaction.amount,
                    from: transaction.currencyRecord!,
                    to: budget.currencyRecord!,
                    context: modelContext
                ))

            Text("- \(currencySymbol) \(formatAmount(amount))")
                .font(.body.bold())
                .foregroundStyle(.red)
        }
    }

    // MARK: - Helper Methods

    private func progressColor(percentage: Double) -> Color {
        if percentage >= 100 {
            return .red
        } else if percentage >= 80 {
            return .orange
        } else {
            return .green
        }
    }

    private var periodText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium

        let start = formatter.string(from: budget.currentPeriodStart)
        let end = formatter.string(from: budget.currentPeriodEnd)

        return "\(start) - \(end)"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
