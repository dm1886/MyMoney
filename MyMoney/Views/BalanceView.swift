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
    @Environment(\.appSettings) var appSettings
    @Query(sort: \Account.name) private var accounts: [Account]
    @Query private var allCurrencies: [CurrencyRecord]
    @Query private var exchangeRates: [ExchangeRate]  // Per aggiornamenti reattivi
    @Query private var transactions: [Transaction]    // Per aggiornamenti reattivi quando transazioni cambiano

    @State private var showingAddAccount = false

    var preferredCurrencyRecord: CurrencyRecord? {
        allCurrencies.first { $0.code == appSettings.preferredCurrencyEnum.rawValue }
    }

    // Group accounts by type
    var cashAccounts: [Account] {
        accounts.filter { $0.accountType == .cash }
    }

    var paymentAccounts: [Account] {
        accounts.filter { $0.accountType == .payment }
    }

    var prepaidCardAccounts: [Account] {
        accounts.filter { $0.accountType == .prepaidCard }
    }

    var creditCardAccounts: [Account] {
        accounts.filter { $0.accountType == .creditCard }
    }

    var assetAccounts: [Account] {
        accounts.filter { $0.accountType == .asset }
    }

    var liabilityAccounts: [Account] {
        accounts.filter { $0.accountType == .liability }
    }

    // Calculate section totals
    func sectionTotal(for accounts: [Account]) -> Decimal {
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

    var totalBalance: Decimal {
        guard let preferredCurrency = preferredCurrencyRecord else { return 0 }

        return accounts.reduce(Decimal(0)) { sum, account in
            guard let accountCurrency = account.currencyRecord else { return sum }

            // Calcola il saldo on-the-fly dalle transazioni invece di usare currentBalance
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

        // Somma tutte le transazioni EXECUTED dell'account
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

        // Aggiungi trasferimenti in entrata
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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header con saldo totale
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
                        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
                )
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 16)

                // Lista conti
                if accounts.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()

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

                        Spacer()
                    }
                } else {
                    List {
                        // Contanti Section
                        if !cashAccounts.isEmpty {
                            Section {
                                ForEach(cashAccounts) { account in
                                    NavigationLink(destination: AccountDetailView(account: account)) {
                                        AccountRow(
                                            account: account,
                                            preferredCurrency: appSettings.preferredCurrencyEnum,
                                            preferredCurrencyRecord: preferredCurrencyRecord,
                                            exchangeRatesCount: exchangeRates.count
                                        )
                                    }
                                }
                            } header: {
                                sectionHeader(
                                    title: "Contanti",
                                    icon: "banknote.fill",
                                    color: .green,
                                    total: sectionTotal(for: cashAccounts)
                                )
                            }
                        }

                        // Pagamento Section
                        if !paymentAccounts.isEmpty {
                            Section {
                                ForEach(paymentAccounts) { account in
                                    NavigationLink(destination: AccountDetailView(account: account)) {
                                        AccountRow(
                                            account: account,
                                            preferredCurrency: appSettings.preferredCurrencyEnum,
                                            preferredCurrencyRecord: preferredCurrencyRecord,
                                            exchangeRatesCount: exchangeRates.count
                                        )
                                    }
                                }
                            } header: {
                                sectionHeader(
                                    title: "Pagamento",
                                    icon: "creditcard.fill",
                                    color: .blue,
                                    total: sectionTotal(for: paymentAccounts)
                                )
                            }
                        }

                        // Carte Prepagate Section
                        if !prepaidCardAccounts.isEmpty {
                            Section {
                                ForEach(prepaidCardAccounts) { account in
                                    NavigationLink(destination: AccountDetailView(account: account)) {
                                        AccountRow(
                                            account: account,
                                            preferredCurrency: appSettings.preferredCurrencyEnum,
                                            preferredCurrencyRecord: preferredCurrencyRecord,
                                            exchangeRatesCount: exchangeRates.count
                                        )
                                    }
                                }
                            } header: {
                                sectionHeader(
                                    title: "Carte Prepagate",
                                    icon: "creditcard.fill",
                                    color: .cyan,
                                    total: sectionTotal(for: prepaidCardAccounts)
                                )
                            }
                        }

                        // Attività Section
                        if !assetAccounts.isEmpty {
                            Section {
                                ForEach(assetAccounts) { account in
                                    NavigationLink(destination: AccountDetailView(account: account)) {
                                        AccountRow(
                                            account: account,
                                            preferredCurrency: appSettings.preferredCurrencyEnum,
                                            preferredCurrencyRecord: preferredCurrencyRecord,
                                            exchangeRatesCount: exchangeRates.count
                                        )
                                    }
                                }
                            } header: {
                                sectionHeader(
                                    title: "Attività",
                                    icon: "building.columns.fill",
                                    color: .purple,
                                    total: sectionTotal(for: assetAccounts)
                                )
                            }
                        }

                        // Carta di Credito Section
                        if !creditCardAccounts.isEmpty {
                            Section {
                                ForEach(creditCardAccounts) { account in
                                    NavigationLink(destination: AccountDetailView(account: account)) {
                                        AccountRow(
                                            account: account,
                                            preferredCurrency: appSettings.preferredCurrencyEnum,
                                            preferredCurrencyRecord: preferredCurrencyRecord,
                                            exchangeRatesCount: exchangeRates.count
                                        )
                                    }
                                }
                            } header: {
                                sectionHeader(
                                    title: "Carta di Credito",
                                    icon: "creditcard.fill",
                                    color: .orange,
                                    total: sectionTotal(for: creditCardAccounts),
                                    isDebt: true
                                )
                            }
                        }

                        // Passività Section
                        if !liabilityAccounts.isEmpty {
                            Section {
                                ForEach(liabilityAccounts) { account in
                                    NavigationLink(destination: AccountDetailView(account: account)) {
                                        AccountRow(
                                            account: account,
                                            preferredCurrency: appSettings.preferredCurrencyEnum,
                                            preferredCurrencyRecord: preferredCurrencyRecord,
                                            exchangeRatesCount: exchangeRates.count
                                        )
                                    }
                                }
                            } header: {
                                sectionHeader(
                                    title: "Passività",
                                    icon: "chart.line.downtrend.xyaxis",
                                    color: .red,
                                    total: sectionTotal(for: liabilityAccounts),
                                    isDebt: true
                                )
                            }
                        }
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Bilancio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddAccount = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(appSettings.accentColor)
                    }
                }
            }
            .sheet(isPresented: $showingAddAccount) {
                AddAccountView()
            }
        }
    }

    private func sectionHeader(title: String, icon: String, color: Color, total: Decimal, isDebt: Bool = false) -> some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .foregroundStyle(.primary)
            }
            Spacer()
            Text(formatSectionTotal(total, isDebt: isDebt))
                .foregroundStyle(.secondary)
        }
        .font(.subheadline.bold())
        .textCase(nil)
    }

    private func formatSectionTotal(_ amount: Decimal, isDebt: Bool) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2

        let displayAmount = abs(amount)
        let amountString = formatter.string(from: displayAmount as NSDecimalNumber) ?? "0.00"

        // Per debiti (carte di credito, passività), mostra + o - in base al segno effettivo
        if isDebt {
            if amount < 0 {
                // Negativo = debito
                return "-\(appSettings.preferredCurrencyEnum.rawValue) \(amountString)"
            } else if amount > 0 {
                // Positivo = credito
                return "+\(appSettings.preferredCurrencyEnum.rawValue) \(amountString)"
            } else {
                // Zero
                return "\(appSettings.preferredCurrencyEnum.rawValue) \(amountString)"
            }
        } else {
            return "\(appSettings.preferredCurrencyEnum.rawValue) \(amountString)"
        }
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2

        let amountString = formatter.string(from: amount as NSDecimalNumber) ?? "0.00"
        return "\(appSettings.preferredCurrencyEnum.rawValue) \(amountString)"
    }
}

struct AccountRow: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var transactions: [Transaction]  // Per aggiornamenti reattivi

    let account: Account
    let preferredCurrency: Currency
    let preferredCurrencyRecord: CurrencyRecord?
    let exchangeRatesCount: Int  // Per aggiornamenti reattivi

    private func displayBalance(for accountBalance: Decimal) -> String {
        guard let accountCurrency = account.currencyRecord,
              let preferredCurr = preferredCurrencyRecord else {
            return "\(preferredCurrency.rawValue) 0.00"
        }

        let convertedBalance = CurrencyService.shared.convert(
            amount: accountBalance,
            from: accountCurrency,
            to: preferredCurr,
            context: modelContext
        )

        // For credit cards and liabilities, show absolute value (debts are stored as negative)
        let displayAmount = (account.accountType == .creditCard || account.accountType == .liability) ? abs(convertedBalance) : convertedBalance

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2

        let amountString = formatter.string(from: displayAmount as NSDecimalNumber) ?? "0.00"
        return "\(preferredCurrency.rawValue) \(amountString)"
    }

    private func balanceColor(for balance: Decimal) -> Color {
        if account.accountType == .creditCard || account.accountType == .liability {
            // For debts, negative (debt exists) is red, zero/positive is green
            return balance < 0 ? .red : .green
        } else {
            // For normal accounts, negative is red, positive is primary
            return balance < 0 ? .red : .primary
        }
    }

    private func calculateBalance(for account: Account) -> Decimal {
        var balance = account.initialBalance

        if let accountTransactions = account.transactions {
            for transaction in accountTransactions where transaction.status == .executed {
                // Determina l'importo da usare: se c'è destinationAmount (conversione), usalo,
                // altrimenti converti on-the-fly se necessario, altrimenti usa l'importo originale
                var amountToUse = transaction.amount

                if let destAmount = transaction.destinationAmount {
                    // Usa l'importo già convertito (salvato durante la creazione)
                    amountToUse = destAmount
                } else if let transactionCurr = transaction.currencyRecord,
                          let accountCurr = account.currencyRecord,
                          transactionCurr.code != accountCurr.code {
                    // Conversione on-the-fly se le valute sono diverse
                    amountToUse = CurrencyService.shared.convert(
                        amount: transaction.amount,
                        from: transactionCurr,
                        to: accountCurr,
                        context: modelContext
                    )
                }

                switch transaction.transactionType {
                case .expense:
                    balance -= amountToUse
                case .income:
                    balance += amountToUse
                case .transfer:
                    balance -= amountToUse
                case .adjustment:
                    balance += amountToUse
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

    var body: some View {
        let balance = calculateBalance(for: account)

        HStack(spacing: 12) {
            // Mostra immagine personalizzata se esiste, altrimenti icona
            if let imageData = account.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(account.color, lineWidth: 2)
                    )
            } else {
                ZStack {
                    Circle()
                        .fill(account.color.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: account.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(account.color)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(account.name)
                    .font(.body)
                    .foregroundStyle(.primary)

                Text(account.accountType.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(displayBalance(for: balance))
                    .font(.body)
                    .foregroundStyle(balanceColor(for: balance))

                if account.currency != preferredCurrency {
                    let displayedBalance = (account.accountType == .creditCard || account.accountType == .liability) ? abs(balance) : balance
                    Text("\(account.currency.rawValue) \(formatDecimal(displayedBalance))")
                        .font(.caption)
                        .foregroundStyle(balanceColor(for: balance))
                }
            }
        }
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
        .environment(\.appSettings, AppSettings.shared)
        .modelContainer(for: [Account.self, Transaction.self, Category.self, CategoryGroup.self])
}
