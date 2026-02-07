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
                            .foregroundStyle(.primary)
                        Spacer()
                        if let account = selectedAccount {
                            Text(account.name)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Seleziona conto")
                                .foregroundStyle(.secondary)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
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
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(formatAmount(calculatedBalance, currency: account.currency.rawValue))
                            .font(.title2.bold())
                            .foregroundStyle(balanceColor)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                }
            } header: {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundStyle(appSettings.accentColor)
                    Text("Saldo Storico")
                        .foregroundStyle(.primary)
                }
                .font(.subheadline.bold())
                .textCase(nil)
            } footer: {
                Text("Visualizza il saldo di un conto a una data e ora specifica nel passato")
            }

            // Sezione Dettaglio Transazioni
            if let account = selectedAccount {
                Section {
                    let relevantTransactions = getTransactionsUpToDate()

                    if relevantTransactions.isEmpty {
                        Text("Nessuna transazione fino a questa data")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(relevantTransactions) { transaction in
                            TransactionHistoryRow(transaction: transaction, account: account)
                        }
                    }
                } header: {
                    HStack(spacing: 6) {
                        Image(systemName: "list.bullet.clipboard")
                            .foregroundStyle(appSettings.accentColor)
                        Text("Transazioni fino a questa data")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("\(getTransactionsUpToDate().count)")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline.bold())
                    .textCase(nil)
                }
            }
        }
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
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let amountString = formatter.string(from: amount as NSDecimalNumber) ?? "0.00"
        return "\(currency) \(amountString)"
    }

    private var balanceColor: Color {
        if calculatedBalance > 0 {
            return .green
        } else if calculatedBalance < 0 {
            return .red
        } else {
            return .secondary
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
                                    .font(.body)
                                    .foregroundStyle(.primary)

                                Text(account.accountType.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if selectedAccount?.id == account.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(appSettings.accentColor)
                            }
                        }
                    }
                }
            }
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
                    .font(.body)
                    .foregroundStyle(.primary)

                Text(formatDate(transaction.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Amount
            Text(displayAmount)
                .font(.body.bold())
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

        let amountString = formatter.string(from: abs(amount) as NSDecimalNumber) ?? "0.00"
        return "\(sign)\(transaction.currency) \(amountString)"
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
                return .red
            case .income:
                return .green
            case .transfer:
                return .blue
            case .liabilityPayment:
                return .orange
            case .adjustment:
                return .orange
            }
        } else {
            return .green
        }
    }

    private var iconBackgroundColor: Color {
        iconColor.opacity(0.15)
    }

    private var amountColor: Color {
        if transaction.account?.id == account.id {
            switch transaction.transactionType {
            case .expense, .transfer, .liabilityPayment:
                return .red
            case .income:
                return .green
            case .adjustment:
                return transaction.amount >= 0 ? .green : .red
            }
        } else {
            return .green
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
