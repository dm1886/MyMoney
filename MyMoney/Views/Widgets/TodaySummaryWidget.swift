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

    // PERFORMANCE: Accept data as parameters instead of @Query
    let transactions: [Transaction]
    let allCurrencies: [CurrencyRecord]

    @State private var selectedDate = Date()

    var preferredCurrencyRecord: CurrencyRecord? {
        allCurrencies.first { $0.code == appSettings.preferredCurrencyEnum.rawValue }
    }

    var dayTransactions: [Transaction] {
        let tracker = DeletedTransactionTracker.shared
        return transactions.filter { transaction in
            guard !tracker.isDeleted(transaction.id) else { return false }
            guard transaction.modelContext != nil else { return false }
            return Calendar.current.isDate(transaction.date, inSameDayAs: selectedDate) && transaction.status == .executed
        }
    }

    var scheduledTransactions: [Transaction] {
        let tracker = DeletedTransactionTracker.shared
        return transactions.filter { transaction in
            guard !tracker.isDeleted(transaction.id) else { return false }
            guard transaction.modelContext != nil else { return false }
            return Calendar.current.isDate(transaction.date, inSameDayAs: selectedDate) && transaction.status == .pending && transaction.isScheduled
        }
    }

    var allDayTransactions: [Transaction] {
        dayTransactions + scheduledTransactions
    }

    var dayExpenses: Decimal {
        guard let preferredCurrency = preferredCurrencyRecord else { return 0 }

        return allDayTransactions
            .filter { $0.transactionType == .expense }
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

    var dayIncome: Decimal {
        guard let preferredCurrency = preferredCurrencyRecord else { return 0 }

        return allDayTransactions
            .filter { $0.transactionType == .income }
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
        VStack(spacing: 12) {
            // Header con navigazione date
            HStack {
                Button {
                    withAnimation {
                        selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                    }
                } label: {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.title2)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .buttonStyle(.plain)

                Spacer()

                VStack(spacing: 2) {
                    Text(formatDate(selectedDate))
                        .font(.headline.bold())
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Text("\(allDayTransactions.count) transazioni")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    withAnimation {
                        selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                    }
                } label: {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title2)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .buttonStyle(.plain)
            }

            // Entrate e Uscite - verticale
            VStack(spacing: 8) {
                // Entrate
                HStack {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundStyle(.green)
                    Text("Entrate")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formatAmount(dayIncome))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.green.opacity(0.1))
                )

                // Uscite
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(.red)
                    Text("Uscite")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formatAmount(dayExpenses))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.red)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.red.opacity(0.1))
                )

                // Bilancio
                HStack {
                    Image(systemName: dayIncome - dayExpenses >= 0 ? "checkmark.circle.fill" : "minus.circle.fill")
                        .foregroundStyle(dayIncome - dayExpenses >= 0 ? .green : .red)
                    Text("Bilancio")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formatAmount(dayIncome - dayExpenses))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(dayIncome - dayExpenses >= 0 ? .green : .red)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
            }

            // Previste (solo se ci sono)
            if !scheduledTransactions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Previste (\(scheduledTransactions.count))")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)

                    ForEach(scheduledTransactions.prefix(3)) { transaction in
                        HStack(spacing: 6) {
                            Image(systemName: transactionIcon(for: transaction))
                                .font(.caption2)
                                .foregroundStyle(transactionColor(for: transaction))
                            Text(transaction.notes.isEmpty ? transaction.category?.name ?? "Transazione" : transaction.notes)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer()
                            Text(formatShortAmount(transaction.amount))
                                .font(.caption2)
                                .foregroundStyle(transactionColor(for: transaction))
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.orange.opacity(0.05))
                )
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        )
    }

    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Oggi"
        } else if calendar.isDateInYesterday(date) {
            return "Ieri"
        } else if calendar.isDateInTomorrow(date) {
            return "Domani"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "d MMM"
            formatter.locale = Locale(identifier: "it_IT")
            return formatter.string(from: date)
        }
    }

    private func transactionIcon(for transaction: Transaction) -> String {
        switch transaction.transactionType {
        case .expense: return "arrow.down"
        case .income: return "arrow.up"
        case .transfer: return "arrow.left.arrow.right"
        case .liabilityPayment: return "creditcard.and.123"
        case .adjustment: return "slider.horizontal.3"
        }
    }

    private func transactionColor(for transaction: Transaction) -> Color {
        switch transaction.transactionType {
        case .expense: return .red
        case .income: return .green
        case .transfer: return .blue
        case .liabilityPayment: return .orange
        case .adjustment: return .purple
        }
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let symbol = preferredCurrencyRecord?.displaySymbol ?? "$"
        let flag = preferredCurrencyRecord?.flagEmoji ?? ""
        return "\(symbol)\(FormatterCache.formatCurrency(amount)) \(flag)"
    }

    private func formatShortAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        let amountString = formatter.string(from: amount as NSDecimalNumber) ?? "0"
        return amountString
    }
}
