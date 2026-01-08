//
//  EditTransactionView.swift
//  MoneyTracker
//
//  Created on 2026-01-06.
//

import SwiftUI
import SwiftData

struct EditTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var accounts: [Account]
    @Query private var categories: [Category]
    @Query private var allCurrencies: [CurrencyRecord]

    let transaction: Transaction

    @State private var amount: String
    @State private var selectedAccount: Account?
    @State private var selectedDestinationAccount: Account?
    @State private var selectedCategory: Category?
    @State private var notes: String
    @State private var selectedDate: Date
    @State private var showingCategoryPicker = false
    @State private var selectedTransactionCurrencyRecord: CurrencyRecord?

    // Scheduling fields
    @State private var isScheduled: Bool
    @State private var scheduledDate: Date
    @State private var isAutomatic: Bool

    // Deletion dialog
    @State private var showingDeleteDialog = false
    @State private var showingRecurringDeleteOptions = false

    init(transaction: Transaction) {
        self.transaction = transaction

        // Convert Decimal to String properly
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        let amountString = formatter.string(from: transaction.amount as NSDecimalNumber) ?? "0"

        _amount = State(initialValue: amountString)
        _selectedAccount = State(initialValue: transaction.account)
        _selectedDestinationAccount = State(initialValue: transaction.destinationAccount)
        _selectedCategory = State(initialValue: transaction.category)
        _notes = State(initialValue: transaction.notes)
        _selectedDate = State(initialValue: transaction.date)
        _selectedTransactionCurrencyRecord = State(initialValue: transaction.currencyRecord)

        // Initialize scheduling fields
        _isScheduled = State(initialValue: transaction.isScheduled)
        _scheduledDate = State(initialValue: transaction.scheduledDate ?? Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())
        _isAutomatic = State(initialValue: transaction.isAutomatic)
    }

    var transactionCurrencyRecord: CurrencyRecord? {
        selectedTransactionCurrencyRecord ?? selectedAccount?.currencyRecord
    }

    var body: some View {
        NavigationStack {
            Form {
                // Amount Section
                Section {
                    HStack {
                        Text(transactionCurrencyRecord?.symbol ?? "€")
                            .font(.title2)
                            .foregroundStyle(.secondary)

                        TextField("Importo", text: $amount)
                            .keyboardType(.decimalPad)
                            .font(.title2.bold())
                    }
                }

                // Category Section
                if transaction.transactionType != .transfer {
                    Section {
                        Button {
                            showingCategoryPicker = true
                        } label: {
                            HStack {
                                Text("Categoria")
                                    .foregroundStyle(.primary)

                                Spacer()

                                if let category = selectedCategory {
                                    HStack(spacing: 8) {
                                        Image(systemName: category.icon)
                                            .foregroundStyle(category.color)
                                        Text(category.name)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }

                // Account Section
                Section {
                    NavigationLink {
                        AccountSelectionView(selectedAccount: $selectedAccount, showNavigationBar: false)
                    } label: {
                        HStack {
                            Text("Conto")
                                .foregroundStyle(.primary)

                            Spacer()

                            if let account = selectedAccount {
                                HStack(spacing: 8) {
                                    if let imageData = account.imageData, let uiImage = UIImage(data: imageData) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 28, height: 28)
                                            .clipShape(Circle())
                                    } else {
                                        Image(systemName: account.icon)
                                            .foregroundStyle(account.color)
                                    }

                                    Text(account.name)
                                        .foregroundStyle(.secondary)

                                    if let currency = account.currencyRecord {
                                        Text(currency.flagEmoji)
                                            .font(.caption)
                                    }
                                }
                            } else {
                                Text("Seleziona")
                                    .foregroundStyle(.secondary)
                            }

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                // Date Section
                Section {
                    DatePicker("Data", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                }

                // Notes Section
                Section {
                    TextField("Note (opzionale)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Note")
                }

                // MARK: - Scheduled Transaction Section
                Section {
                    Toggle(isOn: $isScheduled) {
                        HStack {
                            Image(systemName: "clock.badge.checkmark")
                                .foregroundStyle(.orange)
                            Text("Programma Transazione")
                        }
                    }
                    .onChange(of: isScheduled) { _, newValue in
                        if newValue && transaction.status != .pending {
                            // Set default scheduled date if enabling for first time
                            scheduledDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                        }
                    }

                    if isScheduled {
                        DatePicker("Data Programmata", selection: $scheduledDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.compact)

                        Toggle(isOn: $isAutomatic) {
                            HStack {
                                Image(systemName: isAutomatic ? "bolt.fill" : "hand.tap.fill")
                                    .foregroundStyle(isAutomatic ? .blue : .orange)
                                Text("Esecuzione Automatica")
                            }
                        }

                        if isAutomatic {
                            Text("La transazione sarà eseguita automaticamente alla data impostata.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Riceverai una notifica per confermare manualmente la transazione.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        // Show current status if already scheduled
                        if transaction.isScheduled {
                            HStack {
                                Text("Stato:")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                HStack(spacing: 4) {
                                    Image(systemName: transaction.status.icon)
                                    Text(transaction.status.rawValue)
                                }
                                .foregroundStyle(Color(hex: transaction.status.color) ?? .primary)
                            }
                            .font(.caption)
                        }
                    }
                } header: {
                    Text("Programmazione")
                } footer: {
                    if isScheduled {
                        Text("Le transazioni programmate vengono eseguite alla data impostata e non influenzano il saldo fino all'esecuzione.")
                    }
                }

                // MARK: - Recurring Transaction Info (Read-only)
                if transaction.isRecurring || transaction.parentRecurringTransactionId != nil {
                    Section {
                        HStack {
                            Image(systemName: "repeat.circle.fill")
                                .foregroundStyle(.purple)
                            Text(transaction.isRecurring ? "Template Ricorrente" : "Istanza Ricorrente")
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.purple)
                        }

                        if let rule = transaction.recurrenceRule {
                            HStack {
                                Image(systemName: rule.icon)
                                    .foregroundStyle(.purple)
                                Text("Frequenza")
                                Spacer()
                                Text(rule.displayString)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if let endDate = transaction.recurrenceEndDate {
                            HStack {
                                Image(systemName: "calendar.badge.clock")
                                    .foregroundStyle(.orange)
                                Text("Fino a")
                                Spacer()
                                Text(endDate.formatted(date: .abbreviated, time: .omitted))
                                    .foregroundStyle(.secondary)
                            }
                        } else if transaction.isRecurring || transaction.parentRecurringTransactionId != nil {
                            HStack {
                                Image(systemName: "infinity.circle")
                                    .foregroundStyle(.blue)
                                Text("Ripetizione Infinita")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        Text("Ripetizione")
                    } footer: {
                        if transaction.isRecurring {
                            Text("Questo è il template principale della serie ricorrente.")
                        } else {
                            Text("Questa è un'istanza di una serie ricorrente. La modifica influenzerà solo questa istanza.")
                        }
                    }

                    // MARK: - Gestione Ripetizione
                    if transaction.parentRecurringTransactionId != nil {
                        Section {
                            Button {
                                stopRecurrenceFromHere()
                            } label: {
                                HStack {
                                    Image(systemName: "stop.circle")
                                        .foregroundStyle(.orange)
                                    Text("Interrompi Ripetizione da Qui")
                                    Spacer()
                                }
                            }

                            Button {
                                showingRecurringDeleteOptions = true
                            } label: {
                                HStack {
                                    Image(systemName: "trash.circle")
                                        .foregroundStyle(.red)
                                    Text("Elimina Istanze...")
                                    Spacer()
                                }
                            }
                        } header: {
                            Text("Gestione Serie")
                        } footer: {
                            Text("Puoi interrompere la ripetizione o eliminare istanze specifiche della serie.")
                        }
                    }
                }

                // MARK: - Manual Confirmation Buttons
                if transaction.status == .pending && !transaction.isAutomatic {
                    Section {
                        VStack(spacing: 12) {
                            Text("Questa transazione richiede conferma manuale")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)

                            HStack(spacing: 12) {
                                Button(action: confirmTransaction) {
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text("Conferma")
                                            .font(.headline)
                                    }
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.green)
                                    )
                                }
                                .buttonStyle(.plain)

                                Button(action: cancelTransaction) {
                                    HStack {
                                        Image(systemName: "xmark.circle.fill")
                                        Text("Annulla")
                                            .font(.headline)
                                    }
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.red)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 8)
                    } header: {
                        Text("Azioni")
                    } footer: {
                        Text("Conferma per eseguire immediatamente la transazione, o Annulla per cancellarla definitivamente.")
                    }
                }
            }
            .navigationTitle("Modifica Transazione")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        saveTransaction()
                    }
                    .disabled(amount.isEmpty || selectedAccount == nil)
                }

                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        initiateDelete()
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
            .sheet(isPresented: $showingCategoryPicker) {
                CategoryPickerView(selectedCategory: $selectedCategory, transactionType: transaction.transactionType)
            }
            .confirmationDialog(
                "Elimina Transazione Ricorrente",
                isPresented: $showingRecurringDeleteOptions,
                titleVisibility: .visible
            ) {
                ForEach(RecurringDeletionOption.allCases, id: \.self) { option in
                    Button(option.rawValue, role: .destructive) {
                        deleteRecurring(option: option)
                    }
                }

                Button("Annulla", role: .cancel) {}
            } message: {
                Text("Scegli quale parte della serie ricorrente eliminare:")
            }
            .alert("Elimina Transazione", isPresented: $showingDeleteDialog) {
                Button("Elimina", role: .destructive) {
                    deleteTransaction()
                }
                Button("Annulla", role: .cancel) {}
            } message: {
                Text("Sei sicuro di voler eliminare questa transazione?")
            }
        }
    }

    private func confirmTransaction() {
        // Execute transaction asynchronously
        Task { @MainActor in
            await TransactionScheduler.shared.executeTransaction(transaction, modelContext: modelContext)

            // Cancel notification after execution succeeds
            LocalNotificationManager.shared.cancelNotification(for: transaction)

            dismiss()
        }
    }

    private func cancelTransaction() {
        // Cancel notification when cancelling
        LocalNotificationManager.shared.cancelNotification(for: transaction)

        TransactionScheduler.shared.cancelTransaction(transaction, modelContext: modelContext)
        dismiss()
    }

    private func saveTransaction() {
        guard let amountDecimal = Decimal(string: amount.replacingOccurrences(of: ",", with: ".")) else { return }

        // Track if we're changing scheduling status
        let wasScheduled = transaction.isScheduled
        let wasPending = transaction.status == .pending

        // Update transaction
        transaction.amount = amountDecimal
        transaction.account = selectedAccount
        transaction.category = selectedCategory
        transaction.notes = notes

        // Only update date if transaction is not scheduled/pending
        if transaction.status != .pending {
            transaction.date = selectedDate
        }

        transaction.currencyRecord = selectedTransactionCurrencyRecord

        // Update scheduling fields
        transaction.isScheduled = isScheduled
        transaction.isAutomatic = isAutomatic

        if isScheduled {
            transaction.scheduledDate = scheduledDate
            // If enabling scheduling for an executed transaction, set to pending
            if !wasScheduled {
                transaction.status = .pending
            }
        } else {
            // If disabling scheduling, mark as executed
            if wasScheduled && wasPending {
                transaction.status = .executed
                // Use scheduled date if available, otherwise use now
                transaction.date = transaction.scheduledDate ?? Date()
            }
            transaction.scheduledDate = nil
        }

        // Update account balance only if status changed from pending to executed or vice versa
        if let account = selectedAccount {
            if (wasScheduled && wasPending && !isScheduled) || (!wasScheduled && isScheduled) {
                account.updateBalance(context: modelContext)
            }
        }

        if let destinationAccount = transaction.destinationAccount {
            if (wasScheduled && wasPending && !isScheduled) || (!wasScheduled && isScheduled) {
                destinationAccount.updateBalance(context: modelContext)
            }
        }

        try? modelContext.save()

        // Update local notification if transaction is scheduled
        Task {
            await LocalNotificationManager.shared.updateNotification(for: transaction)
        }

        dismiss()
    }

    private func initiateDelete() {
        // Check if this is a recurring transaction or instance
        if transaction.isRecurring || transaction.parentRecurringTransactionId != nil {
            showingRecurringDeleteOptions = true
        } else {
            showingDeleteDialog = true
        }
    }

    private func deleteTransaction() {
        // Cancel notification if exists
        LocalNotificationManager.shared.cancelNotification(for: transaction)

        // Delete transaction and update account balances
        if let account = transaction.account {
            // Delete transaction
            modelContext.delete(transaction)

            // Update balances AFTER deletion
            account.updateBalance(context: modelContext)

            if let destinationAccount = transaction.destinationAccount {
                destinationAccount.updateBalance(context: modelContext)
            }

            // Save everything together
            try? modelContext.save()
        }

        dismiss()
    }

    private func deleteRecurring(option: RecurringDeletionOption) {
        RecurringTransactionManager.shared.deleteRecurring(
            transaction: transaction,
            option: option,
            modelContext: modelContext
        )

        // Update balances after deletion
        if let account = transaction.account {
            account.updateBalance(context: modelContext)
        }

        if let destinationAccount = transaction.destinationAccount {
            destinationAccount.updateBalance(context: modelContext)
        }

        dismiss()
    }

    private func stopRecurrenceFromHere() {
        guard let templateId = transaction.parentRecurringTransactionId,
              let thisScheduledDate = transaction.scheduledDate else {
            return
        }

        // Trova il template
        let descriptor = FetchDescriptor<Transaction>()
        guard let allTransactions = try? modelContext.fetch(descriptor),
              let template = allTransactions.first(where: { $0.id == templateId }) else {
            return
        }

        // Imposta la data fine al giorno prima di questa istanza
        if let dayBefore = Calendar.current.date(byAdding: .day, value: -1, to: thisScheduledDate) {
            template.recurrenceEndDate = dayBefore
        }

        // Elimina tutte le istanze future (dopo questa, escludendo questa)
        let futureInstances = allTransactions.filter { t in
            guard t.parentRecurringTransactionId == templateId,
                  let tDate = t.scheduledDate else {
                return false
            }
            return tDate > thisScheduledDate
        }

        for instance in futureInstances {
            LocalNotificationManager.shared.cancelNotification(for: instance)
            modelContext.delete(instance)
        }

        try? modelContext.save()

        print("🛑 Ripetizione interrotta. Eliminate \(futureInstances.count) istanze future.")

        dismiss()
    }
}
