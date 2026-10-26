//
//  HistoricalBalanceView.swift
//  MoneyTracker
//
//  Created on 2026-01-26.
//

import SwiftUI
import SwiftData

struct HistoricalBalanceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appSettings) var appSettings
    @Query private var transactions: [Transaction]
    @Query private var accounts: [Account]

    @State private var selectedAccount: Account?
    @State private var selectedDate = Date()
    @State private var showingAccountPicker = false
    @State private var calculatedBalance: Decimal = 0

    var body: some View {
        List {
            // Sezione Saldo Storico
            Section {
                // Selettore conto
                Button {
                    showingAccountPicker = true
                } label: {
                    HStack {
                        Text("Conto")
                            .foregroundStyle(Color.orbText)
                        Spacer()
                        if let account = selectedAccount {
                            Text(account.name)
                                .foregroundStyle(Color.orbMuted)
                        } else {
                            Text("Seleziona conto")
                                .foregroundStyle(Color.orbMuted)
                        }
                        Image(systemName: "chevron.right")
                            .font(.orbCaption)
                            .foregroundStyle(Color.orbMuted)
                    }
                }

                // Selettore data e ora
                DatePicker(
                    "Data e Ora",
                    selection: $selectedDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .onChange(of: selectedDate) { _, _ in
                    calculateHistoricalBalance()
                }

                // Risultato
                if let account = selectedAccount {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Saldo al \(formatDateTime(selectedDate))")
                            .font(.orbSubheadline)
                            .foregroundStyle(Color.orbMuted)

                        Text(formatAmount(calculatedBalance, currency: account.currency.rawValue))
                            .font(.orbTitle2.bold())
                            .foregroundStyle(balanceColor)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                }
            } header: {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundStyle(Color.orbHighlight)
                    Text("Saldo Storico")
                        .foregroundStyle(Color.orbText)
                }
                .font(.orbSubheadline.bold())
                .textCase(nil)
            } footer: {
                Text("Visualizza il saldo di un conto a una data e ora specifica nel passato")
            }.listRowBackground(Color.orbCard)

            if let account = selectedAccount {
                Section("Patrimonio nel tempo") {
                    OrbHistoryChart(account: account, transactions: transactions, end: selectedDate)
                }.listRowBackground(Color.orbCard)
            }
            // Sezione Dettaglio Transazioni
            if let account = selectedAccount {
                Section {
                    let relevantTransactions = getTransactionsUpToDate()

                    if relevantTransactions.isEmpty {
                        Text("Nessuna transazione fino a questa data")
                            .foregroundStyle(Color.orbMuted)
                            .font(.orbSubheadline)
                    } else {
                        ForEach(relevantTransactions) { transaction in
                            TransactionHistoryRow(transaction: transaction, account: account)
                        }
                    }
                } header: {
                    HStack(spacing: 6) {
                        Image(systemName: "list.bullet.clipboard")
                            .foregroundStyle(Color.orbHighlight)
                        Text("Transazioni fino a questa data")
                            .foregroundStyle(Color.orbText)
                        Spacer()
                        Text("\(getTransactionsUpToDate().count)")
                            .foregroundStyle(Color.orbMuted)
                    }
                    .font(.orbSubheadline.bold())
                    .textCase(nil)
                }.listRowBackground(Color.orbCard)
            }
        }.orbScreen()
        .navigationTitle("Saldo Storico")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAccountPicker) {
            AccountPickerSheet(
                accounts: accounts,
                selectedAccount: $selectedAccount,
                onSelect: {
                    showingAccountPicker = false
                    calculateHistoricalBalance()
                }
            )
        }
        .onAppear {
            // Seleziona il primo conto se disponibile
            if selectedAccount == nil, let firstAccount = accounts.first {
                selectedAccount = firstAccount
                calculateHistoricalBalance()
            }
        }
    }

    // MARK: - Helper Methods

    private func calculateHistoricalBalance() {
        guard let account = selectedAccount else {
            calculatedBalance = 0
            return
        }

        // Se la data selezionata è prima della creazione del conto, il saldo è 0
        if selectedDate < account.createdAt {
            calculatedBalance = 0
            return
        }

        if let profile = account.investmentProfile {
            calculatedBalance = account.investmentValue(profile: profile, at: selectedDate)
            return
        }

        // Filtra le transazioni fino alla data/ora selezionata
        let relevantTransactions = transactions.filter { transaction in
            guard transaction.status == .executed else { return false }
            guard transaction.date <= selectedDate else { return false }

            // Include transazioni dove questo conto è coinvolto
            return transaction.account?.id == account.id ||
                   transaction.destinationAccount?.id == account.id
        }

        // Calcola il saldo partendo dal saldo iniziale del conto
        var balance: Decimal = account.initialBalance

        for transaction in relevantTransactions {
            let amount = transaction.amount

            if transaction.account?.id == account.id {
                // Questo conto è il conto principale
                switch transaction.transactionType {
                case .expense:
                    balance -= amount
                case .income:
                    balance += amount
                case .transfer:
                    // Trasferimento in uscita
                    balance -= amount
                case .liabilityPayment:
                    // Pagamento passività: sottrae amount + interesse
                    let totalPayment = amount + (transaction.interestAmount ?? 0)
                    balance -= totalPayment
                case .adjustment:
                    // L'aggiustamento può essere positivo o negativo
                    // Usa il segno dell'importo
                    balance += amount
                }
            } else if transaction.destinationAccount?.id == account.id {
                // Questo conto è il destinatario (solo trasferimenti)
                if transaction.transactionType == .transfer {
                    balance += (transaction.destinationAmount ?? amount)
                }
            }
        }

        calculatedBalance = balance
    }

    private func getTransactionsUpToDate() -> [Transaction] {
        guard let account = selectedAccount else { return [] }

        return transactions.filter { transaction in
            guard transaction.status == .executed else { return false }
            guard transaction.date <= selectedDate else { return false }

            return transaction.account?.id == account.id ||
                   transaction.destinationAccount?.id == account.id
        }.sorted { $0.date > $1.date }
    }

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateFormat = "d MMMM yyyy 'alle' HH:mm"
        return formatter.string(from: date)
    }

    private func formatAmount(_ amount: Decimal, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let amountString = formatter.string(from: amount as NSDecimalNumber) ?? "0.00"
        return OrbCurrency.string(amount, symbol: Currency(rawValue: currency)?.symbol ?? currency)
    }

    private var balanceColor: Color {
        if calculatedBalance > 0 {
            return Color.orbPositive
        } else if calculatedBalance < 0 {
            return Color.orbNegative
        } else {
            return Color.orbMuted
        }
    }
}

// MARK: - Account Picker Sheet

struct AccountPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appSettings) var appSettings

    let accounts: [Account]
    @Binding var selectedAccount: Account?
    let onSelect: () -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(accounts) { account in
                    Button {
                        selectedAccount = account
                        onSelect()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(account.name)
                                    .font(.orbBody)
                                    .foregroundStyle(Color.orbText)

                                Text(account.accountType.rawValue)
                                    .font(.orbCaption)
                                    .foregroundStyle(Color.orbMuted)
                            }

                            Spacer()

                            if selectedAccount?.id == account.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.orbHighlight)
                            }
                        }
                    }
                }
            }.orbScreen()
            .navigationTitle("Seleziona Conto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Transaction History Row

struct TransactionHistoryRow: View {
    @Environment(\.appSettings) var appSettings
    let transaction: Transaction
    let account: Account

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconBackgroundColor)
                    .frame(width: 40, height: 40)

                Image(systemName: iconName)
                    .font(.system(size: 16))
                    .foregroundStyle(iconColor)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(displayTitle)
                    .font(.orbBody)
                    .foregroundStyle(Color.orbText)

                Text(formatDate(transaction.date))
                    .font(.orbCaption)
                    .foregroundStyle(Color.orbMuted)
            }

            Spacer()

            // Amount
            Text(displayAmount)
                .font(.orbBody.bold())
                .foregroundStyle(amountColor)
        }
        .padding(.vertical, 4)
    }

    private var displayTitle: String {
        if transaction.transactionType == .transfer {
            if transaction.account?.id == account.id {
                // Trasferimento in uscita
                return "Trasferito a: \(transaction.destinationAccount?.name ?? "Sconosciuto")"
            } else {
                // Trasferimento in entrata
                return "Ricevuto da: \(transaction.account?.name ?? "Sconosciuto")"
            }
        }
        return transaction.category?.name ?? transaction.transactionType.rawValue
    }

    private var displayAmount: String {
        let amount = transaction.amount
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2

        let sign: String
        if transaction.account?.id == account.id {
            // Conto principale
            switch transaction.transactionType {
            case .expense, .transfer, .liabilityPayment:
                sign = "-"
            case .income:
                sign = "+"
            case .adjustment:
                sign = amount >= 0 ? "+" : ""
            }
        } else {
            // Trasferimento in entrata
            sign = "+"
        }

        return sign + OrbCurrency.string(abs(amount), symbol: transaction.currencyRecord?.displaySymbol ?? transaction.currency.symbol)
    }

    private var iconName: String {
        if transaction.account?.id == account.id {
            switch transaction.transactionType {
            case .expense:
                return transaction.category?.icon ?? "cart"
            case .income:
                return transaction.category?.icon ?? "dollarsign.circle"
            case .liabilityPayment:
                return "creditcard.and.123"
            case .transfer:
                return "arrow.up.right"
            case .adjustment:
                return "plus.minus"
            }
        } else {
            return "arrow.down.left"
        }
    }

    private var iconColor: Color {
        if transaction.account?.id == account.id {
            switch transaction.transactionType {
            case .expense:
                return Color.orbNegative
            case .income:
                return Color.orbPositive
            case .transfer:
                return Color.orbAccent
            case .liabilityPayment:
                return Color.orbHighlight
            case .adjustment:
                return Color.orbHighlight
            }
        } else {
            return Color.orbPositive
        }
    }

    private var iconBackgroundColor: Color {
        iconColor.opacity(0.15)
    }

    private var amountColor: Color {
        if transaction.account?.id == account.id {
            switch transaction.transactionType {
            case .expense, .transfer, .liabilityPayment:
                return Color.orbNegative
            case .income:
                return Color.orbPositive
            case .adjustment:
                return transaction.amount >= 0 ? Color.orbPositive : Color.orbNegative
            }
        } else {
            return Color.orbPositive
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateFormat = "d MMM yyyy, HH:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        HistoricalBalanceView()
            .environment(\.appSettings, AppSettings.shared)
            .modelContainer(for: [Transaction.self, Account.self])
    }
}
