//
//  BalanceView.swift
//  MoneyTracker
//
//  Created on 2026-01-01.
//

import SwiftUI
import SwiftData

struct BalanceView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appSettings: AppSettings
    @Query(sort: \Account.name) private var accounts: [Account]
    @Query private var allCurrencies: [CurrencyRecord]
    @Query private var exchangeRates: [ExchangeRate]  // Per aggiornamenti reattivi

    @State private var showingAddAccount = false

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

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        VStack(spacing: 8) {
                            Text("Saldo Totale")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text(formatAmount(totalBalance))
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                        )
                        .padding(.horizontal)
                        .padding(.top, 8)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("I Miei Conti")
                                .font(.title2.bold())
                                .padding(.horizontal)

                            if accounts.isEmpty {
                                VStack(spacing: 16) {
                                    Image(systemName: "wallet.pass")
                                        .font(.system(size: 60))
                                        .foregroundStyle(.secondary)

                                    Text("Nessun conto")
                                        .font(.title3.bold())

                                    Text("Aggiungi il tuo primo conto per iniziare a tracciare le tue finanze")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 40)
                                }
                                .padding(.vertical, 60)
                                .frame(maxWidth: .infinity)
                            } else {
                                ForEach(accounts) { account in
                                    NavigationLink(destination: AccountDetailView(account: account)) {
                                        AccountRow(
                                            account: account,
                                            preferredCurrency: appSettings.preferredCurrencyEnum,
                                            preferredCurrencyRecord: preferredCurrencyRecord,
                                            exchangeRatesCount: exchangeRates.count
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                .padding(.horizontal)
                            }
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Bilancio")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddAccount = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showingAddAccount) {
                AddAccountView()
            }
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

struct AccountRow: View {
    @Environment(\.modelContext) private var modelContext

    let account: Account
    let preferredCurrency: Currency
    let preferredCurrencyRecord: CurrencyRecord?
    let exchangeRatesCount: Int  // Per aggiornamenti reattivi

    var displayBalance: String {
        // SwiftUI si aggiorna automaticamente quando exchangeRatesCount cambia
        _ = exchangeRatesCount

        guard let accountCurrency = account.currencyRecord,
              let preferredCurr = preferredCurrencyRecord else {
            return "\(preferredCurrency.symbol)0.00"
        }

        let convertedBalance = CurrencyService.shared.convert(
            amount: account.currentBalance,
            from: accountCurrency,
            to: preferredCurr,
            context: modelContext
        )

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2

        let amountString = formatter.string(from: convertedBalance as NSDecimalNumber) ?? "0.00"
        return "\(preferredCurrency.symbol)\(amountString)"
    }

    var body: some View {
        HStack(spacing: 16) {
            // Mostra immagine personalizzata se esiste, altrimenti icona
            if let imageData = account.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(account.color, lineWidth: 2)
                    )
            } else {
                ZStack {
                    Circle()
                        .fill(account.color.opacity(0.2))
                        .frame(width: 50, height: 50)

                    Image(systemName: account.icon)
                        .font(.title3)
                        .foregroundStyle(account.color)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(account.name)
                    .font(.body.bold())
                    .foregroundStyle(.primary)

                Text(account.accountType.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(displayBalance)
                    .font(.body.bold())
                    .foregroundStyle(.primary)

                if account.currency != preferredCurrency {
                    Text("\(account.currency.symbol)\(formatDecimal(account.currentBalance))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        )
    }

    private func formatDecimal(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "0.00"
    }
}

#Preview {
    BalanceView()
        .environmentObject(AppSettings.shared)
        .modelContainer(for: [Account.self, Transaction.self, Category.self, CategoryGroup.self])
}
