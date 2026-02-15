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
                amount: account.currentBalance,
                from: accountCurrency,
                to: preferredCurrency,
                context: modelContext
            )
            return sum + convertedBalance
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Saldo Totale")
                    .font(.headline)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Spacer()
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(formatAmount(totalBalance))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }

            HStack {
                Text("\(accounts.count) conti")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if let currencyRecord = preferredCurrencyRecord {
                    Text(currencyRecord.code)
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
