//
//  TotalBalanceWidget.swift
//  MoneyTracker
//
//  Created on 2026-01-27.
//

import SwiftUI
import SwiftData

struct TotalBalanceWidget: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appSettings) var appSettings

    // PERFORMANCE: Accept data as parameters instead of @Query
    let accounts: [Account]
    let allCurrencies: [CurrencyRecord]
    var transactions: [Transaction] = []

    var preferredCurrencyRecord: CurrencyRecord? {
        #if DEBUG
        print("💰 [TotalBalanceWidget] === ALL CURRENCIES IN DATABASE ===")
        for curr in allCurrencies {
            print("   Currency: \(curr.code)")
            print("      - name: '\(curr.name)'")
            print("      - symbol: '\(curr.symbol)'")
            print("      - flagEmoji: '\(curr.flagEmoji)'")
            print("      - displaySymbol: '\(curr.displaySymbol)'")
            print("   ───────────────")
        }
        print("💰 [TotalBalanceWidget] === END CURRENCIES ===")
        #endif

        let record = allCurrencies.first { $0.code == appSettings.preferredCurrencyEnum.rawValue }

        #if DEBUG
        if let record = record {
            print("💰 [TotalBalanceWidget] Preferred Currency SELECTED:")
            print("   - code: '\(record.code)'")
            print("   - name: '\(record.name)'")
            print("   - symbol: '\(record.symbol)'")
            print("   - flagEmoji: '\(record.flagEmoji)'")
            print("   - displaySymbol: '\(record.displaySymbol)'")
        } else {
            print("💰 [TotalBalanceWidget] ⚠️ NO PREFERRED CURRENCY FOUND!")
        }
        #endif

        return record
    }

    var totalBalance: Decimal {
        guard let preferredCurrency = preferredCurrencyRecord else { return 0 }

        return accounts.reduce(Decimal(0)) { sum, account in
            guard let accountCurrency = account.currencyRecord else { return sum }
            // Use pre-calculated currentBalance instead of recalculating
            let convertedBalance = CurrencyService.shared.convert(
                amount: account.investmentNetWorth,
                from: accountCurrency,
                to: preferredCurrency,
                context: modelContext
            )
            return sum + convertedBalance
        }
    }

    private func subtotal(positive: Bool) -> Decimal {
        guard let preferred = preferredCurrencyRecord else { return 0 }
        return accounts.filter { positive ? $0.investmentNetWorth > 0 : $0.investmentNetWorth < 0 }.reduce(Decimal(0)) { result, account in
            guard let currency = account.currencyRecord else { return result }
            return result + CurrencyService.shared.convert(amount: account.investmentNetWorth, from: currency, to: preferred, context: modelContext)
        }
    }

    private var weeklyExpenses: [DailyExpense] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let total = transactions.filter {
                !DeletedTransactionTracker.shared.isDeleted($0.id) && $0.modelContext != nil &&
                $0.status == .executed && $0.transactionType == .expense && calendar.isDate($0.date, inSameDayAs: date)
            }.reduce(Decimal(0)) { result, transaction in
                guard let preferred = preferredCurrencyRecord, let currency = transaction.currencyRecord else { return result + transaction.amount }
                return result + CurrencyService.shared.convert(amount: transaction.amount, from: currency, to: preferred, context: modelContext)
            }
            return DailyExpense(date: date, amount: total, dayName: date.formatted(.dateTime.weekday(.abbreviated)))
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            BalanceHeaderView(totalBalance: totalBalance, positiveBalance: subtotal(positive: true),
                              negativeBalance: subtotal(positive: false), weeklyExpenses: weeklyExpenses,
                              currencySymbol: preferredCurrencyRecord?.displaySymbol ?? "$",
                              orbSize: 210, orbitLabels: Array(Set(accounts.map { $0.currencyRecord?.code ?? $0.currency.rawValue })).sorted())
            HStack {
                Text(accounts.count == 1 ? "1 conto" : "\(accounts.count) conti")
                Spacer()
                if Set(accounts.map { $0.currencyRecord?.code ?? $0.currency.rawValue }).count > 1 { Text(preferredCurrencyRecord?.code ?? appSettings.preferredCurrency) }
            }.font(.orbCaption).foregroundStyle(Color.orbMuted).padding(.horizontal, 16)
        }.padding(.vertical, 12)
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let symbol = preferredCurrencyRecord?.displaySymbol ?? "$"

        return "\(symbol) \(FormatterCache.formatCurrencyFixed(amount))"
    }
}
