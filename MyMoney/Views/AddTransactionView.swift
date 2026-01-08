//
//  AddTransactionView.swift
//  MoneyTracker
//
//  Created on 2026-01-01.
//

import SwiftUI
import SwiftData

struct AddTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var accounts: [Account]
    @Query private var categories: [Category]
    @Query private var allCurrencies: [CurrencyRecord]

    let transactionType: TransactionType

    @State private var amount = ""
    @State private var selectedAccount: Account?
    @State private var selectedDestinationAccount: Account?
    @State private var selectedCategory: Category?
    @State private var notes = ""
    @State private var selectedDate = Date()
    @State private var showingCategoryPicker = false
    @State private var showingNewCategorySheet = false
    @State private var selectedTransactionCurrency: Currency?  // DEPRECATED
    @State private var selectedTransactionCurrencyRecord: CurrencyRecord?
    @State private var destinationAmount = ""  // Importo manuale per destinazione
    @State private var isDestinationAmountManual = false  // Se true, usa valore manuale invece di conversione automatica

    // MARK: - Scheduled Transaction States
    @State private var isScheduled = false
    @State private var scheduledDate = Date()
    @State private var isAutomatic = false

    // MARK: - Recurring Transaction States
    @State private var isRecurring = false
    @State private var recurrenceInterval: Int = 1
    @State private var recurrenceUnit: RecurrenceUnit = .month
    @State private var hasEndDate = false
    @State private var recurrenceEndDate = Date()

    // MARK: - UI State
    @State private var hasSetDefaultAccount = false

    var transactionCurrency: Currency {
        selectedTransactionCurrency ?? selectedAccount?.currency ?? .EUR
    }

    var transactionCurrencyRecord: CurrencyRecord? {
        selectedTransactionCurrencyRecord ?? selectedAccount?.currencyRecord
    }

    var accountCurrencyRecord: CurrencyRecord? {
        selectedAccount?.currencyRecord
    }

    var needsConversion: Bool {
        guard let transCurr = transactionCurrencyRecord, let accCurr = accountCurrencyRecord else {
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

    // MARK: - Transfer Conversion Logic

    var transferNeedsConversion: Bool {
        guard transactionType == .transfer,
              let sourceCurr = selectedAccount?.currencyRecord,
              let destCurr = selectedDestinationAccount?.currencyRecord else {
            return false
        }
        return sourceCurr.code != destCurr.code
    }

    var autoConvertedDestinationAmount: Decimal? {
        guard transferNeedsConversion,
              let amountDecimal = Decimal(string: amount.replacingOccurrences(of: ",", with: ".")),
              let sourceCurr = selectedAccount?.currencyRecord,
              let destCurr = selectedDestinationAccount?.currencyRecord else {
            return nil
        }

        return CurrencyService.shared.convert(
            amount: amountDecimal,
            from: sourceCurr,
            to: destCurr,
            context: modelContext
        )
    }

    var finalDestinationAmount: Decimal? {
        if isDestinationAmountManual {
            return Decimal(string: destinationAmount.replacingOccurrences(of: ",", with: "."))
        }
        return autoConvertedDestinationAmount
    }

    // MARK: - Recurring Transaction Helpers

    var currentRecurrenceRule: RecurrenceRule {
        RecurrenceRule(interval: recurrenceInterval, unit: recurrenceUnit)
    }

    var nextOccurrences: [Date] {
        guard isRecurring else { return [] }

        let maxOccurrences = 5
        var occurrences: [Date] = []
        var currentDate = scheduledDate

        for _ in 0..<maxOccurrences {
            guard let nextDate = currentRecurrenceRule.nextOccurrence(from: currentDate) else {
                break
            }

            // Se c'è data fine, controlla che non sia superata
            if hasEndDate && nextDate > recurrenceEndDate {
                break
            }

            occurrences.append(nextDate)
            currentDate = nextDate
        }

        return occurrences
    }

    var totalOccurrences: Int {
        guard isRecurring, hasEndDate else { return 0 }

        var count = 0
        var currentDate = scheduledDate
        let endDate = recurrenceEndDate

        while let nextDate = currentRecurrenceRule.nextOccurrence(from: currentDate), nextDate <= endDate {
            count += 1
            currentDate = nextDate
            if count > 1000 { break } // Safety limit
        }

        return count
    }

    var body: some View {
        NavigationStack {
            Form {
                // CATEGORIA - Solo per expense/income
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
                }

                // CONTI - Prima per i trasferimenti
                if transactionType == .transfer {
                    Section {
                        NavigationLink {
                            AccountSelectionView(selectedAccount: $selectedAccount, showNavigationBar: false)
                        } label: {
                            accountRowLabel(title: "Da Conto", account: selectedAccount)
                        }
                        .id(selectedAccount?.id)  // Forza re-rendering quando account cambia

                        NavigationLink {
                            AccountSelectionView(selectedAccount: $selectedDestinationAccount, showNavigationBar: false)
                        } label: {
                            accountRowLabel(title: "A Conto", account: selectedDestinationAccount)
                        }
                        .id(selectedDestinationAccount?.id)  // Forza re-rendering quando account cambia
                    } header: {
                        Text("Trasferimento")
                    }
                }

                // IMPORTO
                Section {
                    HStack {
                        Text(transactionType == .transfer ? "Importo da prelevare" : "Importo")
                        Spacer()
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.title2.bold())
                            .onChange(of: amount) { _, _ in
                                // Reset manual override quando cambia l'importo
                                if transactionType == .transfer {
                                    isDestinationAmountManual = false
                                    if let converted = autoConvertedDestinationAmount {
                                        destinationAmount = formatDecimal(converted)
                                    }
                                }
                            }
                        if transactionType == .transfer {
                            Text(selectedAccount?.currencyRecord?.symbol ?? selectedAccount?.currency.symbol ?? "€")
                                .foregroundStyle(.secondary)
                        } else {
                            Text(transactionCurrencyRecord?.symbol ?? transactionCurrency.symbol)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Selezione valuta (solo per expense/income)
                    if transactionType != .transfer {
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

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }

                        // Mostra conversione se necessaria (per expense/income)
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
                    }
                } footer: {
                    if transactionType != .transfer && needsConversion,
                       let transCurr = transactionCurrencyRecord,
                       let accCurr = accountCurrencyRecord {
                        Text("L'importo verrà convertito da \(transCurr.code) a \(accCurr.code) usando il tasso di cambio corrente.")
                    }
                }

                // CONVERSIONE TRASFERIMENTO
                if transactionType == .transfer && transferNeedsConversion {
                    Section {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundStyle(.blue)
                            Text("Importo da accreditare")
                                .foregroundStyle(.secondary)

                            Spacer()

                            if !isDestinationAmountManual, let converted = autoConvertedDestinationAmount {
                                Text("\(selectedDestinationAccount?.currencyRecord?.symbol ?? "")\(formatDecimal(converted))")
                                    .font(.headline)
                                    .foregroundStyle(.blue)
                            }
                        }

                        Button {
                            isDestinationAmountManual.toggle()
                            if !isDestinationAmountManual, let converted = autoConvertedDestinationAmount {
                                destinationAmount = formatDecimal(converted)
                            }
                        } label: {
                            HStack {
                                Text(isDestinationAmountManual ? "Importo Manuale" : "Modifica Importo")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: isDestinationAmountManual ? "checkmark.circle.fill" : "pencil.circle")
                                    .foregroundStyle(isDestinationAmountManual ? .blue : .secondary)
                            }
                        }

                        if isDestinationAmountManual {
                            HStack {
                                Text("Importo personalizzato")
                                Spacer()
                                TextField("0.00", text: $destinationAmount)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .font(.title3.bold())
                                Text(selectedDestinationAccount?.currencyRecord?.symbol ?? "")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        Text("Conversione Valuta")
                    } footer: {
                        if let sourceCurr = selectedAccount?.currencyRecord,
                           let destCurr = selectedDestinationAccount?.currencyRecord {
                            Text("L'importo verrà convertito automaticamente da \(sourceCurr.code) a \(destCurr.code). Puoi modificare l'importo di destinazione se necessario.")
                        }
                    }
                }

                // CONTO (solo per expense/income)
                if transactionType != .transfer {
                    Section {
                        NavigationLink {
                            AccountSelectionView(selectedAccount: $selectedAccount, showNavigationBar: false)
                        } label: {
                            accountRowLabel(title: "Conto", account: selectedAccount)
                        }
                        .id(selectedAccount?.id)  // Forza re-rendering quando account cambia
                    }
                }

                Section {
                    DatePicker("Data", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
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
                        if newValue {
                            // Imposta data programmata a ora corrente (modificabile dall'utente)
                            scheduledDate = Date()
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
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(.blue)
                                    .font(.caption)
                                Text("La transazione verrà eseguita automaticamente alla data programmata")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(.orange)
                                    .font(.caption)
                                Text("Riceverai una notifica per confermare la transazione")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    if isScheduled {
                        Text("Programmazione")
                    }
                } footer: {
                    if isScheduled {
                        Text("Le transazioni programmate possono essere gestite dalla sezione Impostazioni")
                    }
                }

                // MARK: - Recurring Transaction Section
                if isScheduled {
                    Section {
                        Toggle(isOn: $isRecurring) {
                            HStack {
                                Image(systemName: "repeat.circle.fill")
                                    .foregroundStyle(.purple)
                                Text("Transazione Ricorrente")
                            }
                        }
                        .onChange(of: isRecurring) { _, newValue in
                            if newValue {
                                // Set end date a 1 anno nel futuro di default
                                recurrenceEndDate = Calendar.current.date(byAdding: .year, value: 1, to: scheduledDate) ?? scheduledDate
                            }
                        }

                        if isRecurring {
                            // Intervallo - Numero da 1 a 365
                            HStack {
                                Text("Ogni")
                                    .foregroundStyle(.secondary)

                                Spacer()

                                Picker("", selection: $recurrenceInterval) {
                                    ForEach(1...365, id: \.self) { number in
                                        Text("\(number)").tag(number)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(maxWidth: 100)
                            }

                            // Unità - Giorno/Mese/Anno
                            Picker("", selection: $recurrenceUnit) {
                                ForEach(RecurrenceUnit.allCases, id: \.self) { unit in
                                    Text(recurrenceInterval == 1 ? unit.rawValue : unit.pluralName)
                                        .tag(unit)
                                }
                            }
                            .pickerStyle(.segmented)

                            Toggle(isOn: $hasEndDate) {
                                HStack {
                                    Image(systemName: "calendar.badge.clock")
                                        .foregroundStyle(.orange)
                                    Text("Data Fine")
                                }
                            }

                            if hasEndDate {
                                DatePicker("Fino a", selection: $recurrenceEndDate, in: scheduledDate..., displayedComponents: [.date])
                                    .datePickerStyle(.compact)
                            }

                            // Preview delle prossime occorrenze
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "list.bullet.circle")
                                        .foregroundStyle(.purple)
                                    Text("Prossime Occorrenze")
                                        .font(.caption.bold())
                                        .foregroundStyle(.secondary)
                                }

                                ForEach(Array(nextOccurrences.enumerated()), id: \.offset) { index, date in
                                    HStack(spacing: 6) {
                                        Image(systemName: "\(index + 1).circle.fill")
                                            .font(.caption)
                                            .foregroundStyle(.purple)
                                        Text(date.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                // Mostra messaggio se non ci sono occorrenze (data fine troppo vicina)
                                if nextOccurrences.isEmpty {
                                    HStack(spacing: 6) {
                                        Image(systemName: "exclamationmark.triangle")
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                        Text("Nessuna occorrenza futura con queste impostazioni")
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                    }
                                }

                                // Mostra info sul totale
                                if hasEndDate {
                                    HStack(spacing: 6) {
                                        Image(systemName: "info.circle")
                                            .font(.caption)
                                            .foregroundStyle(.blue)
                                        if totalOccurrences > 5 {
                                            Text("Totale: \(totalOccurrences) ripetizioni (mostrate prime 5)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        } else {
                                            Text("Totale: \(totalOccurrences) ripetizioni")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                } else if !nextOccurrences.isEmpty && nextOccurrences.count == 5 {
                                    HStack(spacing: 6) {
                                        Image(systemName: "ellipsis.circle")
                                            .font(.caption)
                                            .foregroundStyle(.purple)
                                        Text("La ripetizione continua all'infinito (mostrate prime 5)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                // Indicatore modalità esecuzione
                                Divider()
                                    .padding(.vertical, 4)

                                HStack(spacing: 6) {
                                    Image(systemName: isAutomatic ? "bolt.fill" : "hand.tap.fill")
                                        .font(.caption)
                                        .foregroundStyle(isAutomatic ? .blue : .orange)
                                    Text(isAutomatic ? "Tutte le istanze saranno eseguite automaticamente" : "Tutte le istanze richiederanno conferma manuale")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    } header: {
                        if isRecurring {
                            Text("Ripetizione")
                        }
                    } footer: {
                        if isRecurring {
                            Text(currentRecurrenceRule.description)
                        }
                    }
                }

                Section("Note") {
                    TextField("Aggiungi note (opzionale)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(transactionType.rawValue)
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
                    .disabled(!isValid)
                }
            }
            .sheet(isPresented: $showingCategoryPicker) {
                CategoryPickerView(selectedCategory: $selectedCategory, transactionType: transactionType)
            }
            .onChange(of: selectedCategory) { oldValue, newValue in
                // Auto-seleziona il conto predefinito della categoria SOLO se non c'è già un account selezionato dall'utente
                if let category = newValue,
                   let defaultAccount = category.defaultAccount,
                   selectedAccount == nil {
                    selectedAccount = defaultAccount
                }
            }
            .onAppear {
                // Setta default account SOLO la prima volta
                if !hasSetDefaultAccount {
                    if let firstAccount = accounts.first {
                        selectedAccount = firstAccount
                    }
                    hasSetDefaultAccount = true
                }

                if transactionType == .income {
                    selectedCategory = categories.first { $0.categoryGroup?.name == "Entrate" }
                }
            }
        }
    }

    private var isValid: Bool {
        guard !amount.isEmpty,
              let _ = Decimal(string: amount.replacingOccurrences(of: ",", with: ".")),
              selectedAccount != nil else {
            return false
        }

        if transactionType == .transfer {
            return selectedDestinationAccount != nil
        }

        return true
    }

    private func saveTransaction() {
        guard let amountDecimal = Decimal(string: amount.replacingOccurrences(of: ",", with: ".")),
              let account = selectedAccount else {
            return
        }

        // Use selected currency or account's currency
        let currencyToUse = transactionCurrencyRecord ?? account.currencyRecord
        let currencyEnumToUse = transactionCurrency

        let transaction = Transaction(
            transactionType: transactionType,
            amount: amountDecimal,
            currency: currencyEnumToUse, // Usa la valuta selezionata
            date: selectedDate,
            notes: notes,
            account: account,
            category: selectedCategory,
            destinationAccount: selectedDestinationAccount
        )

        // Set SwiftData currency record
        transaction.currencyRecord = currencyToUse

        // Set destination amount for transfers with currency conversion
        if transactionType == .transfer && transferNeedsConversion {
            transaction.destinationAmount = finalDestinationAmount
        }

        // Set scheduled transaction fields
        if isScheduled {
            transaction.isScheduled = true
            transaction.scheduledDate = scheduledDate
            transaction.isAutomatic = isAutomatic
            transaction.status = .pending
        } else {
            transaction.status = .executed
        }

        // Set recurring transaction fields
        if isRecurring && isScheduled {
            transaction.isRecurring = true
            transaction.recurrenceRule = currentRecurrenceRule
            transaction.recurrenceEndDate = hasEndDate ? recurrenceEndDate : nil
        }

        modelContext.insert(transaction)

        // Update balance only for executed (non-scheduled) transactions
        if !isScheduled {
            account.updateBalance(context: modelContext)

            if let destinationAccount = selectedDestinationAccount {
                destinationAccount.updateBalance(context: modelContext)
            }
        }

        // Registra l'uso della valuta
        if let currencyRecord = currencyToUse {
            CurrencyService.shared.recordUsage(of: currencyRecord, context: modelContext)
        }

        try? modelContext.save()

        // Generate recurring instances if this is a recurring template
        if isRecurring && isScheduled {
            Task {
                await RecurringTransactionManager.shared.generateInstances(
                    for: transaction,
                    monthsAhead: 3,
                    modelContext: modelContext
                )
            }
        } else if isScheduled {
            // Schedule local notification for single scheduled transactions
            Task {
                await LocalNotificationManager.shared.scheduleNotification(for: transaction)
            }
        }

        dismiss()
    }

    private func formatDecimal(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "0.00"
    }

    @ViewBuilder
    private func accountRowLabel(title: String, account: Account?) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.primary)

            Spacer()

            if let account = account {
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

#Preview {
    AddTransactionView(transactionType: .expense)
        .modelContainer(for: [Account.self, Transaction.self, Category.self, CategoryGroup.self])
}
