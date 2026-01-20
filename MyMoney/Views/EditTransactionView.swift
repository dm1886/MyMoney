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

    // Edit scope dialog for recurring transactions
    @State private var showingEditScopeDialog = false

    // Flag per prevenire accesso alla transazione durante/dopo eliminazione
    @State private var isDeletionInProgress = false

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
              let amountDecimal = parseAmount(amount),
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

    /// Parse amount string with thousands separators removed
    private func parseAmount(_ amountString: String) -> Decimal? {
        // Remove all non-numeric characters except decimal separators (. and ,)
        var cleaned = amountString.replacingOccurrences(of: " ", with: "")

        // Count decimal separators
        let commaCount = cleaned.filter { $0 == "," }.count
        let dotCount = cleaned.filter { $0 == "." }.count

        // Determine which is the decimal separator based on position
        // The last separator is the decimal separator
        if let lastComma = cleaned.lastIndex(of: ","),
           let lastDot = cleaned.lastIndex(of: ".") {
            if lastComma > lastDot {
                // Comma is decimal separator (e.g., European: 1.000,50)
                cleaned = cleaned.replacingOccurrences(of: ".", with: "")
                cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
            } else {
                // Dot is decimal separator (e.g., US: 1,000.50)
                cleaned = cleaned.replacingOccurrences(of: ",", with: "")
            }
        } else if commaCount > 0 {
            // Only commas present
            if commaCount == 1 && cleaned.split(separator: ",").last?.count ?? 0 <= 2 {
                // Single comma with 1-2 digits after = decimal separator (e.g., 10,50)
                cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
            } else {
                // Multiple commas or comma with >2 digits = thousands separator (e.g., 1,000,000)
                cleaned = cleaned.replacingOccurrences(of: ",", with: "")
            }
        }
        // If only dots, they stay as-is (assumed to be decimal separator for single dot, thousands for multiple)
        else if dotCount > 1 {
            // Multiple dots = thousands separators (e.g., 1.000.000)
            let parts = cleaned.split(separator: ".")
            if parts.count > 1 {
                cleaned = parts.dropLast().joined() + "." + parts.last!
            }
        }

        return Decimal(string: cleaned)
    }

    var body: some View {
        // Se l'eliminazione è in corso, mostra una vista vuota per evitare crash
        if isDeletionInProgress {
            Color.clear
        } else {
            mainContent
        }
    }

    @ViewBuilder
    private var mainContent: some View {
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
                                        if let imageData = category.imageData,
                                           let uiImage = UIImage(data: imageData) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 24, height: 24)
                                                .clipShape(Circle())
                                        } else {
                                            Image(systemName: category.icon)
                                                .foregroundStyle(category.color)
                                        }
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
                            title: transactionType == .transfer ? "Da Conto" : "Conto"
                        )
                    } label: {
                        HStack {
                            Text(transactionType == .transfer ? "Da Conto" : "Conto")
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

                // Destination Account Section (solo per trasferimenti)
                if transactionType == .transfer {
                    Section {
                        NavigationLink {
                            AccountSelectionView(
                                selectedAccount: $selectedDestinationAccount,
                                showNavigationBar: false,
                                transactionType: transactionType,
                                selectedCategory: nil,
                                title: "A Conto"
                            )
                        } label: {
                            HStack {
                                Text("A Conto")
                                    .foregroundStyle(.primary)

                                Spacer()

                                if let account = selectedDestinationAccount {
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

                        // Mostra conversione se le valute sono diverse
                        if let sourceCurrency = selectedAccount?.currencyRecord,
                           let destCurrency = selectedDestinationAccount?.currencyRecord,
                           sourceCurrency.code != destCurrency.code,
                           let amountDecimal = parseAmount(amount) {
                            let converted = CurrencyService.shared.convert(
                                amount: amountDecimal,
                                from: sourceCurrency,
                                to: destCurrency,
                                context: modelContext
                            )
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .foregroundStyle(.blue)
                                Text("Convertito")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(destCurrency.symbol)\(formatDecimal(converted))")
                                    .font(.headline)
                                    .foregroundStyle(.blue)
                            }
                        }
                    } footer: {
                        if let sourceCurrency = selectedAccount?.currencyRecord,
                           let destCurrency = selectedDestinationAccount?.currencyRecord,
                           sourceCurrency.code != destCurrency.code {
                            Text("L'importo verrà convertito da \(sourceCurrency.code) a \(destCurrency.code) usando il tasso di cambio corrente.")
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
                scheduledTransactionSection

                // MARK: - Recurring Transaction Info (Read-only)
                if isRecurring || parentRecurringTransactionId != nil {
                    recurringInfoSection

                    // MARK: - Gestione Ripetizione
                    if parentRecurringTransactionId != nil {
                        recurringManagementSection
                    }
                }

                // MARK: - Execution Buttons (for all pending transactions)
                if transactionStatus == .pending {
                    executionButtonsSection
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
                        // Se è una transazione ricorrente, chiedi se applicare a tutte o solo a questa
                        if parentRecurringTransactionId != nil {
                            showingEditScopeDialog = true
                        } else {
                            saveTransaction(applyToAll: false)
                        }
                    }
                    .disabled(
                        amount.isEmpty ||
                        selectedAccount == nil ||
                        (transactionType == .transfer && selectedDestinationAccount == nil)
                    )
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
            .confirmationDialog(
                "Modifica Transazione Ricorrente",
                isPresented: $showingEditScopeDialog,
                titleVisibility: .visible
            ) {
                Button("Solo questa") {
                    saveTransaction(applyToAll: false)
                }
                Button("Tutte le future") {
                    saveTransaction(applyToAll: true)
                }
                Button("Annulla", role: .cancel) { }
            } message: {
                Text("Vuoi applicare le modifiche solo a questa transazione o a tutte le transazioni future della serie?")
            }
        }
    }

    // MARK: - Extracted View Sections

    @ViewBuilder
    private var scheduledTransactionSection: some View {
        Section {
            Toggle(isOn: $isScheduled) {
                HStack {
                    Image(systemName: "clock.badge.checkmark")
                        .foregroundStyle(.orange)
                    Text("Programma Transazione")
                }
            }

            if isScheduled {
                Toggle(isOn: $isAutomatic) {
                    HStack {
                        Image(systemName: isAutomatic ? "bolt.fill" : "hand.tap.fill")
                            .foregroundStyle(isAutomatic ? .blue : .orange)
                        Text("Esecuzione Automatica")
                    }
                }

                if isAutomatic {
                    Text("La transazione sarà eseguita automaticamente alla data selezionata.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Riceverai una notifica per confermare manualmente la transazione.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

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
        } header: {
            Text("Programmazione")
        } footer: {
            if isScheduled {
                Text("La data sopra sarà usata come data di esecuzione programmata.")
            }
        }
    }

    @ViewBuilder
    private var recurringInfoSection: some View {
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
            } else {
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
    }

    @ViewBuilder
    private var recurringManagementSection: some View {
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

    @ViewBuilder
    private var executionButtonsSection: some View {
        Section {
            VStack(spacing: 12) {
                if isAutomatic {
                    Text("Transazione automatica programmata")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Questa transazione richiede conferma manuale")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 12) {
                    Button(action: confirmTransaction) {
                        HStack {
                            Image(systemName: "bolt.circle.fill")
                            Text("Esegui Ora")
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
                            Text("Elimina")
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
            if isAutomatic {
                Text("Premi 'Esegui Ora' per eseguire subito la transazione senza attendere la data programmata, o 'Elimina' per cancellarla.")
            } else {
                Text("Conferma per eseguire immediatamente la transazione, o Elimina per cancellarla definitivamente.")
            }
        }
    }

    // MARK: - Actions

    private func confirmTransaction() {
        let transactionId = transaction.id

        Task { @MainActor in
            await TransactionScheduler.shared.executeTransaction(transaction, modelContext: modelContext)
            LocalNotificationManager.shared.cancelNotification(transactionId: transactionId)
            try? await Task.sleep(nanoseconds: 100_000_000)
            dismiss()
        }
    }

    private func cancelTransaction() {
        let transactionId = transaction.id
        LocalNotificationManager.shared.cancelNotification(transactionId: transactionId)
        TransactionScheduler.shared.cancelTransaction(transaction, modelContext: modelContext)

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000)
            dismiss()
        }
    }

    private func saveTransaction(applyToAll: Bool) {
        guard let amountDecimal = parseAmount(amount) else {
            return
        }

        LogManager.shared.info("Saving transaction: \(transactionType.rawValue), Amount: \(amountDecimal)", category: "Transaction")

        // Track if we're changing scheduling status
        let wasScheduled = transaction.isScheduled
        let wasPending = transaction.status == .pending

        // Store old accounts BEFORE updating (for balance recalculation if accounts changed)
        let oldAccount = transaction.account
        let oldDestinationAccount = transaction.destinationAccount

        // Update current transaction
        transaction.amount = amountDecimal
        transaction.account = selectedAccount
        transaction.destinationAccount = selectedDestinationAccount
        transaction.category = selectedCategory
        transaction.notes = notes

        // Only update date if transaction is not scheduled/pending
        if transaction.status != .pending {
            transaction.date = selectedDate
        }

        transaction.currencyRecord = selectedTransactionCurrencyRecord

        // Set converted amount if currency conversion is needed
        if transactionType == .transfer {
            print("💾 [SAVE DEBUG] TRANSFER - amount: \(amountDecimal)")
            print("💾 [SAVE DEBUG] TRANSFER - source account: \(selectedAccount?.name ?? "nil") (\(selectedAccount?.currencyRecord?.code ?? "nil"))")
            print("💾 [SAVE DEBUG] TRANSFER - dest account: \(selectedDestinationAccount?.name ?? "nil") (\(selectedDestinationAccount?.currencyRecord?.code ?? "nil"))")
            // For transfers, check if source and destination currencies differ
            if let sourceCurrency = selectedAccount?.currencyRecord,
               let destCurrency = selectedDestinationAccount?.currencyRecord,
               sourceCurrency.code != destCurrency.code {
                // Convert amount from source to destination currency
                let converted = CurrencyService.shared.convert(
                    amount: amountDecimal,
                    from: sourceCurrency,
                    to: destCurrency,
                    context: modelContext
                )
                transaction.destinationAmount = converted
                print("💾 [SAVE DEBUG] TRANSFER - Cross-currency: destinationAmount set to \(converted)")
            } else {
                // Same currency, no conversion needed
                transaction.destinationAmount = nil
                print("💾 [SAVE DEBUG] TRANSFER - Same currency: destinationAmount set to nil")
            }
        } else if needsConversion {
            // For expense/income, convert from transaction currency to account currency
            transaction.destinationAmount = convertedAmount
            print("💾 [SAVE DEBUG] NON-TRANSFER - destinationAmount set to \(convertedAmount ?? 0)")
        } else {
            // Clear destinationAmount if no conversion needed
            transaction.destinationAmount = nil
            print("💾 [SAVE DEBUG] NON-TRANSFER - destinationAmount set to nil")
        }

        // Update scheduling fields
        transaction.isScheduled = isScheduled
        transaction.isAutomatic = isAutomatic

        if isScheduled {
            // If enabling scheduling for an executed transaction, set to pending
            if !wasScheduled {
                transaction.status = .pending
            }
        } else {
            // If disabling scheduling, mark as executed
            if wasScheduled && wasPending {
                transaction.status = .executed

                // Record category usage when converting from scheduled to executed
                if let category = selectedCategory {
                    category.recordUsage()
                }
            }
        }

        // Se applyToAll è true, applica le modifiche anche a tutte le transazioni future della serie
        if applyToAll, let templateId = parentRecurringTransactionId {
            applyChangesToFutureTransactions(
                templateId: templateId,
                amount: amountDecimal,
                convertedAmount: convertedAmount
            )
        }

        // IMPORTANTE: Salvare PRIMA di updateBalance() per assicurare che le relazioni inverse siano stabilite
        try? modelContext.save()

        // Update account balances:
        // - Always update for executed transactions (any edit could change the balance)
        // - Update when status changes between pending and executed
        let needsBalanceUpdate = transaction.status == .executed ||
                                  (wasScheduled && wasPending && !isScheduled) ||
                                  (!wasScheduled && isScheduled)

        print("📝 [DEBUG] EditTransaction - needsBalanceUpdate: \(needsBalanceUpdate)")
        print("📝 [DEBUG] EditTransaction - transaction.status: \(transaction.status.rawValue)")
        print("📝 [DEBUG] EditTransaction - transactionType: \(transactionType.rawValue)")
        print("📝 [DEBUG] EditTransaction - selectedAccount: \(selectedAccount?.name ?? "nil")")
        print("📝 [DEBUG] EditTransaction - selectedDestinationAccount: \(selectedDestinationAccount?.name ?? "nil")")
        print("📝 [DEBUG] EditTransaction - oldAccount: \(oldAccount?.name ?? "nil")")
        print("📝 [DEBUG] EditTransaction - oldDestinationAccount: \(oldDestinationAccount?.name ?? "nil")")

        if needsBalanceUpdate {
            // Update source account
            if let account = selectedAccount {
                print("📝 [DEBUG] Calling updateBalance for SOURCE account: \(account.name)")
                account.updateBalance(context: modelContext)
            }

            // Update destination account (for transfers)
            if let destinationAccount = selectedDestinationAccount {
                print("📝 [DEBUG] Calling updateBalance for DESTINATION account: \(destinationAccount.name)")
                destinationAccount.updateBalance(context: modelContext)
            }

            // Also update old accounts if they changed
            if let previousAccount = oldAccount, previousAccount.id != selectedAccount?.id {
                print("📝 [DEBUG] Calling updateBalance for OLD SOURCE account: \(previousAccount.name)")
                previousAccount.updateBalance(context: modelContext)
            }
            if let previousDestAccount = oldDestinationAccount, previousDestAccount.id != selectedDestinationAccount?.id {
                print("📝 [DEBUG] Calling updateBalance for OLD DESTINATION account: \(previousDestAccount.name)")
                previousDestAccount.updateBalance(context: modelContext)
            }

            // Salva di nuovo dopo l'aggiornamento dei bilanci
            try? modelContext.save()
        } else {
            print("📝 [DEBUG] Skipping balance update - needsBalanceUpdate is false")
        }

        // Update local notification if transaction is scheduled
        Task {
            await LocalNotificationManager.shared.updateNotification(for: transaction)
        }

        LogManager.shared.success("Transaction saved successfully", category: "Transaction")

        // Notify TodayView to refresh its transaction list
        NotificationCenter.default.post(name: .transactionsDidChange, object: nil)

        dismiss()
    }

    private func initiateDelete() {
        // Check if this is a recurring transaction or instance
        if isRecurring || parentRecurringTransactionId != nil {
            showingDeleteInstancesWarning = true
        } else {
            showingDeleteDialog = true
        }
    }

    private func deleteTransaction() {
        let transactionId = transaction.id
        let accountToUpdate = selectedAccount
        let destinationAccountToUpdate = selectedDestinationAccount
        let wasScheduled = self.isScheduled

        // Mark as deleted in global tracker IMMEDIATELY
        DeletedTransactionTracker.shared.markAsDeleted(transactionId)

        isDeletionInProgress = true
        dismiss()

        // Elimina DOPO aver chiuso la vista
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [modelContext] in
            let descriptor = FetchDescriptor<Transaction>()
            guard let allTransactions = try? modelContext.fetch(descriptor),
                  let transactionToDelete = allTransactions.first(where: { $0.id == transactionId }) else {
                return
            }

            if wasScheduled {
                LocalNotificationManager.shared.cancelNotification(transactionId: transactionId)
            }

            withAnimation {
                modelContext.delete(transactionToDelete)
            }

            try? modelContext.save()

            if let account = accountToUpdate {
                account.updateBalance(context: modelContext)
            }

            if let destinationAccount = destinationAccountToUpdate {
                destinationAccount.updateBalance(context: modelContext)
            }

            try? modelContext.save()
        }
    }

    private func deleteRecurring(option: RecurringDeletionOption) {
        let transactionId = transaction.id
        let accountToUpdate = selectedAccount
        let destinationAccountToUpdate = selectedDestinationAccount
        let templateId = parentRecurringTransactionId ?? transactionId
        let thisDate = selectedDate

        let tracker = DeletedTransactionTracker.shared

        switch option {
        case .thisOnly:
            tracker.markAsDeleted(transactionId)
        case .thisAndFuture:
            tracker.markAsDeleted(transactionId)
            let descriptor = FetchDescriptor<Transaction>()
            if let allTransactions = try? modelContext.fetch(descriptor) {
                let futureIds = allTransactions.filter { t in
                    guard t.parentRecurringTransactionId == templateId else { return false }
                    return t.date >= thisDate
                }.map { $0.id }
                tracker.markAsDeleted(futureIds)
            }
        case .all:
            tracker.markAsDeleted(templateId)
            let descriptor = FetchDescriptor<Transaction>()
            if let allTransactions = try? modelContext.fetch(descriptor) {
                let allRelatedIds = allTransactions.filter {
                    $0.id == templateId || $0.parentRecurringTransactionId == templateId
                }.map { $0.id }
                tracker.markAsDeleted(allRelatedIds)
            }
        }

        isDeletionInProgress = true
        dismiss()

        // Elimina DOPO aver chiuso la vista
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [modelContext] in
            let descriptor = FetchDescriptor<Transaction>()
            guard let allTransactions = try? modelContext.fetch(descriptor) else {
                return
            }

            switch option {
            case .thisOnly:
                if let transactionToDelete = allTransactions.first(where: { $0.id == transactionId }) {
                    LocalNotificationManager.shared.cancelNotification(transactionId: transactionId)
                    withAnimation {
                        modelContext.delete(transactionToDelete)
                    }
                }

            case .thisAndFuture:
                let transactionsToDelete = allTransactions.filter { t in
                    guard t.parentRecurringTransactionId == templateId else {
                        return false
                    }
                    return t.date >= thisDate
                }

                withAnimation {
                    for t in transactionsToDelete {
                        let tId = t.id
                        LocalNotificationManager.shared.cancelNotification(transactionId: tId)
                        modelContext.delete(t)
                    }

                    if transactionId == templateId {
                        if let template = allTransactions.first(where: { $0.id == templateId }) {
                            modelContext.delete(template)
                        }
                    }
                }

            case .all:
                let allRelated = allTransactions.filter {
                    $0.id == templateId || $0.parentRecurringTransactionId == templateId
                }

                withAnimation {
                    for t in allRelated {
                        let tId = t.id
                        LocalNotificationManager.shared.cancelNotification(transactionId: tId)
                        modelContext.delete(t)
                    }
                }
            }

            try? modelContext.save()

            if let account = accountToUpdate {
                account.updateBalance(context: modelContext)
            }

            if let destinationAccount = destinationAccountToUpdate {
                destinationAccount.updateBalance(context: modelContext)
            }

            try? modelContext.save()
        }
    }

    private func stopRecurrenceFromHere() {
        guard let templateId = transaction.parentRecurringTransactionId else {
            return
        }
        let thisDate = transaction.date

        dismiss()

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 50_000_000)

            let descriptor = FetchDescriptor<Transaction>()
            guard let allTransactions = try? modelContext.fetch(descriptor),
                  let template = allTransactions.first(where: { $0.id == templateId }) else {
                return
            }

            if let dayBefore = Calendar.current.date(byAdding: .day, value: -1, to: thisDate) {
                template.recurrenceEndDate = dayBefore
            }

            // Elimina tutte le transazioni future (dopo questa, escludendo questa)
            let futureTransactions = allTransactions.filter { t in
                guard t.parentRecurringTransactionId == templateId else {
                    return false
                }
                return t.date > thisDate
            }

            for transaction in futureTransactions {
                // Salva l'ID prima di eliminare
                let transactionId = transaction.id
                LocalNotificationManager.shared.cancelNotification(transactionId: transactionId)
                modelContext.delete(transaction)
            }

            try? modelContext.save()
            LogManager.shared.info("Recurrence stopped. Deleted \(futureTransactions.count) future transactions.", category: "Transaction")
        }
    }

    private func applyChangesToFutureTransactions(templateId: UUID, amount: Decimal, convertedAmount: Decimal?) {
        let thisDate = transaction.date

        let descriptor = FetchDescriptor<Transaction>()
        guard let allTransactions = try? modelContext.fetch(descriptor) else { return }

        // Trova tutte le transazioni future della stessa serie
        let futureTransactions = allTransactions.filter { t in
            guard t.parentRecurringTransactionId == templateId,
                  t.id != transaction.id else {
                return false
            }
            return t.date > thisDate && t.status == .pending
        }

        // Applica le stesse modifiche a tutte le transazioni future
        for futureTransaction in futureTransactions {
            updateTransactionFields(futureTransaction, amount: amount, convertedAmount: convertedAmount)
        }

        // Aggiorna anche il template
        if let template = allTransactions.first(where: { $0.id == templateId }) {
            updateTransactionFields(template, amount: amount, convertedAmount: convertedAmount)
        }
    }

    private func updateTransactionFields(_ targetTransaction: Transaction, amount: Decimal, convertedAmount: Decimal?) {
        targetTransaction.amount = amount
        targetTransaction.account = selectedAccount
        targetTransaction.destinationAccount = selectedDestinationAccount
        targetTransaction.category = selectedCategory
        targetTransaction.notes = notes
        targetTransaction.currencyRecord = selectedTransactionCurrencyRecord
        targetTransaction.isAutomatic = isAutomatic

        // Update converted amount
        if transactionType == .transfer {
            updateTransferConversion(targetTransaction, amount: amount)
        } else if needsConversion {
            targetTransaction.destinationAmount = convertedAmount
        } else {
            targetTransaction.destinationAmount = nil
        }
    }

    private func updateTransferConversion(_ targetTransaction: Transaction, amount: Decimal) {
        guard let sourceCurrency = selectedAccount?.currencyRecord,
              let destCurrency = selectedDestinationAccount?.currencyRecord else {
            targetTransaction.destinationAmount = nil
            return
        }

        if sourceCurrency.code != destCurrency.code {
            let converted = CurrencyService.shared.convert(
                amount: amount,
                from: sourceCurrency,
                to: destCurrency,
                context: modelContext
            )
            targetTransaction.destinationAmount = converted
        } else {
            targetTransaction.destinationAmount = nil
        }
    }
}
