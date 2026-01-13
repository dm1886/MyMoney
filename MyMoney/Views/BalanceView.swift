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
    @State private var isEditMode = false
    @State private var accountOrder: [Account] = []

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
                                // Contanti Section
                                if !cashAccounts.isEmpty {
                                    AccountSection(
                                        title: "Contanti",
                                        icon: "banknote.fill",
                                        color: .green,
                                        accounts: cashAccounts,
                                        total: sectionTotal(for: cashAccounts),
                                        preferredCurrency: appSettings.preferredCurrencyEnum,
                                        preferredCurrencyRecord: preferredCurrencyRecord,
                                        exchangeRatesCount: exchangeRates.count,
                                        isEditMode: isEditMode
                                    )
                                }

                                // Pagamento Section
                                if !paymentAccounts.isEmpty {
                                    AccountSection(
                                        title: "Pagamento",
                                        icon: "creditcard.fill",
                                        color: .blue,
                                        accounts: paymentAccounts,
                                        total: sectionTotal(for: paymentAccounts),
                                        preferredCurrency: appSettings.preferredCurrencyEnum,
                                        preferredCurrencyRecord: preferredCurrencyRecord,
                                        exchangeRatesCount: exchangeRates.count,
                                        isEditMode: isEditMode
                                    )
                                }

                                // Attività Section
                                if !assetAccounts.isEmpty {
                                    AccountSection(
                                        title: "Attività",
                                        icon: "building.columns.fill",
                                        color: .purple,
                                        accounts: assetAccounts,
                                        total: sectionTotal(for: assetAccounts),
                                        preferredCurrency: appSettings.preferredCurrencyEnum,
                                        preferredCurrencyRecord: preferredCurrencyRecord,
                                        exchangeRatesCount: exchangeRates.count,
                                        isEditMode: isEditMode
                                    )
                                }

                                // Carta di Credito Section
                                if !creditCardAccounts.isEmpty {
                                    AccountSection(
                                        title: "Carta di Credito",
                                        icon: "creditcard.fill",
                                        color: .orange,
                                        accounts: creditCardAccounts,
                                        total: sectionTotal(for: creditCardAccounts),
                                        preferredCurrency: appSettings.preferredCurrencyEnum,
                                        preferredCurrencyRecord: preferredCurrencyRecord,
                                        exchangeRatesCount: exchangeRates.count,
                                        isDebt: true,
                                        isEditMode: isEditMode
                                    )
                                }

                                // Passività Section
                                if !liabilityAccounts.isEmpty {
                                    AccountSection(
                                        title: "Passività",
                                        icon: "chart.line.downtrend.xyaxis",
                                        color: .red,
                                        accounts: liabilityAccounts,
                                        total: sectionTotal(for: liabilityAccounts),
                                        preferredCurrency: appSettings.preferredCurrencyEnum,
                                        preferredCurrencyRecord: preferredCurrencyRecord,
                                        exchangeRatesCount: exchangeRates.count,
                                        isDebt: true,
                                        isEditMode: isEditMode
                                    )
                                }
                            }
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Bilancio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingAddAccount = true
                        } label: {
                            Label("Aggiungi Conto", systemImage: "plus.circle")
                        }

                        Button {
                            isEditMode.toggle()
                        } label: {
                            Label(isEditMode ? "Fine" : "Modifica Ordine", systemImage: isEditMode ? "checkmark.circle" : "arrow.up.arrow.down.circle")
                        }
                    } label: {
                        Image(systemName: isEditMode ? "checkmark.circle.fill" : "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(isEditMode ? .green : appSettings.accentColor)
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
                        .fill(account.color.opacity(0.2))
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

// MARK: - Account Section View

struct AccountSection: View {
    @Environment(\.modelContext) private var modelContext

    let title: String
    let icon: String
    let color: Color
    let accounts: [Account]
    let total: Decimal
    let preferredCurrency: Currency
    let preferredCurrencyRecord: CurrencyRecord?
    let exchangeRatesCount: Int
    var isDebt: Bool = false
    var isEditMode: Bool = false

    @State private var localAccounts: [Account] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header with Total
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .foregroundStyle(color)
                        .font(.title3)

                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                Spacer()

                // Section Total
                Text(formatSectionTotal(total))
                    .font(.subheadline.bold())
                    .foregroundStyle(total < 0 ? .red : color)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Accounts in this section
            VStack(spacing: 8) {
                ForEach(localAccounts) { account in
                    if isEditMode {
                        HStack {
                            Image(systemName: "line.3.horizontal")
                                .foregroundStyle(.secondary)
                                .padding(.leading)

                            NavigationLink(destination: AccountDetailView(account: account)) {
                                AccountRow(
                                    account: account,
                                    preferredCurrency: preferredCurrency,
                                    preferredCurrencyRecord: preferredCurrencyRecord,
                                    exchangeRatesCount: exchangeRatesCount
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    } else {
                        NavigationLink(destination: AccountDetailView(account: account)) {
                            AccountRow(
                                account: account,
                                preferredCurrency: preferredCurrency,
                                preferredCurrencyRecord: preferredCurrencyRecord,
                                exchangeRatesCount: exchangeRatesCount
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .onMove { source, destination in
                    localAccounts.move(fromOffsets: source, toOffset: destination)
                }
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            localAccounts = accounts
        }
        .onChange(of: accounts) { _, newAccounts in
            if !isEditMode {
                localAccounts = newAccounts
            }
        }
    }

    private func formatSectionTotal(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2

        // For debts, show as positive in UI but with indicator
        let displayAmount = isDebt ? abs(amount) : amount
        let amountString = formatter.string(from: displayAmount as NSDecimalNumber) ?? "0.00"

        if isDebt {
            return "-\(preferredCurrency.rawValue) \(amountString)"
        } else {
            return "\(preferredCurrency.rawValue) \(amountString)"
        }
    }
}

#Preview {
    BalanceView()
        .environment(\.appSettings, AppSettings.shared)
        .modelContainer(for: [Account.self, Transaction.self, Category.self, CategoryGroup.self])
}
