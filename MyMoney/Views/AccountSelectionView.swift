//
//  AccountSelectionView.swift
//  MoneyTracker
//
//  Created on 2026-01-06.
//

import SwiftUI
import SwiftData

struct AccountSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.name) private var accounts: [Account]
    @Query private var transactions: [Transaction]

    @Binding var selectedAccount: Account?
    let showNavigationBar: Bool
    let transactionType: TransactionType?
    let selectedCategory: Category?
    let title: String
    let excludedAccount: Account?  // Conto da escludere (es. conto origine nei trasferimenti)

    init(
        selectedAccount: Binding<Account?>,
        showNavigationBar: Bool = true,
        transactionType: TransactionType? = nil,
        selectedCategory: Category? = nil,
        title: String = "Seleziona Conto",
        excludedAccount: Account? = nil
    ) {
        self._selectedAccount = selectedAccount
        self.showNavigationBar = showNavigationBar
        self.transactionType = transactionType
        self.selectedCategory = selectedCategory
        self.title = title
        self.excludedAccount = excludedAccount
    }

    // Filtra i conti in base al tipo di transazione
    var filteredAccounts: [Account] {
        var filtered: [Account]

        if let type = transactionType {
            switch type {
            case .expense, .income:
                // Per spese ed entrate, escludi passività e attività
                filtered = accounts.filter { account in
                    account.accountType != .liability && account.accountType != .asset
                }
            case .liabilityPayment:
                // Per pagamenti passività, mostra tutti i conti
                filtered = accounts
            case .transfer, .adjustment:
                // Per trasferimenti e aggiustamenti, mostra tutti i conti
                filtered = accounts
            }
        } else {
            filtered = accounts
        }

        // Escludi il conto specificato (es. conto origine nei trasferimenti)
        if let excluded = excludedAccount {
            filtered = filtered.filter { $0.id != excluded.id }
        }

        return filtered
    }

    // Ordina i conti: prima il più usato o predefinito, poi gli altri
    var sortedAccounts: [Account] {
        let filtered = filteredAccounts

        // Se c'è una categoria con conto predefinito, mettilo primo
        if let defaultAccount = selectedCategory?.defaultAccount,
           filtered.contains(where: { $0.id == defaultAccount.id }) {
            var sorted = filtered.filter { $0.id != defaultAccount.id }
            sorted.insert(defaultAccount, at: 0)
            return sorted
        }

        // Altrimenti ordina per uso recente
        let recentTransactions = transactions
            .filter { $0.status == .executed }
            .sorted { $0.date > $1.date }
            .prefix(5)

        // Conta l'uso di ogni conto nelle ultime 5 transazioni
        var accountUsage: [UUID: Int] = [:]
        for transaction in recentTransactions {
            if let accountId = transaction.account?.id {
                accountUsage[accountId, default: 0] += 1
            }
        }

        // Ordina per uso (decrescente), poi per nome
        return filtered.sorted { account1, account2 in
            let usage1 = accountUsage[account1.id] ?? 0
            let usage2 = accountUsage[account2.id] ?? 0

            if usage1 != usage2 {
                return usage1 > usage2
            }
            return account1.name < account2.name
        }
    }

    // Raggruppa conti per tipo (come in BalanceView)
    var groupedAccountsByType: [(AccountType, String, String, Color, [Account])] {
        // (type, title, icon, color, accounts)
        var groups: [(AccountType, String, String, Color, [Account])] = []

        let cashAccounts = sortedAccounts.filter { $0.accountType == .cash }
        if !cashAccounts.isEmpty {
            groups.append((.cash, "Contanti", "banknote.fill", .green, cashAccounts))
        }

        let paymentAccounts = sortedAccounts.filter { $0.accountType == .payment }
        if !paymentAccounts.isEmpty {
            groups.append((.payment, "Pagamento", "creditcard.fill", .blue, paymentAccounts))
        }

        let prepaidAccounts = sortedAccounts.filter { $0.accountType == .prepaidCard }
        if !prepaidAccounts.isEmpty {
            groups.append((.prepaidCard, "Carte Prepagate", "creditcard.fill", .cyan, prepaidAccounts))
        }

        let creditCardAccounts = sortedAccounts.filter { $0.accountType == .creditCard }
        if !creditCardAccounts.isEmpty {
            groups.append((.creditCard, "Carta di Credito", "creditcard.fill", .orange, creditCardAccounts))
        }

        let assetAccounts = sortedAccounts.filter { $0.accountType == .asset }
        if !assetAccounts.isEmpty {
            groups.append((.asset, "Attività", "building.columns.fill", .purple, assetAccounts))
        }

        let liabilityAccounts = sortedAccounts.filter { $0.accountType == .liability }
        if !liabilityAccounts.isEmpty {
            groups.append((.liability, "Passività", "chart.line.downtrend.xyaxis", .red, liabilityAccounts))
        }

        return groups
    }

    var body: some View {
        Group {
            if showNavigationBar {
                NavigationStack {
                    content
                        .navigationTitle(title)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Annulla") {
                                    dismiss()
                                }
                            }
                        }
                }
            } else {
                content
                    .navigationTitle(title)
            }
        }
    }

    var content: some View {
        List {
            ForEach(groupedAccountsByType, id: \.0) { _, title, icon, color, typeAccounts in
                Section {
                    ForEach(typeAccounts) { account in
                        Button {
                            selectedAccount = account
                            dismiss()
                        } label: {
                            AccountListRow(
                                account: account,
                                isSelected: selectedAccount?.id == account.id,
                                modelContext: modelContext
                            )
                        }
                    }
                } header: {
                    HStack(spacing: 6) {
                        Image(systemName: icon)
                            .foregroundStyle(color)
                        Text(title)
                            .foregroundStyle(.primary)
                    }
                    .font(.subheadline.bold())
                    .textCase(nil)
                }
            }
        }
        .refreshable {
            // Force refresh when user pulls down
            // The @Query will automatically update
        }
    }
}

struct AccountListRow: View {
    let account: Account
    let isSelected: Bool
    let modelContext: ModelContext

    // Query per far aggiornare la vista quando cambiano le transazioni
    @Query private var allTransactions: [Transaction]
    @Query private var exchangeRates: [ExchangeRate]

    // Calcola saldo on-the-fly - ora reagisce ai cambiamenti grazie alla @Query
    private var calculatedBalance: Decimal {
        // Forza il re-render quando cambiano transazioni o tassi
        _ = allTransactions.count
        _ = exchangeRates.count

        var balance = account.initialBalance
        let tracker = DeletedTransactionTracker.shared

        // Filter out deleted/detached transactions to prevent crash
        // CRITICAL: Check tracker FIRST before accessing transactionType
        if let accountTransactions = account.transactions {
            for transaction in accountTransactions where !tracker.isDeleted(transaction.id) && transaction.modelContext != nil && transaction.status == .executed {
                // IMPORTANTE: Usa la stessa logica di BalanceView
                var amountToUse = transaction.amount

                // Per TRANSFER: usa sempre transaction.amount (importo originale)
                // Per expense/income/adjustment: usa destinationAmount se presente (conversione valuta)
                if transaction.transactionType != .transfer {
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
            for transfer in incoming where !tracker.isDeleted(transfer.id) && transfer.modelContext != nil && transfer.status == .executed && transfer.transactionType == .transfer {
                var amountToAdd: Decimal = 0
                if let destAmount = transfer.destinationAmount {
                    amountToAdd = destAmount
                } else if let transferCurr = transfer.currencyRecord,
                          let accountCurr = account.currencyRecord {
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

        return balance
    }

    var body: some View {
        HStack(spacing: 12) {
            // Account Icon
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

                HStack(spacing: 4) {
                    if let currencyRecord = account.currencyRecord {
                        Text(currencyRecord.flagEmoji)
                            .font(.caption2)
                        Text(currencyRecord.code)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(formatAmount(calculatedBalance, currency: account.currencyRecord))
                    .font(.body)
                    .foregroundStyle(calculatedBalance < 0 ? .red : .primary)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(account.color)
                        .font(.caption)
                }
            }
        }
    }

    private func formatAmount(_ amount: Decimal, currency: CurrencyRecord?) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2

        let amountString = formatter.string(from: amount as NSDecimalNumber) ?? "0.00"
        return "\(currency?.code ?? "EUR") \(amountString)"
    }
}

#Preview {
    @Previewable @State var selectedAccount: Account? = nil

    AccountSelectionView(selectedAccount: $selectedAccount)
        .modelContainer(for: [Account.self, Transaction.self, Category.self, CategoryGroup.self])
}
