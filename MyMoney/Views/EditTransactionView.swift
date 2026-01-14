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

    @State private var transactionType: TransactionType
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

    // Recurring fields (salvate per evitare crash dopo eliminazione)
    @State private var isRecurring: Bool
    @State private var parentRecurringTransactionId: UUID?
    @State private var recurrenceRule: RecurrenceRule?
    @State private var recurrenceEndDate: Date?
    @State private var transactionStatus: TransactionStatus

    // Deletion dialog
    @State private var showingDeleteDialog = false
    @State private var showingRecurringDeleteOptions = false
    @State private var showingStopRecurrenceAlert = false
    @State private var showingDeleteInstancesWarning = false
    @State private var selectedDeletionOption: RecurringDeletionOption?

    // Help disclosure states
    @State private var showingStopRecurrenceHelp = false
    @State private var showingDeleteTransactionsHelp = false

    init(transaction: Transaction) {
        self.transaction = transaction

        // IMPORTANTE: Salva TUTTE le proprietà usate nel body per evitare crash dopo eliminazione
        _transactionType = State(initialValue: transaction.transactionType)
        _transactionStatus = State(initialValue: transaction.status)

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

        // Initialize recurring fields
        _isRecurring = State(initialValue: transaction.isRecurring)
        _parentRecurringTransactionId = State(initialValue: transaction.parentRecurringTransactionId)
        _recurrenceRule = State(initialValue: transaction.recurrenceRule)
        _recurrenceEndDate = State(initialValue: transaction.recurrenceEndDate)
    }

    var transactionCurrencyRecord: CurrencyRecord? {
        selectedTransactionCurrencyRecord ?? selectedAccount?.currencyRecord
    }

    var accountCurrencyRecord: CurrencyRecord? {
        selectedAccount?.currencyRecord
    }

    var needsConversion: Bool {
        guard let transCurr = transactionCurrencyRecord,
              let accCurr = accountCurrencyRecord else {
            return false
        }
        return transCurr.code != accCurr.code
    }

    var convertedAmount: Decimal? {
        guard needsConversion,
              let amountDecimal = Decimal(string: amount.replacingOccurrences(of: ",", with: ".")),
              let transCurr = transactionCurrencyRecord,
              let accCurr = accountCurrencyRecord else {
            return nil
        }

        return CurrencyService.shared.convert(
            amount: amountDecimal,
            from: transCurr,
            to: accCurr,
            context: modelContext
        )
    }

    private func formatDecimal(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "0.00"
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
                if transactionType != .transfer {
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
                        AccountSelectionView(
                            selectedAccount: $selectedAccount,
                            showNavigationBar: false,
                            transactionType: transactionType,
                            selectedCategory: selectedCategory,
                            title: "Conto"
                        )
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
                        }
                    }
                }

                // Currency Section (solo per expense/income)
                if transactionType != .transfer {
                    Section {
                        NavigationLink {
                            CurrencySelectionView(selectedCurrency: $selectedTransactionCurrencyRecord)
                        } label: {
                            HStack {
                                Text("Valuta")
                                    .foregroundStyle(.primary)

                                Spacer()

                                if let currency = selectedTransactionCurrencyRecord {
                                    HStack(spacing: 8) {
                                        Text(currency.flagEmoji)
                                        Text(currency.code)
                                            .foregroundStyle(.secondary)
                                    }
                                } else if let accountCurr = accountCurrencyRecord {
                                    HStack(spacing: 8) {
                                        Text(accountCurr.flagEmoji)
                                        Text("Valuta del conto (\(accountCurr.code))")
                                            .foregroundStyle(.secondary)
                                    }
                                } else {
                                    Text("Seleziona")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        // Mostra conversione se necessaria
                        if needsConversion, let converted = convertedAmount {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .foregroundStyle(.blue)
                                Text("Convertito")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                if let accCurr = accountCurrencyRecord {
                                    Text("\(accCurr.symbol)\(formatDecimal(converted))")
                                        .font(.headline)
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    } footer: {
                        if needsConversion,
                           let transCurr = transactionCurrencyRecord,
                           let accCurr = accountCurrencyRecord {
                            Text("L'importo verrà convertito da \(transCurr.code) a \(accCurr.code) usando il tasso di cambio corrente.")
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
                        if newValue && transactionStatus != .pending {
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
                        if isScheduled {
                            HStack {
                                Text("Stato:")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                HStack(spacing: 4) {
                                    Image(systemName: transactionStatus.icon)
                                    Text(transactionStatus.rawValue)
                                }
                                .foregroundStyle(Color(hex: transactionStatus.color) ?? .primary)
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
                if isRecurring || parentRecurringTransactionId != nil {
                    Section {
                        HStack {
                            Image(systemName: "repeat.circle.fill")
                                .foregroundStyle(.purple)
                            Text(isRecurring ? "Template Ricorrente" : "Transazione Ricorrente")
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.purple)
                        }

                        if let rule = recurrenceRule {
                            HStack {
                                Image(systemName: rule.icon)
                                    .foregroundStyle(.purple)
                                Text("Frequenza")
                                Spacer()
                                Text(rule.displayString)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if let endDate = recurrenceEndDate {
                            HStack {
                                Image(systemName: "calendar.badge.clock")
                                    .foregroundStyle(.orange)
                                Text("Fino a")
                                Spacer()
                                Text(endDate.formatted(date: .abbreviated, time: .omitted))
                                    .foregroundStyle(.secondary)
                            }
                        } else if isRecurring || parentRecurringTransactionId != nil {
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
                        if isRecurring {
                            Text("Questo è il template principale della serie ricorrente.")
                        } else {
                            Text("Questa è una transazione di una serie ricorrente. La modifica influenzerà solo questa transazione.")
                        }
                    }

                    // MARK: - Gestione Ripetizione
                    if parentRecurringTransactionId != nil {
                        Section {
                            VStack(alignment: .leading, spacing: 8) {
                                Button {
                                    showingStopRecurrenceAlert = true
                                } label: {
                                    HStack {
                                        Image(systemName: "stop.circle")
                                            .foregroundStyle(.orange)
                                        Text("Interrompi Ripetizione da Qui")
                                        Spacer()
                                    }
                                }

                                DisclosureGroup(
                                    isExpanded: $showingStopRecurrenceHelp,
                                    content: {
                                        Text("Ferma la ripetizione mantenendo questa transazione. Tutte le transazioni future verranno eliminate, ma questa rimarrà intatta.")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .padding(.top, 4)
                                    },
                                    label: {
                                        Text("Cosa succede?")
                                            .font(.caption)
                                            .foregroundStyle(.blue)
                                    }
                                )
                            }

                            Divider()
                                .padding(.vertical, 4)

                            VStack(alignment: .leading, spacing: 8) {
                                Button {
                                    showingDeleteInstancesWarning = true
                                } label: {
                                    HStack {
                                        Image(systemName: "trash.circle")
                                            .foregroundStyle(.red)
                                        Text("Elimina Transazioni...")
                                        Spacer()
                                    }
                                }

                                DisclosureGroup(
                                    isExpanded: $showingDeleteTransactionsHelp,
                                    content: {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text("• Solo Questa: elimina solo questa transazione")
                                            Text("• Questa e Future: elimina questa + tutte le future")
                                            Text("• Tutte: elimina l'intera serie ricorrente")
                                        }
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.top, 4)
                                    },
                                    label: {
                                        Text("Cosa succede?")
                                            .font(.caption)
                                            .foregroundStyle(.blue)
                                    }
                                )
                            }
                        } header: {
                            Text("Gestione Ripetizione")
                        } footer: {
                            Text("Puoi interrompere la ripetizione o eliminare transazioni specifiche della serie.")
                        }
                    }
                }

                // MARK: - Manual Confirmation Buttons
                if transactionStatus == .pending && !isAutomatic {
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
                CategoryPickerView(selectedCategory: $selectedCategory, transactionType: transactionType)
            }
            .alert("Interrompi Ripetizione", isPresented: $showingStopRecurrenceAlert) {
                Button("Conferma", role: .destructive) {
                    stopRecurrenceFromHere()
                }
            } message: {
                Text("Questa transazione non si ripeterà più dopo questa data. Tutte le transazioni future verranno eliminate.")
            }
            .alert("Elimina Transazioni Ricorrenti", isPresented: $showingDeleteInstancesWarning) {
                Button("Continua", role: .destructive) {
                    showingRecurringDeleteOptions = true
                }
            } message: {
                Text("Stai per eliminare delle transazioni della serie ricorrente. Questa azione non può essere annullata. Vuoi continuare?")
            }
            .confirmationDialog(
                "Elimina Transazione Ricorrente",
                isPresented: $showingRecurringDeleteOptions,
                titleVisibility: .visible
            ) {
                ForEach(RecurringDeletionOption.allCases, id: \.self) { option in
                    Button(option.rawValue, role: .destructive) {
                        selectedDeletionOption = option
                        deleteRecurring(option: option)
                    }
                }
            } message: {
                Text("Scegli quale parte della serie ricorrente eliminare:")
            }
            .alert("Elimina Transazione", isPresented: $showingDeleteDialog) {
                Button("Elimina", role: .destructive) {
                    deleteTransaction()
                }
            } message: {
                Text("Sei sicuro di voler eliminare questa transazione?")
            }
        }
    }

    private func confirmTransaction() {
        // IMPORTANTE: Salva l'ID PRIMA dell'esecuzione
        let transactionId = transaction.id

        // Execute transaction asynchronously
        Task { @MainActor in
            await TransactionScheduler.shared.executeTransaction(transaction, modelContext: modelContext)

            // Cancel notification after execution succeeds (usa solo l'ID)
            LocalNotificationManager.shared.cancelNotification(transactionId: transactionId)

            // Dismiss con delay per evitare crash
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 secondi
            dismiss()
        }
    }

    private func cancelTransaction() {
        // IMPORTANTE: Salva l'ID PRIMA di cancellare
        let transactionId = transaction.id

        // Cancel notification when cancelling (usa solo l'ID)
        LocalNotificationManager.shared.cancelNotification(transactionId: transactionId)

        TransactionScheduler.shared.cancelTransaction(transaction, modelContext: modelContext)

        // Dismiss con delay per evitare crash
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 secondi
            dismiss()
        }
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

        // Set converted amount if currency conversion is needed
        if transactionType != .transfer && needsConversion {
            transaction.destinationAmount = convertedAmount
        } else {
            // Clear destinationAmount if no conversion needed
            transaction.destinationAmount = nil
        }

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

                // Record category usage when converting from scheduled to executed
                if let category = selectedCategory {
                    category.recordUsage()
                }
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
        print("🚀 [DEBUG] initiateDelete() - START")

        // Check if this transaction still exists in the context
        // (potrebbe essere stata già eliminata da "Interrompi Ripetizione da Qui")
        let descriptor = FetchDescriptor<Transaction>()
        guard let allTransactions = try? modelContext.fetch(descriptor),
              allTransactions.contains(where: { $0.id == transaction.id }) else {
            // La transazione è già stata eliminata, chiudi la vista
            print("⚠️ [DEBUG] Transaction already deleted in initiateDelete, dismissing")
            dismiss()
            return
        }

        print("🔍 [DEBUG] Checking if transaction is recurring...")
        let isRecurring = transaction.isRecurring
        print("   isRecurring: \(isRecurring)")

        let parentId = transaction.parentRecurringTransactionId
        print("   parentRecurringTransactionId: \(parentId?.uuidString ?? "nil")")

        // Check if this is a recurring transaction or instance
        if isRecurring || parentId != nil {
            print("📋 [DEBUG] Showing delete instances warning")
            showingDeleteInstancesWarning = true
        } else {
            print("📋 [DEBUG] Showing simple delete dialog")
            showingDeleteDialog = true
        }

        print("✅ [DEBUG] initiateDelete() - COMPLETED")
    }

    private func deleteTransaction() {
        print("🗑️ [DEBUG] deleteTransaction() - START")

        // Verifica se la transazione esiste ancora
        let descriptor = FetchDescriptor<Transaction>()
        guard let allTransactions = try? modelContext.fetch(descriptor),
              allTransactions.contains(where: { $0.id == transaction.id }) else {
            // La transazione è già stata eliminata
            print("⚠️ [DEBUG] Transaction already deleted, dismissing")
            dismiss()
            return
        }

        print("🔍 [DEBUG] Reading transaction properties...")

        // IMPORTANTE: Salva TUTTE le informazioni necessarie PRIMA
        let transactionId = transaction.id
        print("   ✅ Got transactionId: \(transactionId)")

        let isScheduled = transaction.isScheduled
        print("   ✅ Got isScheduled: \(isScheduled)")

        let accountToUpdate = transaction.account
        print("   ✅ Got account: \(accountToUpdate?.name ?? "nil")")

        let destinationAccountToUpdate = transaction.destinationAccount
        print("   ✅ Got destinationAccount: \(destinationAccountToUpdate?.name ?? "nil")")

        // STRATEGIA: Chiudi la vista PRIMA di eliminare
        print("👋 [DEBUG] Dismissing BEFORE deletion")
        dismiss()

        // Elimina DOPO aver chiuso la vista
        Task { @MainActor in
            // Piccolo delay per assicurarsi che la vista sia chiusa
            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 secondi

            print("⏳ [DEBUG] Vista chiusa, ora elimino...")

            // Cancel notification if exists (usa solo l'ID)
            if isScheduled {
                print("🔔 [DEBUG] Cancelling notification for: \(transactionId)")
                LocalNotificationManager.shared.cancelNotification(transactionId: transactionId)
                print("   ✅ Notification cancelled")
            }

            // Delete transaction
            print("🗑️ [DEBUG] Deleting transaction from context...")
            modelContext.delete(transaction)
            print("   ✅ Transaction deleted from context")

            // Update balances AFTER deletion usando i riferimenti salvati
            if let account = accountToUpdate {
                print("💰 [DEBUG] Updating balance for account: \(account.name)")
                account.updateBalance(context: modelContext)
                print("   ✅ Balance updated")
            }

            if let destinationAccount = destinationAccountToUpdate {
                print("💰 [DEBUG] Updating balance for destination account: \(destinationAccount.name)")
                destinationAccount.updateBalance(context: modelContext)
                print("   ✅ Destination balance updated")
            }

            // Save everything together
            print("💾 [DEBUG] Saving context...")
            try? modelContext.save()
            print("   ✅ Context saved")

            print("✅ [DEBUG] deleteTransaction() - COMPLETED")
        }
    }

    private func deleteRecurring(option: RecurringDeletionOption) {
        print("🔄 [DEBUG] deleteRecurring() - START with option: \(option.rawValue)")

        // Verifica se la transazione esiste ancora
        let descriptor = FetchDescriptor<Transaction>()
        guard let allTransactions = try? modelContext.fetch(descriptor),
              allTransactions.contains(where: { $0.id == transaction.id }) else {
            // La transazione è già stata eliminata
            print("⚠️ [DEBUG] Transaction already deleted in deleteRecurring, dismissing")
            dismiss()
            return
        }

        print("🔍 [DEBUG] Reading transaction data and account references...")
        // IMPORTANTE: Salva TUTTI i dati necessari PRIMA
        let transactionId = transaction.id
        print("   ✅ Got transactionId: \(transactionId)")

        let accountToUpdate = transaction.account
        print("   ✅ Got account: \(accountToUpdate?.name ?? "nil")")

        let destinationAccountToUpdate = transaction.destinationAccount
        print("   ✅ Got destinationAccount: \(destinationAccountToUpdate?.name ?? "nil")")

        let templateId = transaction.parentRecurringTransactionId ?? transaction.id
        print("   ✅ Got templateId: \(templateId)")

        let thisScheduledDate = transaction.scheduledDate
        print("   ✅ Got scheduledDate: \(thisScheduledDate?.description ?? "nil")")

        // STRATEGIA: Chiudi la vista PRIMA di eliminare
        print("👋 [DEBUG] Dismissing BEFORE deletion")
        dismiss()

        // Elimina DOPO aver chiuso la vista
        Task { @MainActor in
            // Piccolo delay per assicurarsi che la vista sia chiusa
            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 secondi

            print("⏳ [DEBUG] Vista chiusa, ora elimino...")

            // Fetch transactions again in the async context
            let descriptor = FetchDescriptor<Transaction>()
            guard let allTransactions = try? modelContext.fetch(descriptor) else {
                print("⚠️ [DEBUG] Could not fetch transactions")
                return
            }

            print("🗑️ [DEBUG] Executing deletion for option: \(option.rawValue)")

            switch option {
            case .thisOnly:
                // Elimina solo questa transazione
                print("   Deleting single transaction: \(transactionId)")
                if let transactionToDelete = allTransactions.first(where: { $0.id == transactionId }) {
                    LocalNotificationManager.shared.cancelNotification(transactionId: transactionId)
                    modelContext.delete(transactionToDelete)
                    print("   ✅ Deleted single transaction")
                }

            case .thisAndFuture:
                // Elimina questa transazione e tutte le future
                guard let thisDate = thisScheduledDate else {
                    print("   ⚠️ No scheduled date for thisAndFuture deletion")
                    return
                }

                let transactionsToDelete = allTransactions.filter { t in
                    guard t.parentRecurringTransactionId == templateId,
                          let tDate = t.scheduledDate else {
                        return false
                    }
                    return tDate >= thisDate
                }

                print("   Deleting \(transactionsToDelete.count) transactions (this and future)")
                for t in transactionsToDelete {
                    let tId = t.id
                    LocalNotificationManager.shared.cancelNotification(transactionId: tId)
                    modelContext.delete(t)
                }

                // Se la transazione corrente è il template, eliminala
                if transactionId == templateId {
                    if let template = allTransactions.first(where: { $0.id == templateId }) {
                        modelContext.delete(template)
                        print("   ✅ Deleted template as well")
                    }
                }

                print("   ✅ Deleted \(transactionsToDelete.count) future transactions")

            case .all:
                // Elimina tutte le transazioni + template
                let allRelated = allTransactions.filter {
                    $0.id == templateId || $0.parentRecurringTransactionId == templateId
                }

                print("   Deleting all \(allRelated.count) transactions including template")
                for t in allRelated {
                    let tId = t.id
                    LocalNotificationManager.shared.cancelNotification(transactionId: tId)
                    modelContext.delete(t)
                }

                print("   ✅ Deleted all \(allRelated.count) instances")
            }

            // Save context
            try? modelContext.save()
            print("   ✅ Context saved")

            // Update balances AFTER deletion usando i riferimenti salvati
            if let account = accountToUpdate {
                print("💰 [DEBUG] Updating balance for account: \(account.name)")
                account.updateBalance(context: modelContext)
                print("   ✅ Balance updated")
            }

            if let destinationAccount = destinationAccountToUpdate {
                print("💰 [DEBUG] Updating balance for destination account: \(destinationAccount.name)")
                destinationAccount.updateBalance(context: modelContext)
                print("   ✅ Destination balance updated")
            }

            print("✅ [DEBUG] deleteRecurring() - COMPLETED")
        }
    }

    private func stopRecurrenceFromHere() {
        // IMPORTANTE: Salva TUTTI i dati necessari PRIMA
        guard let templateId = transaction.parentRecurringTransactionId,
              let thisScheduledDate = transaction.scheduledDate else {
            return
        }

        print("🛑 [DEBUG] stopRecurrenceFromHere - templateId: \(templateId), date: \(thisScheduledDate)")

        // STRATEGIA: Chiudi la vista PRIMA di modificare/eliminare
        print("👋 [DEBUG] Dismissing BEFORE stopping recurrence")
        dismiss()

        // Modifica/Elimina DOPO aver chiuso la vista
        Task { @MainActor in
            // Piccolo delay per assicurarsi che la vista sia chiusa
            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 secondi

            print("⏳ [DEBUG] Vista chiusa, ora interrompo la ripetizione...")

            // Trova il template
            let descriptor = FetchDescriptor<Transaction>()
            guard let allTransactions = try? modelContext.fetch(descriptor),
                  let template = allTransactions.first(where: { $0.id == templateId }) else {
                print("⚠️ [DEBUG] Template not found")
                return
            }

            // Imposta la data fine al giorno prima di questa transazione
            if let dayBefore = Calendar.current.date(byAdding: .day, value: -1, to: thisScheduledDate) {
                template.recurrenceEndDate = dayBefore
                print("📅 [DEBUG] Set recurrence end date to: \(dayBefore)")
            }

            // Elimina tutte le transazioni future (dopo questa, escludendo questa)
            let futureTransactions = allTransactions.filter { t in
                guard t.parentRecurringTransactionId == templateId,
                      let tDate = t.scheduledDate else {
                    return false
                }
                return tDate > thisScheduledDate
            }

            for transaction in futureTransactions {
                // Salva l'ID prima di eliminare
                let transactionId = transaction.id
                LocalNotificationManager.shared.cancelNotification(transactionId: transactionId)
                modelContext.delete(transaction)
            }

            try? modelContext.save()

            print("🛑 Ripetizione interrotta. Eliminate \(futureTransactions.count) transazioni future.")
            print("✅ [DEBUG] stopRecurrenceFromHere - COMPLETED")
        }
    }
}
