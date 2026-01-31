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
    @Query private var accounts: [Account]
    @Query private var allCurrencies: [CurrencyRecord]

    var preferredCurrencyRecord: CurrencyRecord? {
        allCurrencies.first { $0.code == appSettings.preferredCurrencyEnum.rawValue }
    }

    var totalBalance: Decimal {
        guard let preferredCurrency = preferredCurrencyRecord else { return 0 }

        return accounts.reduce(Decimal(0)) { sum, account in
            guard let accountCurrency = account.currencyRecord else { return sum }
            let accountBalance = calculateAccountBalance(account)
            let convertedBalance = CurrencyService.shared.convert(
                amount: accountBalance,
                from: accountCurrency,
                to: preferredCurrency,
                context: modelContext
            )
            return sum + convertedBalance
        }
    }

    private func calculateAccountBalance(_ account: Account) -> Decimal {
        var balance = account.initialBalance
        let tracker = DeletedTransactionTracker.shared

        if let accountTransactions = account.transactions {
            for transaction in accountTransactions where !tracker.isDeleted(transaction.id) && transaction.modelContext != nil && transaction.status == .executed {
                switch transaction.transactionType {
                case .expense: balance -= transaction.amount
                case .income: balance += transaction.amount
                case .transfer: balance -= transaction.amount
                case .adjustment: balance += transaction.amount
                }
            }
        }

        if let incoming = account.incomingTransfers {
            for transfer in incoming where !tracker.isDeleted(transfer.id) && transfer.modelContext != nil && transfer.status == .executed && transfer.transactionType == .transfer {
                // IMPORTANTE: Usa destinationAmount salvato per preservare calcoli storici
                if let destAmount = transfer.destinationAmount {
                    balance += destAmount
                } else if let snapshot = transfer.exchangeRateSnapshot {
                    // Usa snapshot del tasso se disponibile (preserva calcoli storici)
                    let convertedAmount = transfer.amount * snapshot
                    balance += convertedAmount
                } else if let transferCurr = transfer.currencyRecord,
                          let accountCurr = account.currencyRecord {
                    // Fallback: usa tasso corrente (solo per vecchie transazioni senza snapshot)
                    let convertedAmount = CurrencyService.shared.convert(
                        amount: transfer.amount,
                        from: transferCurr,
                        to: accountCurr,
                        context: modelContext
                    )
                    balance += convertedAmount
                }
            }
        }

        return balance
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
                if let currencyRecord = preferredCurrencyRecord {
                    Text(currencyRecord.flagEmoji)
                        .font(.system(size: 32))
                }

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
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = "."
        formatter.decimalSeparator = ","
        let amountString = formatter.string(from: amount as NSDecimalNumber) ?? "0"
        return amountString
    }
}
