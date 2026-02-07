//
//  AccountDetailView.swift
//  MoneyTracker
//
//  Created on 2026-01-01.
//

import SwiftUI
import SwiftData

enum SortOption: String, CaseIterable {
    case dateDescending = "Data (recente)"
    case dateAscending = "Data (meno recente)"
    case amountDescending = "Importo (maggiore)"
    case amountAscending = "Importo (minore)"
}

struct AccountDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appSettings) var appSettings
    @Environment(\.colorScheme) var colorScheme
    @Bindable var account: Account

    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingBalanceAdjustment = false
    @State private var selectedDate: Date?
    @State private var sortOption: SortOption = .dateDescending
    @State private var showingFilters = false
    @State private var transactionToDelete: Transaction?
    @State private var showingDeleteRecurringAlert = false
    @State private var showingAddTransaction = false
    @State private var selectedTransactionType: TransactionType = .expense

    var filteredTransactions: [Transaction] {
        let tracker = DeletedTransactionTracker.shared

        // Include sia le transazioni in uscita che i trasferimenti in entrata
        // CRITICAL: Check tracker FIRST before accessing transactionType
        let outgoingTransactions = (account.transactions ?? [])
            .filter { !tracker.isDeleted($0.id) && $0.modelContext != nil && $0.status != .pending }

        let incomingTransfers = (account.incomingTransfers ?? [])
            .filter { !tracker.isDeleted($0.id) && $0.modelContext != nil && $0.status != .pending && $0.transactionType == .transfer }

        var allTransactions = outgoingTransactions + incomingTransfers

        // Applica filtro per data se selezionato
        if let selectedDate = selectedDate {
            allTransactions = allTransactions.filter { transaction in
                Calendar.current.isDate(transaction.date, inSameDayAs: selectedDate)
            }
        }

        return allTransactions
    }

    var sortedTransactions: [Transaction] {
        switch sortOption {
        case .dateDescending:
            return filteredTransactions.sorted { $0.date > $1.date }
        case .dateAscending:
            return filteredTransactions.sorted { $0.date < $1.date }
        case .amountDescending:
            return filteredTransactions.sorted { $0.amount > $1.amount }
        case .amountAscending:
            return filteredTransactions.sorted { $0.amount < $1.amount }
        }
    }

    // Raggruppa transazioni per data
    var groupedTransactions: [(Date, [Transaction])] {
        let grouped = Dictionary(grouping: sortedTransactions) { transaction in
            Calendar.current.startOfDay(for: transaction.date)
        }
        return grouped.sorted { $0.key > $1.key }
    }

    // Calcola saldo on-the-fly
    private var calculatedBalance: Decimal {
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
            for transfer in incoming where !tracker.isDeleted(transfer.id) && transfer.modelContext != nil && transfer.status == .executed && transfer.transactionType == .transfer {
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

    // Balance label based on account type
    private var balanceLabel: String {
        switch account.accountType {
        case .creditCard, .liability:
            return "Debito Attuale"
        default:
            return "Saldo Attuale"
        }
    }

    // Balance color based on account type and value
    private var balanceColor: Color {
        if account.accountType == .creditCard || account.accountType == .liability {
            // For debts, negative (debt exists) is red, zero/positive is green
            return calculatedBalance < 0 ? .red : .green
        } else {
            // For normal accounts, negative is red, positive is primary
            return calculatedBalance < 0 ? .red : .primary
        }
    }

    // Format balance display based on account type
    private func formatBalance(_ amount: Decimal) -> String {
        if account.accountType == .creditCard || account.accountType == .liability {
            // For debts, show absolute value (debts are stored as negative)
            let debtAmount = abs(amount)
            return "\(account.currency.rawValue) \(formatDecimal(debtAmount))"
        } else {
            return "\(account.currency.rawValue) \(formatDecimal(amount))"
        }
    }

    var body: some View {
        List {
            // Header Section
            Section {
                VStack(spacing: 16) {
                    // Mostra immagine personalizzata se esiste, altrimenti icona
                    if let imageData = account.imageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(account.color, lineWidth: 3)
                            )
                    } else {
                        ZStack {
                            Circle()
                                .fill(account.color.opacity(0.2))
                                .frame(width: 80, height: 80)

                            Image(systemName: account.icon)
                                .font(.system(size: 40))
                                .foregroundStyle(account.color)
                        }
                    }

                    VStack(spacing: 4) {
                        Text(account.name)
                            .font(.title.bold())

                        Text(account.accountType.rawValue)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 4) {
                        Text(balanceLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(formatBalance(calculatedBalance))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(balanceColor)
                    }

                    // Show credit limit for credit cards
                    if account.accountType == .creditCard, let limit = account.creditLimit, limit > 0 {
                        HStack(spacing: 4) {
                            Text("Limite:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(account.currency.rawValue) \(formatDecimal(limit))")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)

                            // Available credit
                            let availableCredit = limit + calculatedBalance // balance is negative for debt
                            Text("• Disponibile:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(account.currency.rawValue) \(formatDecimal(availableCredit))")
                                .font(.caption.bold())
                                .foregroundStyle(availableCredit > 0 ? .green : .red)
                        }
                    }

                    if !account.accountDescription.isEmpty {
                        Text(account.accountDescription)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            // Filtri Section
            if showingFilters {
                Section {
                    // Filtro data
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundStyle(appSettings.accentColor)

                        if let selectedDate = selectedDate {
                            DatePicker(
                                "Data",
                                selection: Binding(
                                    get: { selectedDate },
                                    set: { self.selectedDate = $0 }
                                ),
                                displayedComponents: .date
                            )
                            .labelsHidden()

                            Button {
                                self.selectedDate = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text("Filtra per data")
                                .foregroundStyle(.secondary)

                            Spacer()

                            Button {
                                self.selectedDate = Date()
                            } label: {
                                Text("Seleziona")
                                    .font(.subheadline)
                                    .foregroundStyle(appSettings.accentColor)
                            }
                        }
                    }

                    // Ordinamento
                    HStack {
                        Image(systemName: "arrow.up.arrow.down")
                            .foregroundStyle(appSettings.accentColor)

                        Picker("Ordina", selection: $sortOption) {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                } header: {
                    Text("Filtri")
                }
            }

            // Transactions Sections
            if sortedTransactions.isEmpty {
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "list.bullet.clipboard")
                            .font(.system(size: 50))
                            .foregroundStyle(.secondary)

                        Text(selectedDate == nil ? "Nessuna transazione" : "Nessuna transazione per questa data")
                            .font(.headline)

                        Text(selectedDate == nil ? "Le transazioni per questo conto appariranno qui" : "Prova a selezionare un'altra data")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowBackground(Color.clear)
                }
            } else {
                ForEach(groupedTransactions, id: \.0) { date, transactions in
                    Section {
                        ForEach(transactions) { transaction in
                            NavigationLink {
                                EditTransactionView(transaction: transaction)
                            } label: {
                                TransactionRowView(transaction: transaction, isCompact: true, contextAccount: account)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    handleDeleteTransaction(transaction)
                                } label: {
                                    Label("Elimina", systemImage: "trash")
                                }
                            }
                        }
                    } header: {
                        Text(formatDateHeader(date))
                            .font(.subheadline.bold())
                            .textCase(nil)
                    }
                }
            }
        }
        .navigationTitle("Dettagli Conto")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showingFilters.toggle()
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle\(showingFilters ? ".fill" : "")")
                        .foregroundStyle(appSettings.accentColor)
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        selectedTransactionType = .expense
                        showingAddTransaction = true
                    } label: {
                        Label("Nuova Transazione", systemImage: "plus.circle")
                    }

                    Divider()

                    Button {
                        showingBalanceAdjustment = true
                    } label: {
                        Label("Aggiusta Saldo", systemImage: "slider.horizontal.3")
                    }

                    Divider()

                    Button {
                        showingEditSheet = true
                    } label: {
                        Label("Modifica", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("Elimina", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditAccountView(account: account)
        }
        .sheet(isPresented: $showingBalanceAdjustment) {
            BalanceAdjustmentView(account: account)
        }
        .sheet(isPresented: $showingAddTransaction) {
            AddTransactionView(transactionType: selectedTransactionType, defaultAccount: account)
        }
        .alert("Elimina Conto", isPresented: $showingDeleteAlert) {
            Button("Annulla", role: .cancel) { }
            Button("Elimina", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("Sei sicuro di voler eliminare questo conto? Tutte le transazioni associate verranno eliminate.")
        }
        .onAppear {
            account.updateBalance(context: modelContext)
        }
        .alert("Elimina Transazione Ricorrente", isPresented: $showingDeleteRecurringAlert) {
            Button("Annulla", role: .cancel) {
                transactionToDelete = nil
            }
            Button("Solo questa", role: .destructive) {
                if let transaction = transactionToDelete {
                    deleteTransaction(transaction, deleteAll: false)
                }
                transactionToDelete = nil
            }
            Button("Elimina tutte per sempre", role: .destructive) {
                if let transaction = transactionToDelete {
                    deleteTransaction(transaction, deleteAll: true)
                }
                transactionToDelete = nil
            }
        } message: {
            Text("Vuoi eliminare solo questa occorrenza o tutte le transazioni ricorrenti?")
        }
    }

    private func formatDecimal(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "0.00"
    }

    private func formatDateHeader(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Oggi"
        } else if calendar.isDateInYesterday(date) {
            return "Ieri"
        } else {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "it_IT")
            formatter.dateFormat = "EEEE, d MMMM yyyy"
            return formatter.string(from: date).capitalized
        }
    }

    private func handleDeleteTransaction(_ transaction: Transaction) {
        // Se è una transazione ricorrente, mostra l'alert
        if transaction.isRecurring {
            transactionToDelete = transaction
            showingDeleteRecurringAlert = true
        } else {
            // Altrimenti elimina direttamente
            deleteTransaction(transaction, deleteAll: false)
        }
    }

    private func deleteTransaction(_ transaction: Transaction, deleteAll: Bool) {
        let transactionId = transaction.id
        let isRecurring = transaction.isRecurring
        let parentRecurringId = transaction.parentRecurringTransactionId
        let isScheduled = transaction.isScheduled
        let accountToUpdate = account

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 50_000_000)

            let allTransactions = accountToUpdate.transactions ?? []

            if deleteAll && isRecurring {
                let templateId = parentRecurringId ?? transactionId

                let allRelated = allTransactions.filter {
                    $0.id == templateId || $0.parentRecurringTransactionId == templateId
                }

                for related in allRelated {
                    let relatedId = related.id
                    let relatedIsScheduled = related.isScheduled

                    if relatedIsScheduled {
                        LocalNotificationManager.shared.cancelNotification(transactionId: relatedId)
                    }
                    modelContext.delete(related)
                }
            } else {
                if let transactionToDelete = allTransactions.first(where: { $0.id == transactionId }) {
                    if isScheduled {
                        LocalNotificationManager.shared.cancelNotification(transactionId: transactionId)
                    }
                    modelContext.delete(transactionToDelete)
                }
            }

            accountToUpdate.updateBalance(context: modelContext)
            try? modelContext.save()
        }
    }

    private func deleteAccount() {
        modelContext.delete(account)
        try? modelContext.save()
        dismiss()
    }
}

// Nuovo componente che segue lo stile di TodayView
struct AccountTransactionRow: View {
    @Environment(\.appSettings) var appSettings
    @Environment(\.colorScheme) var colorScheme
    let transaction: Transaction
    let account: Account

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Icon (custom image or SF Symbol)
                if let category = transaction.category,
                   let imageData = category.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                } else {
                    ZStack {
                        Circle()
                            .fill(iconBackgroundColor)
                            .frame(width: 50, height: 50)

                        Image(systemName: transaction.category?.icon ?? defaultIcon)
                            .font(.title3)
                            .foregroundStyle(iconColor)
                    }
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayTitle)
                        .font(.body.bold())
                        .foregroundStyle(.primary)
                    
                    // Dettagli trasferimento (se applicabile)
                    if let transferDetail = transferDetail {
                        Text(transferDetail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 4) {
                        Text(transaction.date.formatted(date: .omitted, time: .shortened))
                            .font(.caption)

                        if transaction.isScheduled && transaction.status == .executed {
                            Image(systemName: "bolt.fill")
                                .font(.caption2)
                        }
                    }
                    .foregroundStyle(.secondary)
                }

                Spacer()

                // Amount
                VStack(alignment: .trailing, spacing: 4) {
                    Text(transaction.displayAmount)
                        .font(.body.bold())
                        .foregroundStyle(.primary)
                }
            }
            .padding()

            // Color line at the bottom
            UnevenRoundedRectangle(
                bottomLeadingRadius: 12,
                bottomTrailingRadius: 12
            )
            .fill(lineColor)
            .frame(height: 3)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        )
    }

    private var displayTitle: String {
        // Per i trasferimenti, mostra solo "Trasferimento"
        if transaction.transactionType == .transfer {
            return "Trasferimento"
        }
        
        // Per gli altri tipi, mostra categoria o tipo
        return transaction.category?.name ?? transaction.transactionType.rawValue
    }
    
    private var transferDetail: String? {
        // Dettagli del trasferimento (conti coinvolti)
        guard transaction.transactionType == .transfer else { return nil }
        
        if transaction.account?.id == account.id {
            // Trasferimento in uscita
            return "→ \(transaction.destinationAccount?.name ?? "Sconosciuto")"
        } else if transaction.destinationAccount?.id == account.id {
            // Trasferimento in entrata
            return "← \(transaction.account?.name ?? "Sconosciuto")"
        }
        
        return nil
    }
    
    private var iconBackgroundColor: Color {
        return (transaction.category?.color ?? appSettings.accentColor).opacity(0.15)
    }

    private var iconColor: Color {
        return transaction.category?.color ?? appSettings.accentColor
    }

    private var defaultIcon: String {
        switch transaction.transactionType {
        case .expense: return "cart"
        case .income: return "dollarsign.circle"
        case .transfer: return "arrow.left.arrow.right"
        case .liabilityPayment: return "creditcard.and.123"
        case .adjustment: return "plus.minus"
        }
    }

    private var amountColor: Color {
        .primary
    }

    private var amountBackgroundColor: Color {
        switch transaction.transactionType {
        case .expense:
            return .red.opacity(0.15)
        case .income:
            return .green.opacity(0.15)
        case .transfer:
            return .blue.opacity(0.15)
        case .liabilityPayment:
            return .orange.opacity(0.15)
        case .adjustment:
            return .orange.opacity(0.15)
        }
    }

    private var lineColor: Color {
        switch transaction.transactionType {
        case .expense:
            return .red
        case .income:
            return .green
        case .liabilityPayment:
            return .orange
        case .transfer:
            return .blue
        case .adjustment:
            return .orange
        }
    }
}

// Manteniamo il vecchio TransactionRow per retrocompatibilità
struct TransactionRow: View {
    @Environment(\.modelContext) private var modelContext

    let transaction: Transaction

    var needsConversion: Bool {
        guard let account = transaction.account,
              let transactionCurr = transaction.currencyRecord,
              let accountCurr = account.currencyRecord else { return false }
        return transactionCurr.code != accountCurr.code
    }

    var convertedAmount: Decimal? {
        guard needsConversion,
              let account = transaction.account,
              let transactionCurr = transaction.currencyRecord,
              let accountCurr = account.currencyRecord else { return nil }

        return CurrencyService.shared.convert(
            amount: transaction.amount,
            from: transactionCurr,
            to: accountCurr,
            context: modelContext
        )
    }

    // Precompute a formatted converted display string for the target account currency
    private var formattedConvertedDisplay: String? {
        guard let converted = convertedAmount, let account = transaction.account else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let amountString = formatter.string(from: converted as NSDecimalNumber) ?? "0.00"
        return "\(account.currency.symbol)\(amountString)"
    }

    var body: some View {
        HStack(spacing: 16) {
            // Category icon (custom image or SF Symbol)
            if let category = transaction.category,
               let imageData = category.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
            } else {
                ZStack {
                    Circle()
                        .fill(Color(hex: transaction.transactionType.color)?.opacity(0.2) ?? .blue.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: transaction.category?.icon ?? transaction.transactionType.icon)
                        .foregroundStyle(Color(hex: transaction.transactionType.color) ?? .blue)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(transaction.category?.name ?? transaction.transactionType.rawValue)
                        .font(.body.bold())

                    // Icona per transazioni programmate eseguite
                    if transaction.isScheduled && transaction.status == .executed {
                        Image(systemName: "clock.badge.checkmark.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }

                Text(transaction.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !transaction.notes.isEmpty {
                    Text(transaction.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                // Mostra valuta originale se diversa
                if needsConversion {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption2)
                        Text("Originale: \(transaction.displayAmount)")
                    }
                    .font(.caption)
                    .foregroundStyle(.blue)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let displayText = formattedConvertedDisplay {
                    Text(formatTransactionAmount(displayText))
                        .font(.body.bold())
                        .foregroundStyle(transactionColor)
                } else {
                    Text(formatTransactionAmount(transaction.displayAmount))
                        .font(.body.bold())
                        .foregroundStyle(transactionColor)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        )
    }

    private func formatTransactionAmount(_ displayAmount: String) -> String {
        switch transaction.transactionType {
        case .expense:
            return "-\(displayAmount)"
        case .income:
            return "+\(displayAmount)"
        case .transfer:
            return "-\(displayAmount)"
        case .liabilityPayment:
            return "-\(displayAmount)"
        case .adjustment:
            // Amount is already signed
            let sign = transaction.amount >= 0 ? "+" : "-"
            return "\(sign)\(displayAmount)"
        }
    }

    private var transactionColor: Color {
        switch transaction.transactionType {
        case .expense:
            return .red
        case .income:
            return .green
        case .liabilityPayment:
            return .orange
        case .transfer:
            return .blue
        case .adjustment:
            return transaction.amount >= 0 ? .green : .red
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Account.self, Transaction.self, configurations: config)

    let account = Account(name: "Test Account", accountType: .payment, currency: .EUR)
    container.mainContext.insert(account)

    return NavigationStack {
        AccountDetailView(account: account)
    }
    .modelContainer(container)
}

