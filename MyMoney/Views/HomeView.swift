//
//  HomeView.swift
//  MoneyTracker
//
//  Created on 2026-01-01.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appSettings) var appSettings
    @Query private var accounts: [Account]
    @Query private var transactions: [Transaction]
    @Query private var allCurrencies: [CurrencyRecord]
    @Query private var exchangeRates: [ExchangeRate]  // Per aggiornamenti reattivi

    var preferredCurrencyRecord: CurrencyRecord? {
        allCurrencies.first { $0.code == appSettings.preferredCurrencyEnum.rawValue }
    }

    var totalBalance: Decimal {
        guard let preferredCurrency = preferredCurrencyRecord else { return 0 }

        return accounts.reduce(Decimal(0)) { sum, account in
            guard let accountCurrency = account.currencyRecord else { return sum }

            // Calcola il saldo on-the-fly dalle transazioni
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

    // Calcola il saldo dell'account direttamente dalle transazioni
    private func calculateAccountBalance(_ account: Account) -> Decimal {
        var balance = account.initialBalance

        if let accountTransactions = account.transactions {
            for transaction in accountTransactions where transaction.status == .executed {
                switch transaction.transactionType {
                case .expense:
                    balance -= transaction.amount
                case .income:
                    balance += transaction.amount
                case .transfer:
                    balance -= transaction.amount
                case .adjustment:
                    balance += transaction.amount
                }
            }
        }

        if let incoming = account.incomingTransfers {
            for transfer in incoming where transfer.status == .executed && transfer.transactionType == .transfer {
                if let destAmount = transfer.destinationAmount {
                    balance += destAmount
                } else if let transferCurr = transfer.currencyRecord,
                          let accountCurr = account.currencyRecord {
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

    var todayTransactions: [Transaction] {
        transactions.filter { Calendar.current.isDateInToday($0.date) && $0.status != .pending }
    }

    var todayExpenses: Decimal {
        _ = exchangeRates.count
        guard let preferredCurrency = preferredCurrencyRecord else { return 0 }

        return todayTransactions
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

    var todayIncome: Decimal {
        _ = exchangeRates.count
        guard let preferredCurrency = preferredCurrencyRecord else { return 0 }

        return todayTransactions
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

    var overdueManualTransactions: [Transaction] {
        let now = Date()
        return transactions.filter { transaction in
            guard let scheduledDate = transaction.scheduledDate else { return false }
            return transaction.isScheduled &&
                   transaction.status == .pending &&
                   !transaction.isAutomatic &&
                   scheduledDate < now
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("Benvenuto in")
                            .font(.title3)
                            .foregroundStyle(.secondary)

                        Text("MoneyTracker")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    .padding(.top, 20)

                    // Overdue Manual Transactions Banner
                    if !overdueManualTransactions.isEmpty {
                        NavigationLink(destination: PendingTransactionsView()) {
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.orange)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Transazioni in Attesa")
                                        .font(.headline)
                                        .foregroundStyle(.primary)

                                    Text("\(overdueManualTransactions.count) transazione\(overdueManualTransactions.count == 1 ? "" : "i") da confermare")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.orange.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.orange, lineWidth: 2)
                                    )
                            )
                            .padding(.horizontal)
                        }
                    }

                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Saldo Totale")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                Text(formatAmount(totalBalance))
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary)
                            }

                            Spacer()

                            Image(systemName: "dollarsign.circle.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(.blue)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                        )

                        HStack(spacing: 12) {
                            SummaryCard(
                                title: "Entrate Oggi",
                                amount: todayIncome,
                                currency: appSettings.preferredCurrencyEnum,
                                icon: "arrow.up.circle.fill",
                                color: .green
                            )

                            SummaryCard(
                                title: "Uscite Oggi",
                                amount: todayExpenses,
                                currency: appSettings.preferredCurrencyEnum,
                                icon: "arrow.down.circle.fill",
                                color: .red
                            )
                        }
                    }
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Statistiche")
                            .font(.title2.bold())
                            .padding(.horizontal)

                        VStack(spacing: 12) {
                            StatRow(title: "Conti Attivi", value: "\(accounts.count)", icon: "creditcard.fill")
                            StatRow(title: "Transazioni Oggi", value: "\(todayTransactions.count)", icon: "list.bullet")
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                        )
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 100)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
        }
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

struct SummaryCard: View {
    let title: String
    let amount: Decimal
    let currency: Currency
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                Spacer()
            }

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(formatAmount(amount))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        )
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2

        let amountString = formatter.string(from: amount as NSDecimalNumber) ?? "0.00"
        return "\(currency.symbol)\(amountString)"
    }
}

struct StatRow: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 30)

            Text(title)
                .font(.body)
                .foregroundStyle(.primary)

            Spacer()

            Text(value)
                .font(.body.bold())
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    HomeView()
        .environment(\.appSettings, AppSettings.shared)
        .modelContainer(for: [Account.self, Transaction.self, Category.self, CategoryGroup.self])
}
