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

    @State private var collapsedGroups: Set<String> = []
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
        guard let preferredCurrency = preferredCurrencyRecord else {
            return 0
        }

        let total = accounts.reduce(Decimal(0)) { sum, account in
            guard let accountCurrency = account.currencyRecord else {
                return sum
            }

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

        return total
    }

    var positiveBalance: Decimal {
        guard let preferredCurrency = preferredCurrencyRecord else { return 0 }

        return accounts.reduce(Decimal(0)) { sum, account in
            guard let accountCurrency = account.currencyRecord else { return sum }
            let accountBalance = calculateAccountBalance(account)
            guard accountBalance > 0 else { return sum }

            let convertedBalance = CurrencyService.shared.convert(
                amount: accountBalance,
                from: accountCurrency,
                to: preferredCurrency,
                context: modelContext
            )
            return sum + convertedBalance
        }
    }

    var negativeBalance: Decimal {
        guard let preferredCurrency = preferredCurrencyRecord else { return 0 }

        return accounts.reduce(Decimal(0)) { sum, account in
            guard let accountCurrency = account.currencyRecord else { return sum }
            let accountBalance = calculateAccountBalance(account)
            guard accountBalance < 0 else { return sum }

            let convertedBalance = CurrencyService.shared.convert(
                amount: accountBalance,
                from: accountCurrency,
                to: preferredCurrency,
                context: modelContext
            )
            return sum + convertedBalance
        }
    }

    var weeklyExpenses: [DailyExpense] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var expenses: [DailyExpense] = []

        for dayOffset in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let nextDay = calendar.date(byAdding: .day, value: 1, to: date) ?? date

            let dayExpenses = transactions.filter { transaction in
                transaction.transactionType == .expense &&
                transaction.status == .executed &&
                transaction.date >= date &&
                transaction.date < nextDay
            }

            let total = dayExpenses.reduce(Decimal(0)) { sum, transaction in
                guard let preferredCurrency = preferredCurrencyRecord,
                      let transactionCurrency = transaction.currencyRecord else {
                    return sum + transaction.amount
                }
                return sum + CurrencyService.shared.convert(
                    amount: transaction.amount,
                    from: transactionCurrency,
                    to: preferredCurrency,
                    context: modelContext
                )
            }

            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            formatter.locale = Locale(identifier: "it_IT")

            expenses.append(DailyExpense(
                date: date,
                amount: total,
                dayName: formatter.string(from: date).prefix(3).capitalized
            ))
        }

        return expenses
    }

    // Calcola il saldo dell'account direttamente dalle transazioni
    private func calculateAccountBalance(_ account: Account) -> Decimal {
        if account.investmentProfile != nil { return account.investmentNetWorth }
        var balance = account.initialBalance
        let tracker = DeletedTransactionTracker.shared

        // Somma tutte le transazioni EXECUTED dell'account
        // Filter out deleted/detached transactions to prevent crash
        // CRITICAL: Check tracker FIRST before accessing transactionType
        if let accountTransactions = account.transactions {
            for transaction in accountTransactions where !tracker.isDeleted(transaction.id) && transaction.modelContext != nil && transaction.status == .executed {
                // Per TRANSFER: usa sempre transaction.amount (importo originale)
                // Per expense/income: usa destinationAmount se presente (conversione valuta)
                var amountToUse = transaction.amount

                if transaction.transactionType != .transfer {
                    // Per expense/income: controlla se c'è conversione
                    if let destAmount = transaction.destinationAmount {
                        amountToUse = destAmount
                    }
                }

                switch transaction.transactionType {
                case .expense:
                    balance -= amountToUse
                case .income:
                    balance += amountToUse
                case .transfer:
                    balance -= amountToUse
                case .liabilityPayment:
                    let totalPayment = amountToUse + (transaction.interestAmount ?? 0)
                    balance -= totalPayment
                case .adjustment:
                    balance += amountToUse
                }
            }
        }

        // Aggiungi trasferimenti in entrata e pagamenti passività
        // Filter out deleted/detached transfers to prevent crash
        // CRITICAL: Check tracker FIRST before accessing transactionType
        if let incoming = account.incomingTransfers {
            for transfer in incoming where !tracker.isDeleted(transfer.id) && transfer.modelContext != nil && transfer.status == .executed {
                var amountToAdd: Decimal = 0
                
                if transfer.transactionType == .transfer {
                    // IMPORTANTE: Usa destinationAmount salvato per preservare calcoli storici
                    if let destAmount = transfer.destinationAmount {
                        amountToAdd = destAmount
                    } else if let snapshot = transfer.exchangeRateSnapshot {
                        // Usa snapshot del tasso se disponibile (preserva calcoli storici)
                        amountToAdd = transfer.amount * snapshot
                    } else if let transferCurr = transfer.currencyRecord,
                              let accountCurr = account.currencyRecord {
                        // Fallback: usa tasso corrente (solo per vecchie transazioni senza snapshot)
                        amountToAdd = CurrencyService.shared.convert(
                            amount: transfer.amount,
                            from: transferCurr,
                            to: accountCurr,
                            context: modelContext
                        )
                    } else {
                        amountToAdd = transfer.amount
                    }
                    balance += amountToAdd
                } else if transfer.transactionType == .liabilityPayment {
                    // Per pagamenti passività, accredita l'importo del debito (riduce la passività)
                    // L'interesse non viene accreditato perché è una spesa
                    if let destAmount = transfer.destinationAmount {
                        amountToAdd = destAmount
                    } else if let transferCurr = transfer.currencyRecord,
                              let accountCurr = account.currencyRecord,
                              transferCurr.code != accountCurr.code {
                        amountToAdd = CurrencyService.shared.convert(
                            amount: transfer.amount,
                            from: transferCurr,
                            to: accountCurr,
                            context: modelContext
                        )
                    } else {
                        amountToAdd = transfer.amount
                    }
                    balance += amountToAdd
                }
            }
        }

        return balance
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header dinamico basato sulle impostazioni
                BalanceHeaderView(
                    totalBalance: totalBalance,
                    positiveBalance: positiveBalance,
                    negativeBalance: negativeBalance,
                    weeklyExpenses: weeklyExpenses,
                    currencySymbol: preferredCurrencyRecord?.displaySymbol ?? "EUR"
                )
                .padding(.bottom, 12)
                .background(Color.orbCard, in: RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 16)
                .padding(.bottom, 16)

                // Lista conti
                if accounts.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()

                        Image(systemName: "wallet.pass")
                            .font(.system(size: 60))
                            .foregroundStyle(Color.orbMuted)

                        Text("Nessun conto")
                            .font(.orbTitle3.bold())

                        Text("Aggiungi il tuo primo conto per iniziare a tracciare le tue finanze")
                            .font(.orbSubheadline)
                            .foregroundStyle(Color.orbMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)

                        Spacer()
                    }
                } else {
                    List {
                        // Contanti Section
                        if !cashAccounts.isEmpty {
                            Section {
                                ForEach(collapsedGroups.contains("cashAccounts") ? [] : cashAccounts) { account in
                                    OrbAccountLink(
                                            account: account,
                                            preferredCurrency: appSettings.preferredCurrencyEnum,
                                            preferredCurrencyRecord: preferredCurrencyRecord,
                                            exchangeRatesCount: exchangeRates.count
                                        )
                                }
                            } header: {
                                sectionHeader(
                                    title: "Contanti",
                                    icon: "banknote.fill",
                                    color: Color.orbPositive,
                                    total: sectionTotal(for: cashAccounts),
                                    groupID: "cashAccounts"
                                )
                            }.listRowBackground(Color.orbCard)
                        }

                        // Pagamento Section
                        if !paymentAccounts.isEmpty {
                            Section {
                                ForEach(collapsedGroups.contains("paymentAccounts") ? [] : paymentAccounts) { account in
                                    OrbAccountLink(
                                            account: account,
                                            preferredCurrency: appSettings.preferredCurrencyEnum,
                                            preferredCurrencyRecord: preferredCurrencyRecord,
                                            exchangeRatesCount: exchangeRates.count
                                        )
                                }
                            } header: {
                                sectionHeader(
                                    title: "Pagamento",
                                    icon: "creditcard.fill",
                                    color: Color.orbAccent,
                                    total: sectionTotal(for: paymentAccounts),
                                    groupID: "paymentAccounts"
                                )
                            }.listRowBackground(Color.orbCard)
                        }

                        // Carte Prepagate Section
                        if !prepaidCardAccounts.isEmpty {
                            Section {
                                ForEach(collapsedGroups.contains("prepaidCardAccounts") ? [] : prepaidCardAccounts) { account in
                                    OrbAccountLink(
                                            account: account,
                                            preferredCurrency: appSettings.preferredCurrencyEnum,
                                            preferredCurrencyRecord: preferredCurrencyRecord,
                                            exchangeRatesCount: exchangeRates.count
                                        )
                                }
                            } header: {
                                sectionHeader(
                                    title: "Carte Prepagate",
                                    icon: "creditcard.fill",
                                    color: Color.orbSecondary,
                                    total: sectionTotal(for: prepaidCardAccounts),
                                    groupID: "prepaidCardAccounts"
                                )
                            }.listRowBackground(Color.orbCard)
                        }

                        // Attività Section
                        if !assetAccounts.isEmpty {
                            Section {
                                ForEach(collapsedGroups.contains("assetAccounts") ? [] : assetAccounts) { account in
                                    OrbAccountLink(
                                            account: account,
                                            preferredCurrency: appSettings.preferredCurrencyEnum,
                                            preferredCurrencyRecord: preferredCurrencyRecord,
                                            exchangeRatesCount: exchangeRates.count
                                        )
                                }
                            } header: {
                                sectionHeader(
                                    title: "Attività",
                                    icon: "building.columns.fill",
                                    color: Color.orbAccent,
                                    total: sectionTotal(for: assetAccounts),
                                    groupID: "assetAccounts"
                                )
                            }.listRowBackground(Color.orbCard)
                        }

                        // Carta di Credito Section
                        if !creditCardAccounts.isEmpty {
                            Section {
                                ForEach(collapsedGroups.contains("creditCardAccounts") ? [] : creditCardAccounts) { account in
                                    OrbAccountLink(
                                            account: account,
                                            preferredCurrency: appSettings.preferredCurrencyEnum,
                                            preferredCurrencyRecord: preferredCurrencyRecord,
                                            exchangeRatesCount: exchangeRates.count
                                        )
                                }
                            } header: {
                                sectionHeader(
                                    title: "Carta di Credito",
                                    icon: "creditcard.fill",
                                    color: Color.orbHighlight,
                                    total: sectionTotal(for: creditCardAccounts),
                                    groupID: "creditCardAccounts",
                                    isDebt: true
                                )
                            }.listRowBackground(Color.orbCard)
                        }

                        // Passività Section
                        if !liabilityAccounts.isEmpty {
                            Section {
                                ForEach(collapsedGroups.contains("liabilityAccounts") ? [] : liabilityAccounts) { account in
                                    OrbAccountLink(
                                            account: account,
                                            preferredCurrency: appSettings.preferredCurrencyEnum,
                                            preferredCurrencyRecord: preferredCurrencyRecord,
                                            exchangeRatesCount: exchangeRates.count
                                        )
                                }
                            } header: {
                                sectionHeader(
                                    title: "Passività",
                                    icon: "chart.line.downtrend.xyaxis",
                                    color: Color.orbNegative,
                                    total: sectionTotal(for: liabilityAccounts),
                                    groupID: "liabilityAccounts",
                                    isDebt: true
                                )
                            }.listRowBackground(Color.orbCard)
                        }
                        Section {
                            NetWorthTrendWidget(accounts: accounts, allCurrencies: allCurrencies)
                        }.listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                    }.orbScreen()
                }
            }
            .background(Color.orbBackground)
            .background(OrbTabReselect(tab: 1))
            .navigationTitle("Bilancio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Conto", systemImage: "wallet.pass") {
                        showingAddAccount = true
                    }
                    .labelStyle(.titleAndIcon)
                    .buttonStyle(.plain)
                    .accessibilityLabel("Aggiungi conto")
                }
            }
            .sheet(isPresented: $showingAddAccount) {
                AddAccountView()
            }
        }
    }

    private func sectionHeader(title: String, icon: String, color: Color, total: Decimal, groupID: String, isDebt: Bool = false) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.3)) {
                if collapsedGroups.contains(groupID) { collapsedGroups.remove(groupID) }
                else { collapsedGroups.insert(groupID) }
            }
        } label: {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .foregroundStyle(Color.orbText)
            }
            Image(systemName: "chevron.right")
                .font(.caption).rotationEffect(.degrees(collapsedGroups.contains(groupID) ? 0 : 90))
            Spacer()
            Text(formatSectionTotal(total, isDebt: isDebt))
                .foregroundStyle(Color.orbMuted)
        }
        .font(.orbSubheadline.bold())
        .textCase(nil).frame(minHeight: 44)
        }.buttonStyle(.plain)
        .accessibilityHint(collapsedGroups.contains(groupID) ? "Espandi gruppo" : "Comprimi gruppo")
    }

    private func formatSectionTotal(_ amount: Decimal, isDebt: Bool) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = "."
        formatter.decimalSeparator = ","

        let displayAmount = abs(amount)
        let amountString = formatter.string(from: displayAmount as NSDecimalNumber) ?? "0,00"

        let symbol = preferredCurrencyRecord?.displaySymbol ?? (appSettings.preferredCurrencyEnum.rawValue == "USD" ? "$" : appSettings.preferredCurrencyEnum.rawValue)


        // Per debiti (carte di credito, passività), mostra + o - in base al segno effettivo
        if isDebt {
            if amount < 0 {
                // Negativo = debito
                return "-\(symbol) \(amountString)"
            } else if amount > 0 {
                // Positivo = credito
                return "+\(symbol) \(amountString)"
            } else {
                // Zero
                return "\(symbol) \(amountString)"
            }
        } else {
            return "\(symbol) \(amountString)"
        }
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2

        let amountString = formatter.string(from: amount as NSDecimalNumber) ?? "0.00"
        return OrbCurrency.string(amount, symbol: appSettings.preferredCurrencyEnum.symbol)
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
        // For credit cards and liabilities, show absolute value (debts are stored as negative)
        let displayAmount = account.accountType == .liability ? abs(accountBalance) : accountBalance

        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = "."
        formatter.decimalSeparator = ","

        let amountString = formatter.string(from: displayAmount as NSDecimalNumber) ?? "0,00"

        // Usa la currency del conto, non quella preferita
        let symbol = account.currencyRecord?.displaySymbol ?? (account.currency.rawValue == "USD" ? "$" : account.currency.rawValue)


        return "\(symbol) \(amountString)"
    }

    private func balanceColor(for balance: Decimal) -> Color {
        if account.accountType == .creditCard || account.accountType == .liability {
            // For debts, negative (debt exists) is red, zero/positive is green
            return balance < 0 ? Color.orbNegative : Color.orbPositive
        } else {
            // For normal accounts, negative is red, positive is primary
            return balance < 0 ? Color.orbNegative : Color.orbText
        }
    }

    private func calculateBalance(for account: Account) -> Decimal {
        if account.investmentProfile != nil { return account.investmentNetWorth }
        var balance = account.initialBalance
        let tracker = DeletedTransactionTracker.shared

        // Filter out deleted/detached transactions to prevent crash
        // CRITICAL: Check tracker FIRST before accessing transactionType
        if let accountTransactions = account.transactions {
            for transaction in accountTransactions where !tracker.isDeleted(transaction.id) && transaction.modelContext != nil && transaction.status == .executed {
                // Determina l'importo da usare
                var amountToUse = transaction.amount

                // Per TRANSFER: usa sempre transaction.amount (importo originale nella valuta di origine)
                // destinationAmount è solo per il conto di destinazione (gestito in incomingTransfers)
                if transaction.transactionType != .transfer {
                    // Per expense/income/adjustment: usa destinationAmount se presente (conversione)
                    if let destAmount = transaction.destinationAmount {
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
                }

                switch transaction.transactionType {
                case .expense:
                    balance -= amountToUse
                case .income:
                    balance += amountToUse
                case .transfer:
                    balance -= amountToUse
                case .liabilityPayment:
                    let totalPayment = amountToUse + (transaction.interestAmount ?? 0)
                    balance -= totalPayment
                case .adjustment:
                    balance += amountToUse
                }
            }
        }

        // Filter out deleted/detached transfers to prevent crash
        // CRITICAL: Check tracker FIRST before accessing transactionType
        if let incoming = account.incomingTransfers {
            for transfer in incoming where !tracker.isDeleted(transfer.id) && transfer.modelContext != nil && transfer.status == .executed {
                if transfer.transactionType == .transfer {
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
                } else if transfer.transactionType == .liabilityPayment {
                    // Per pagamenti passività, accredita l'importo del debito (riduce la passività)
                    var amountToAdd: Decimal = 0
                    if let destAmount = transfer.destinationAmount {
                        amountToAdd = destAmount
                    } else if let transferCurr = transfer.currencyRecord,
                              let accountCurr = account.currencyRecord,
                              transferCurr.code != accountCurr.code {
                        amountToAdd = CurrencyService.shared.convert(
                            amount: transfer.amount,
                            from: transferCurr,
                            to: accountCurr,
                            context: modelContext
                        )
                    } else {
                        amountToAdd = transfer.amount
                    }
                    balance += amountToAdd
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
                    .font(.orbBody)
                    .foregroundStyle(Color.orbText)

                Text(account.accountType.rawValue)
                    .font(.orbCaption)
                    .foregroundStyle(Color.orbMuted)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(displayBalance(for: balance)).lineLimit(1).minimumScaleFactor(0.2)
                    .font(.orbBody.bold())
                    .foregroundStyle(balanceColor(for: balance))

                // Mostra saldo convertito nella valuta preferita solo se diversa
                if let convertedText = convertedBalanceText(for: balance) {
                    Text(convertedText).lineLimit(1).minimumScaleFactor(0.2)
                        .font(.orbCaption)
                        .foregroundStyle(Color.orbMuted)
                }
            }
        }
    }

    private func formatDecimal(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "0.00"
    }

    private func convertedBalanceText(for balance: Decimal) -> String? {
        guard let accountCurrency = account.currencyRecord,
              let preferredCurr = preferredCurrencyRecord,
              accountCurrency.code != preferredCurr.code else {
            return nil
        }

        let convertedBalance = CurrencyService.shared.convert(
            amount: balance,
            from: accountCurrency,
            to: preferredCurr,
            context: modelContext
        )

        let displayAmount = account.accountType == .liability ? abs(convertedBalance) : convertedBalance

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = "."
        formatter.decimalSeparator = ","

        let amountString = formatter.string(from: displayAmount as NSDecimalNumber) ?? "0,00"
        let symbol = preferredCurr.displaySymbol


        return "\(symbol) \(amountString)"
    }
}


#Preview {
    BalanceView()
        .environment(\.appSettings, AppSettings.shared)
        .modelContainer(for: [Account.self, Transaction.self, Category.self, CategoryGroup.self])
}
