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
        OrbCard {
            VStack(spacing: 14) {
                HStack {
                    dayButton(-1, icon: "chevron.left")
                    Spacer()
                    Text(formatDate(selectedDate)).font(.orbHeadline).lineLimit(1)
                    Spacer()
                    dayButton(1, icon: "chevron.right")
                }
                HStack(spacing: 0) {
                    summary("Entrate", value: dayIncome, color: .orbPositive)
                    Divider()
                    summary("Uscite", value: dayExpenses, color: .orbNegative)
                    Divider()
                    summary("Saldo", value: dayIncome - dayExpenses, color: .orbText)
                }.fixedSize(horizontal: false, vertical: true)
                Text("\(allDayTransactions.count) transazioni").font(.orbCaption).foregroundStyle(Color.orbMuted)
            }
        }
    }
    private func dayButton(_ offset: Int, icon: String) -> some View {
        Button {
            withAnimation { selectedDate = Calendar.current.date(byAdding: .day, value: offset, to: selectedDate) ?? selectedDate }
        } label: {
            Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.orbText)
                .frame(width: 36, height: 36).overlay(Circle().stroke(Color.orbLine, lineWidth: 1))
                .frame(width: 44, height: 44)
        }.buttonStyle(.plain).accessibilityLabel(offset < 0 ? "Giorno precedente" : "Giorno successivo")
    }
    private func summary(_ title: String, value: Decimal, color: Color) -> some View {
        VStack(spacing: 7) {
            Text(title).font(.orbCaption).foregroundStyle(Color.orbMuted)
            Text(OrbCurrency.string(value, symbol: preferredCurrencyRecord?.displaySymbol ?? "€"))
                .font(.orbHeadline).foregroundStyle(color).monospacedDigit().lineLimit(1).minimumScaleFactor(0.65)
        }.frame(maxWidth: .infinity)
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
        case .expense: return Color.orbNegative
        case .income: return Color.orbPositive
        case .transfer: return Color.orbAccent
        case .liabilityPayment: return Color.orbHighlight
        case .adjustment: return Color.orbAccent
        }
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let symbol = preferredCurrencyRecord?.displaySymbol ?? "$"

        return "\(symbol) \(FormatterCache.formatCurrencyFixed(amount))"
    }

    private func formatShortAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        let amountString = formatter.string(from: amount as NSDecimalNumber) ?? "0"
        return amountString
    }
}
