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
    @EnvironmentObject var appSettings: AppSettings
    @Query private var accounts: [Account]
    @Query private var transactions: [Transaction]
    @Query private var allCurrencies: [CurrencyRecord]
    @Query private var exchangeRates: [ExchangeRate]  // Per aggiornamenti reattivi

    var preferredCurrencyRecord: CurrencyRecord? {
        allCurrencies.first { $0.code == appSettings.preferredCurrencyEnum.rawValue }
    }

    var totalBalance: Decimal {
        // SwiftUI si aggiorna automaticamente quando exchangeRates cambia
        _ = exchangeRates.count

        guard let preferredCurrency = preferredCurrencyRecord else { return 0 }

        return accounts.reduce(Decimal(0)) { sum, account in
            guard let accountCurrency = account.currencyRecord else { return sum }

            let convertedBalance = CurrencyService.shared.convert(
                amount: account.currentBalance,
                from: accountCurrency,
                to: preferredCurrency,
                context: modelContext
            )
            return sum + convertedBalance
        }
    }

    var todayTransactions: [Transaction] {
        transactions.filter { Calendar.current.isDateInToday($0.date) }
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
        .environmentObject(AppSettings.shared)
        .modelContainer(for: [Account.self, Transaction.self, Category.self, CategoryGroup.self])
}
