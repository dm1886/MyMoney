//
//  AddTransactionView.swift
//  MoneyTracker
//
//  Created on 2026-01-01.
//

import SwiftUI
import SwiftData

enum InterestMode: String, CaseIterable {
    case percentage = "Percentuale"
    case manual = "Manuale"
}

struct AddTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var accounts: [Account]
    @Query private var suggestionTransactions: [Transaction]
    @FocusState private var amountFocused: Bool
    @Query private var categories: [Category]
    @Query private var allCurrencies: [CurrencyRecord]

    @State private var transactionType: TransactionType
    let initialDate: Date
    let defaultAccount: Account?

    init(transactionType: TransactionType, initialDate: Date = Date(), defaultAccount: Account? = nil) {
        _transactionType = State(initialValue: transactionType)
        self.initialDate = initialDate
        self.defaultAccount = defaultAccount
    }

    @State private var showingAddAccountAlert = false
    @State private var showingAddAccountSheet = false
    @State private var amount = ""
    @State private var selectedAccount: Account?
    @State private var selectedDestinationAccount: Account?
    @State private var selectedCategory: Category?
    @State private var notes = ""
    @State private var selectedDate: Date = Date()
    @State private var showingCategoryPicker = false
    @State private var showingNewCategorySheet = false
    @State private var selectedTransactionCurrency: Currency?  // DEPRECATED
    @State private var selectedTransactionCurrencyRecord: CurrencyRecord?
    @State private var destinationAmount = ""  // Importo manuale per destinazione
    @State private var isDestinationAmountManual = false  // Se true, usa valore manuale invece di conversione automatica
    
    // MARK: - Liability Payment States
    @State private var interestMode: InterestMode = .percentage
    @State private var interestPercentage = ""
    @State private var interestAmount = ""

    // MARK: - Scheduled Transaction States
    @State private var isScheduled = false
    @State private var isAutomatic = false

    // MARK: - Recurring Transaction States
    @State private var isRecurring = false
    @State private var recurrenceInterval: Int = 1
    @State private var recurrenceUnit: RecurrenceUnit = .month
    @State private var hasEndDate = false
    @State private var recurrenceEndDate = Date()
    @State private var adjustToWorkingDay = false
    @State private var includeStartDayInCount = false

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
              let amountDecimal = parseAmount(amount),
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
            return parseAmount(destinationAmount)
        }
        return autoConvertedDestinationAmount
    }
    
    // MARK: - Liability Payment Logic
    
    var calculatedInterest: Decimal? {
        guard transactionType == .liabilityPayment else { return nil }

        if interestMode == .manual {
            // Se vuoto, ritorna 0
            if interestAmount.isEmpty {
                return 0
            }
            return parseAmount(interestAmount)
        } else {
            // Se vuoto, ritorna 0
            if interestPercentage.isEmpty {
                return 0
            }

            // Percentuale sul debito totale del conto destinazione
            guard let percentage = parseAmount(interestPercentage),
                  let destAccount = selectedDestinationAccount else {
                return nil
            }

            let currentDebt = abs(destAccount.currentBalance)
            return (currentDebt * percentage) / 100
        }
    }
    
    var totalLiabilityPayment: Decimal? {
        guard transactionType == .liabilityPayment,
              let debtAmount = parseAmount(amount),
              let interest = calculatedInterest else {
            return nil
        }
        return debtAmount + interest
    }
    
    var liabilityPaymentCurrencyMismatch: Bool {
        guard transactionType == .liabilityPayment,
              let sourceAccount = selectedAccount,
              let destAccount = selectedDestinationAccount,
              let sourceCurr = sourceAccount.currencyRecord,
              let destCurr = destAccount.currencyRecord else {
            return false
        }
        return sourceCurr.code != destCurr.code
    }
    
    var isValidLiabilityDestination: Bool {
        guard transactionType == .liabilityPayment,
              let destAccount = selectedDestinationAccount else {
            return false
        }
        return destAccount.accountType == .liability || destAccount.accountType == .creditCard
    }

    // MARK: - Recurring Transaction Helpers

    var currentRecurrenceRule: RecurrenceRule {
        RecurrenceRule(interval: recurrenceInterval, unit: recurrenceUnit)
    }

    var nextOccurrences: [Date] {
        guard isRecurring else { return [] }

        let maxOccurrences = 5
        var occurrences: [Date] = []
        var currentDate = selectedDate

        for _ in 0..<maxOccurrences {
            guard let nextDate = currentRecurrenceRule.nextOccurrence(from: currentDate, includeStartDayInCount: includeStartDayInCount) else {
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
        var currentDate = selectedDate
        let endDate = recurrenceEndDate

        while let nextDate = currentRecurrenceRule.nextOccurrence(from: currentDate), nextDate <= endDate {
            count += 1
            currentDate = nextDate
            if count > 1000 { break } // Safety limit
        }

        return count
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
        NavigationStack {
            Form {
                Section {
                    OrbSegmented(values: [TransactionType.expense, .income, .transfer, .liabilityPayment, .adjustment], selection: $transactionType) { $0.rawValue }
                }.listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                // IMPORTO
                Section {
                    HStack(spacing: 12) {
                        OrbView(size: 56, primary: transactionType.orbColor, isAnimating: false) {
                            Image(systemName: transactionType.icon).font(.title2)
                        }.accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                        Text(transactionType == .transfer ? "Importo da prelevare" : transactionType == .liabilityPayment ? "Importo Debito" : "Importo")
                            .font(.orbCaption).foregroundStyle(Color.orbMuted)
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.orbDisplay).monospacedDigit().lineLimit(1).minimumScaleFactor(0.2)
                            .focused($amountFocused)
                            .onChange(of: amount) { _, _ in
                                // Reset manual override quando cambia l'importo
                                if transactionType == .transfer {
                                    isDestinationAmountManual = false
                                    if let converted = autoConvertedDestinationAmount {
                                        destinationAmount = formatDecimal(converted)
                                    }
                                }
                            }
                        }
                        if transactionType == .transfer {
                            Text(selectedAccount?.currencyRecord?.symbol ?? selectedAccount?.currency.symbol ?? "€")
                                .foregroundStyle(Color.orbMuted)
                        } else {
                            Text(transactionCurrencyRecord?.symbol ?? transactionCurrency.symbol)
                                .foregroundStyle(Color.orbMuted)
                        }
                    }

                    // Selezione valuta (solo per expense/income)
                    if transactionType != .transfer {
                        NavigationLink {
                            CurrencySelectionView(selectedCurrency: $selectedTransactionCurrencyRecord)
                        } label: {
                            HStack {
                                Text("Valuta")
                                    .foregroundStyle(Color.orbText)

                                Spacer()

                                if let currency = selectedTransactionCurrencyRecord {
                                    HStack(spacing: 8) {
                                        Text(currency.flagEmoji)
                                        Text(currency.code)
                                            .foregroundStyle(Color.orbMuted)
                                    }
                                } else if let accountCurr = accountCurrencyRecord {
                                    HStack(spacing: 8) {
                                        Text(accountCurr.flagEmoji)
                                        Text("Valuta del conto (\(accountCurr.code))")
                                            .foregroundStyle(Color.orbMuted)
                                    }
                                } else {
                                    Text("Seleziona")
                                        .foregroundStyle(Color.orbMuted)
                                }
                            }
                        }

                        // Mostra conversione se necessaria (per expense/income)
                        if needsConversion, let converted = convertedAmount {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .foregroundStyle(Color.orbHighlight)
                                Text("Convertito")
                                    .foregroundStyle(Color.orbMuted)
                                Spacer()
                                if let accCurr = accountCurrencyRecord {
                                    Text("\(accCurr.symbol)\(formatDecimal(converted))")
                                        .font(.orbHeadline)
                                        .foregroundStyle(Color.orbHighlight)
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
                }.listRowBackground(Color.orbCard)

                // CONTO - Solo per expense/income
                if transactionType != .transfer && transactionType != .liabilityPayment {
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
                            accountRowLabel(title: "Conto", account: selectedAccount)
                        }
                        .id(selectedAccount?.id)  // Forza re-rendering quando account cambia
                    }.listRowBackground(Color.orbCard)
                }

                // CONTI - Per i trasferimenti
                if transactionType == .transfer {
                    Section {
                        NavigationLink {
                            AccountSelectionView(
                                selectedAccount: $selectedAccount,
                                showNavigationBar: false,
                                transactionType: transactionType,
                                title: "Da Conto",
                                excludedAccount: selectedDestinationAccount  // Escludi il conto destinazione
                            )
                        } label: {
                            accountRowLabel(title: "Da Conto", account: selectedAccount)
                        }
                        .id(selectedAccount?.id)  // Forza re-rendering quando account cambia

                        NavigationLink {
                            AccountSelectionView(
                                selectedAccount: $selectedDestinationAccount,
                                showNavigationBar: false,
                                transactionType: transactionType,
                                title: "A Conto",
                                excludedAccount: selectedAccount  // Escludi il conto origine
                            )
                        } label: {
                            accountRowLabel(title: "A Conto", account: selectedDestinationAccount)
                        }
                        .id(selectedDestinationAccount?.id)  // Forza re-rendering quando account cambia
                    } header: {
                        Text("Trasferimento")
                    }.listRowBackground(Color.orbCard)
                }
                
                // CONTI - Per pagamento passività
                if transactionType == .liabilityPayment {
                    Section {
                        NavigationLink {
                            AccountSelectionView(
                                selectedAccount: $selectedAccount,
                                showNavigationBar: false,
                                transactionType: transactionType,
                                title: "Da Conto"
                            )
                        } label: {
                            accountRowLabel(title: "Da Conto", account: selectedAccount)
                        }
                        .id(selectedAccount?.id)

                        NavigationLink {
                            AccountSelectionView(
                                selectedAccount: $selectedDestinationAccount,
                                showNavigationBar: false,
                                transactionType: transactionType,
                                title: "Conto Passività"
                            )
                        } label: {
                            accountRowLabel(title: "Conto Passività", account: selectedDestinationAccount)
                        }
                        .id(selectedDestinationAccount?.id)
                        
                        // Warning per valute diverse
                        if liabilityPaymentCurrencyMismatch {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(Color.orbHighlight)
                                Text("I conti devono avere la stessa valuta")
                                    .font(.orbCaption)
                                    .foregroundStyle(Color.orbHighlight)
                            }
                        }
                        
                        // Warning per tipo conto errato
                        if selectedDestinationAccount != nil && !isValidLiabilityDestination {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(Color.orbNegative)
                                Text("Il conto destinazione deve essere Passività o Carta di Credito")
                                    .font(.orbCaption)
                                    .foregroundStyle(Color.orbNegative)
                            }
                        }
                    } header: {
                        Text("Pagamento Passività")
                    }.listRowBackground(Color.orbCard)
                }
                // CONVERSIONE TRASFERIMENTO
                if transactionType == .transfer && transferNeedsConversion {
                    Section {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundStyle(Color.orbHighlight)
                            Text("Importo da accreditare")
                                .foregroundStyle(Color.orbMuted)

                            Spacer()

                            if !isDestinationAmountManual, let converted = autoConvertedDestinationAmount {
                                Text("\(selectedDestinationAccount?.currencyRecord?.symbol ?? "")\(formatDecimal(converted))")
                                    .font(.orbHeadline)
                                    .foregroundStyle(Color.orbHighlight)
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
                                    .foregroundStyle(Color.orbText)
                                Spacer()
                                Image(systemName: isDestinationAmountManual ? "checkmark.circle.fill" : "pencil.circle")
                                    .foregroundStyle(isDestinationAmountManual ? Color.orbAccent : Color.orbMuted)
                            }
                        }

                        if isDestinationAmountManual {
                            HStack {
                                Text("Importo personalizzato")
                                Spacer()
                                TextField("0.00", text: $destinationAmount)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .font(.orbTitle3.bold())
                                Text(selectedDestinationAccount?.currencyRecord?.symbol ?? "")
                                    .foregroundStyle(Color.orbMuted)
                            }
                        }
                    } header: {
                        Text("Conversione Valuta")
                    } footer: {
                        if let sourceCurr = selectedAccount?.currencyRecord,
                           let destCurr = selectedDestinationAccount?.currencyRecord {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("L'importo verrà convertito automaticamente da \(sourceCurr.code) a \(destCurr.code). Puoi modificare l'importo di destinazione se necessario.")

                                // Mostra tasso di cambio effettivo
                                if let parsed = parseAmount(amount),
                                   parsed > 0,
                                   let destAmount = finalDestinationAmount {
                                    let effectiveRate = destAmount / parsed
                                    HStack(spacing: 4) {
                                        Image(systemName: isDestinationAmountManual ? "pencil.circle.fill" : "arrow.triangle.2.circlepath")
                                            .font(.orbCaption2)
                                            .foregroundStyle(isDestinationAmountManual ? Color.orbHighlight : Color.orbAccent)
                                        Text("Tasso: 1 \(sourceCurr.code) = \(formatDecimal(effectiveRate)) \(destCurr.code)")
                                            .font(.orbCaption)
                                        if isDestinationAmountManual {
                                            Text("(personalizzato)")
                                                .font(.orbCaption)
                                                .foregroundStyle(Color.orbHighlight)
                                        }
                                    }
                                    .padding(.top, 2)
                                }
                            }
                        }
                    }.listRowBackground(Color.orbCard)
                }
                
                // INTERESSI - Per pagamento passività
                if transactionType == .liabilityPayment {
                    Section {
                        Picker("Modalità Calcolo", selection: $interestMode) {
                            ForEach(InterestMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        if interestMode == .percentage {
                            HStack {
                                Text("Percentuale Interesse")
                                Spacer()
                                TextField("0.0", text: $interestPercentage)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .font(.orbBody)
                                Text("%")
                                    .foregroundStyle(Color.orbMuted)
                            }
                            
                            if let destAccount = selectedDestinationAccount {
                                HStack {
                                    Text("Debito Attuale")
                                        .foregroundStyle(Color.orbMuted)
                                    Spacer()
                                    Text("\(destAccount.currencyRecord?.symbol ?? "€")\(formatDecimal(abs(destAccount.currentBalance)))")
                                        .foregroundStyle(Color.orbNegative)
                                        .font(.orbCaption)
                                }
                            }
                        } else {
                            HStack {
                                Text("Importo Interesse")
                                Spacer()
                                TextField("0.00", text: $interestAmount)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .font(.orbBody)
                                Text(selectedAccount?.currencyRecord?.symbol ?? "€")
                                    .foregroundStyle(Color.orbMuted)
                            }
                        }
                        
                        // Riepilogo
                        if let debtAmount = parseAmount(amount),
                           let interest = calculatedInterest,
                           let total = totalLiabilityPayment {
                            VStack(spacing: 8) {
                                Divider()
                                
                                HStack {
                                    Text("Debito da pagare")
                                        .foregroundStyle(Color.orbMuted)
                                    Spacer()
                                    Text("\(selectedAccount?.currencyRecord?.symbol ?? "€")\(formatDecimal(debtAmount))")
                                        .font(.orbBody)
                                }
                                
                                HStack {
                                    Text("Interesse")
                                        .foregroundStyle(Color.orbMuted)
                                    Spacer()
                                    Text("\(selectedAccount?.currencyRecord?.symbol ?? "€")\(formatDecimal(interest))")
                                        .font(.orbBody)
                                        .foregroundStyle(Color.orbHighlight)
                                }
                                
                                Divider()
                                
                                HStack {
                                    Text("Totale da dedurre")
                                        .font(.orbHeadline)
                                    Spacer()
                                    Text("\(selectedAccount?.currencyRecord?.symbol ?? "€")\(formatDecimal(total))")
                                        .font(.orbTitle3.bold())
                                        .foregroundStyle(Color.orbNegative)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    } header: {
                        Text("Interessi (Opzionale)")
                    } footer: {
                        if interestMode == .percentage {
                            Text("L'interesse viene calcolato come percentuale del debito totale del conto passività. Lascia vuoto per pagamento senza interessi (0%).")
                        } else {
                            Text("Inserisci manualmente l'importo dell'interesse da pagare. Lascia vuoto per pagamento senza interessi.")
                        }
                    }.listRowBackground(Color.orbCard)
                }

                Section {
                    DatePicker("Data", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                }.listRowBackground(Color.orbCard)

                // CATEGORIA - Per expense/income e liability payment (opzionale)
                if transactionType != .transfer {
                    Section {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                            ForEach(categories.filter { $0.categoryGroup?.applicability.isApplicable(to: transactionType) ?? true }.sorted { $0.usageCount > $1.usageCount }.prefix(7)) { category in
                                Button { selectedCategory = category } label: {
                                    VStack(spacing: 8) {
                                        Image(systemName: category.icon).font(.orbTitle3).foregroundStyle(category.color)
                                        Text(category.name).font(.orbCaption).lineLimit(1).minimumScaleFactor(0.6)
                                    }.frame(maxWidth: .infinity).frame(minHeight: 68)
                                        .background(selectedCategory?.id == category.id ? category.color.opacity(0.15) : Color.orbCard2, in: RoundedRectangle(cornerRadius: 16))
                                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(selectedCategory?.id == category.id ? category.color : .clear, lineWidth: 1.5))
                                }.buttonStyle(.plain)
                            }
                            Button { showingCategoryPicker = true } label: {
                                VStack(spacing: 8) { Image(systemName: "ellipsis"); Text("Tutte…").font(.orbCaption) }.frame(maxWidth: .infinity).frame(minHeight: 68)
                            }.buttonStyle(.plain)
                        }
                        Button {
                            showingCategoryPicker = true
                        } label: {
                            HStack {
                                Text("Categoria")
                                    .foregroundStyle(Color.orbText)

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
                                            .foregroundStyle(Color.orbMuted)
                                    }
                                } else {
                                    Text(transactionType == .liabilityPayment ? "Opzionale" : "Seleziona")
                                        .foregroundStyle(Color.orbMuted)
                                }

                                Image(systemName: "chevron.right")
                                    .font(.orbCaption)
                                    .foregroundStyle(Color.orbMuted)
                            }
                        }
                    }.listRowBackground(Color.orbCard)
                }

                if !isRecurring {
                    let suggestions = RecurringSuggestions.find(in: suggestionTransactions, type: transactionType)
                    if !suggestions.isEmpty {
                        Section("Ricorrenti suggerite") {
                            ForEach(suggestions) { suggestion in
                                Button {
                                    let t = suggestion.transaction
                                    amount = NSDecimalNumber(decimal: t.amount).stringValue
                                    selectedAccount = t.account; selectedCategory = t.category
                                    selectedTransactionCurrencyRecord = t.currencyRecord
                                    selectedTransactionCurrency = t.currency; notes = t.notes
                                    isScheduled = true; isRecurring = true; isAutomatic = false
                                    selectedDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
                                    recurrenceUnit = .month; recurrenceInterval = 1
                                } label: {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(suggestion.transaction.notes.isEmpty ? (suggestion.transaction.category?.name ?? transactionType.rawValue) : suggestion.transaction.notes).font(.orbHeadline)
                                        Text("Ripetuta \(suggestion.count) volte · " + suggestion.transaction.displayAmount).font(.orbCaption)
                                        Text("Rendi ricorrente…").font(.orbSubheadline)
                                    }
                                }.buttonStyle(.plain)
                            }
                            Text("Suggerimenti da operazioni simili in giorni diversi. Controlla data, frequenza e importo prima di salvare; nessuna ricorrenza viene creata automaticamente.").font(.orbCaption)
                        }
                    }
                }

                // MARK: - Scheduled Transaction Section
                Section {
                    Toggle(isOn: $isScheduled) {
                        HStack {
                            Image(systemName: "clock.badge.checkmark")
                                .foregroundStyle(Color.orbHighlight)
                            Text("Programma Transazione")
                        }
                    }

                    if isScheduled {
                        Toggle(isOn: $isAutomatic) {
                            HStack {
                                Image(systemName: isAutomatic ? "bolt.fill" : "hand.tap.fill")
                                    .foregroundStyle(isAutomatic ? Color.orbAccent : Color.orbHighlight)
                                Text("Esecuzione Automatica")
                            }
                        }

                        if isAutomatic {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(Color.orbHighlight)
                                    .font(.orbCaption)
                                Text("La transazione verrà eseguita automaticamente alla data selezionata")
                                    .font(.orbCaption)
                                    .foregroundStyle(Color.orbMuted)
                            }
                            .padding(.vertical, 4)
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(Color.orbHighlight)
                                    .font(.orbCaption)
                                Text("Riceverai una notifica per confermare la transazione")
                                    .font(.orbCaption)
                                    .foregroundStyle(Color.orbMuted)
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
                        Text("La data della transazione sopra sarà usata come data di esecuzione programmata")
                    }
                }.listRowBackground(Color.orbCard)

                // MARK: - Recurring Transaction Section
                if isScheduled {
                    Section {
                        Toggle(isOn: $isRecurring) {
                            HStack {
                                Image(systemName: "repeat.circle.fill")
                                    .foregroundStyle(Color.orbHighlight)
                                Text("Transazione Ricorrente")
                            }
                        }
                        .onChange(of: isRecurring) { _, newValue in
                            if newValue {
                                // Set end date a 1 anno nel futuro di default
                                recurrenceEndDate = Calendar.current.date(byAdding: .year, value: 1, to: selectedDate) ?? selectedDate
                            }
                        }

                        if isRecurring {
                            // Intervallo - Numero da 1 a 365
                            HStack {
                                Text("Ogni")
                                    .foregroundStyle(Color.orbMuted)

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
                                        .foregroundStyle(Color.orbHighlight)
                                    Text("Data Fine")
                                }
                            }

                            if hasEndDate {
                                DatePicker("Fino a", selection: $recurrenceEndDate, in: selectedDate..., displayedComponents: [.date])
                                    .datePickerStyle(.compact)
                            }

                            // Working day adjustment toggle
                            Toggle(isOn: $adjustToWorkingDay) {
                                HStack {
                                    Image(systemName: "briefcase.fill")
                                        .foregroundStyle(Color.orbHighlight)
                                    Text("Giorno Lavorativo")
                                }
                            }

                            if adjustToWorkingDay {
                                HStack(spacing: 8) {
                                    Image(systemName: "info.circle")
                                        .foregroundStyle(Color.orbHighlight)
                                        .font(.orbCaption)
                                    Text("Se la data cade di sabato o domenica, la transazione verrà spostata al lunedì successivo")
                                        .font(.orbCaption)
                                        .foregroundStyle(Color.orbMuted)
                                }
                                .padding(.vertical, 4)
                            }

                            // Include start day in count toggle
                            Toggle(isOn: $includeStartDayInCount) {
                                HStack {
                                    Image(systemName: "calendar.badge.clock")
                                        .foregroundStyle(Color.orbHighlight)
                                    Text("Includi Giorno Iniziale")
                                }
                            }

                            if includeStartDayInCount {
                                HStack(spacing: 8) {
                                    Image(systemName: "info.circle")
                                        .foregroundStyle(Color.orbHighlight)
                                        .font(.orbCaption)
                                    Text("Il giorno di inizio conta come 'giorno 1'. Es: ogni 15 giorni dal 2 feb = 16 feb (invece di 17 feb)")
                                        .font(.orbCaption)
                                        .foregroundStyle(Color.orbMuted)
                                }
                                .padding(.vertical, 4)
                            }

                            // Preview delle prossime occorrenze
                            VStack(alignment: .leading, spacing: 8) {
                                // Prima transazione (la data selezionata)
                                HStack {
                                    Image(systemName: "1.circle.fill")
                                        .foregroundStyle(Color.orbPositive)
                                    Text("Prima transazione")
                                        .font(.orbCaption.bold())
                                        .foregroundStyle(Color.orbMuted)
                                }

                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.right")
                                        .font(.orbCaption)
                                        .foregroundStyle(Color.orbPositive)
                                    Text(selectedDate.formatted(date: .abbreviated, time: .shortened))
                                        .font(.orbCaption)
                                        .foregroundStyle(Color.orbText)
                                        .bold()
                                }
                                .padding(.leading, 4)

                                Divider()
                                    .padding(.vertical, 4)

                                HStack {
                                    Image(systemName: "list.bullet.circle")
                                        .foregroundStyle(Color.orbHighlight)
                                    Text("Prossime Ripetizioni")
                                        .font(.orbCaption.bold())
                                        .foregroundStyle(Color.orbMuted)
                                }

                                ForEach(Array(nextOccurrences.enumerated()), id: \.offset) { index, date in
                                    HStack(spacing: 6) {
                                        Image(systemName: "\(index + 2).circle.fill")
                                            .font(.orbCaption)
                                            .foregroundStyle(Color.orbHighlight)
                                        Text(date.formatted(date: .abbreviated, time: .shortened))
                                            .font(.orbCaption)
                                            .foregroundStyle(Color.orbMuted)
                                    }
                                }

                                // Mostra messaggio se non ci sono occorrenze (data fine troppo vicina)
                                if nextOccurrences.isEmpty {
                                    HStack(spacing: 6) {
                                        Image(systemName: "exclamationmark.triangle")
                                            .font(.orbCaption)
                                            .foregroundStyle(Color.orbHighlight)
                                        Text("Nessuna occorrenza futura con queste impostazioni")
                                            .font(.orbCaption)
                                            .foregroundStyle(Color.orbHighlight)
                                    }
                                }

                                // Mostra info sul totale
                                if hasEndDate {
                                    HStack(spacing: 6) {
                                        Image(systemName: "info.circle")
                                            .font(.orbCaption)
                                            .foregroundStyle(Color.orbHighlight)
                                        if totalOccurrences > 5 {
                                            Text("Totale: \(totalOccurrences) ripetizioni (mostrate prime 5)")
                                                .font(.orbCaption)
                                                .foregroundStyle(Color.orbMuted)
                                        } else {
                                            Text("Totale: \(totalOccurrences) ripetizioni")
                                                .font(.orbCaption)
                                                .foregroundStyle(Color.orbMuted)
                                        }
                                    }
                                } else if !nextOccurrences.isEmpty && nextOccurrences.count == 5 {
                                    HStack(spacing: 6) {
                                        Image(systemName: "ellipsis.circle")
                                            .font(.orbCaption)
                                            .foregroundStyle(Color.orbHighlight)
                                        Text("La ripetizione continua all'infinito (mostrate prime 5)")
                                            .font(.orbCaption)
                                            .foregroundStyle(Color.orbMuted)
                                    }
                                }

                                // Indicatore modalità esecuzione
                                Divider()
                                    .padding(.vertical, 4)

                                HStack(spacing: 6) {
                                    Image(systemName: isAutomatic ? "bolt.fill" : "hand.tap.fill")
                                        .font(.orbCaption)
                                        .foregroundStyle(isAutomatic ? Color.orbAccent : Color.orbHighlight)
                                    Text(isAutomatic ? "Tutte le transazioni saranno eseguite automaticamente" : "Tutte le transazioni richiederanno conferma manuale")
                                        .font(.orbCaption)
                                        .foregroundStyle(Color.orbMuted)
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
                    }.listRowBackground(Color.orbCard)
                }

                Section("Note") {
                    TextField("Aggiungi note (opzionale)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }.listRowBackground(Color.orbCard)
            }.listSectionSpacing(16).orbScreen()
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
                // Auto-seleziona il conto predefinito della categoria
                if let category = newValue,
                   let defaultAccount = category.defaultAccount {
                    selectedAccount = defaultAccount
                    LogManager.shared.info("Auto-selected default account '\(defaultAccount.name)' for category '\(category.name)'", category: "AddTransaction")
                }
            }
            .onChange(of: selectedAccount) { oldValue, newValue in
                // Per trasferimenti: resetta il conto di destinazione se diventa uguale all'origine
                if transactionType == .transfer,
                   let origin = newValue,
                   let destination = selectedDestinationAccount,
                   origin.id == destination.id {
                    selectedDestinationAccount = nil
                }
            }
            .onChange(of: selectedDestinationAccount) { oldValue, newValue in
                // Per trasferimenti: resetta il conto di origine se diventa uguale alla destinazione
                if transactionType == .transfer,
                   let destination = newValue,
                   let origin = selectedAccount,
                   origin.id == destination.id {
                    selectedAccount = nil
                }
            }
            .animation(.easeInOut(duration: 0.5), value: transactionType)
            .onChange(of: transactionType) { _, type in
                selectedDestinationAccount = nil
                isDestinationAmountManual = false
                destinationAmount = ""
                if type == .transfer { selectedCategory = nil }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Fatto") { amountFocused = false }
                }
            }
            .onAppear {
                // Set the date from calendar selection
                selectedDate = initialDate

                // Check if there are no accounts
                if accounts.isEmpty {
                    showingAddAccountAlert = true
                    return
                }

                // Setta default account SOLO la prima volta
                if !hasSetDefaultAccount {
                    // Use provided defaultAccount if available, otherwise first account
                    if let providedDefault = defaultAccount {
                        selectedAccount = providedDefault
                    } else if let firstAccount = accounts.first {
                        selectedAccount = firstAccount
                    }
                    hasSetDefaultAccount = true
                }

                if transactionType == .income {
                    selectedCategory = categories.first { $0.categoryGroup?.name == "Entrate" }
                }
            }
            .alert("Nessun Conto Disponibile", isPresented: $showingAddAccountAlert) {
                Button("Annulla", role: .cancel) {
                    dismiss()
                }
                Button("Crea Conto") {
                    showingAddAccountSheet = true
                }
            } message: {
                Text("Devi creare almeno un conto prima di poter aggiungere una transazione.")
            }
            .sheet(isPresented: $showingAddAccountSheet) {
                AddAccountView()
            }
        }
    }

    private var isValid: Bool {
        guard !amount.isEmpty,
              let _ = parseAmount(amount),
              selectedAccount != nil else {
            return false
        }

        if transactionType == .transfer {
            return selectedDestinationAccount != nil
        }
        
        if transactionType == .liabilityPayment {
            // Conto destinazione obbligatorio
            guard selectedDestinationAccount != nil else { return false }

            // Deve essere Passività o Carta di Credito
            guard isValidLiabilityDestination else { return false }

            // Valute devono essere uguali
            guard !liabilityPaymentCurrencyMismatch else { return false }

            // Interesse opzionale - se specificato deve essere valido
            if interestMode == .percentage {
                if !interestPercentage.isEmpty {
                    guard let _ = parseAmount(interestPercentage) else {
                        return false
                    }
                }
            } else {
                if !interestAmount.isEmpty {
                    guard let _ = parseAmount(interestAmount) else {
                        return false
                    }
                }
            }

            return true
        }

        return true
    }

    private func saveTransaction() {
        guard let amountDecimal = parseAmount(amount),
              let account = selectedAccount else {
            return
        }

        LogManager.shared.info("Creating transaction: \(transactionType.rawValue), Amount: \(amountDecimal), Account: \(account.name)", category: "Transaction")

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

            // IMPORTANTE: Salva lo snapshot del tasso di cambio per preservare i calcoli storici
            if let _ = currencyToUse,
               let _ = selectedDestinationAccount?.currencyRecord,
               let destAmount = finalDestinationAmount,
               let parsedAmount = parseAmount(amount),
               parsedAmount > 0 {
                // Calcola il tasso effettivo usato
                let effectiveRate = destAmount / parsedAmount
                transaction.exchangeRateSnapshot = effectiveRate

                // Marca come custom se l'utente ha modificato manualmente
                transaction.isCustomRate = isDestinationAmountManual
            }
        }

        // Set converted amount for expense/income with currency conversion
        if transactionType != .transfer && transactionType != .liabilityPayment && needsConversion {
            transaction.destinationAmount = convertedAmount

            // Salva snapshot anche per expense/income con conversione
            if let _ = currencyToUse,
               let _ = selectedAccount?.currencyRecord,
               let converted = convertedAmount,
               let parsedAmount = parseAmount(amount),
               parsedAmount > 0 {
                let effectiveRate = converted / parsedAmount
                transaction.exchangeRateSnapshot = effectiveRate
                transaction.isCustomRate = false  // Sempre automatico per expense/income
            }
        }
        
        // Set liability payment fields and create interest expense
        if transactionType == .liabilityPayment {
            if let interest = calculatedInterest {
                transaction.interestAmount = interest

                if interestMode == .percentage, let percentage = parseAmount(interestPercentage) {
                    transaction.interestPercentage = percentage
                }

                // Crea transazione spesa separata per l'interesse (anche se zero)
                let interestTransaction = Transaction(
                    transactionType: .expense,
                    amount: interest,
                    currency: currencyEnumToUse,
                    date: selectedDate,
                    notes: interest == 0 ? "Pagamento passività senza interessi - \(selectedDestinationAccount?.name ?? "")" : "Interessi su pagamento passività - \(selectedDestinationAccount?.name ?? "")",
                    account: account,
                    category: selectedCategory ?? categories.first { $0.name == "Interessi Passivi" },
                    destinationAccount: nil
                )
                interestTransaction.currencyRecord = currencyToUse
                interestTransaction.status = transaction.status  // Stesso status della transazione principale

                modelContext.insert(interestTransaction)

                LogManager.shared.info("Created interest expense: \(interest)", category: "LiabilityPayment")
            }
        }

        // Set scheduled transaction fields
        if isScheduled {
            transaction.isScheduled = true
            transaction.isAutomatic = isAutomatic

            // Se la data è nel passato, eseguila automaticamente
            // (sia automatiche che manuali, per evitare che rimangano invisibili)
            let isPastDate = selectedDate < Date()
            if isPastDate {
                transaction.status = .executed
                print("🕐 [AUTO-EXECUTE] Transazione programmata con data passata eseguita automaticamente")
            } else {
                transaction.status = .pending
            }
        } else {
            transaction.status = .executed
        }

        // Set recurring transaction fields
        if isRecurring && isScheduled {
            transaction.isRecurring = true
            transaction.recurrenceRule = currentRecurrenceRule
            transaction.recurrenceEndDate = hasEndDate ? recurrenceEndDate : nil
            transaction.adjustToWorkingDay = adjustToWorkingDay
            transaction.includeStartDayInCount = includeStartDayInCount
        }

        modelContext.insert(transaction)

        // IMPORTANTE: Salvare PRIMA di updateBalance() per assicurare che le relazioni inverse siano stabilite
        try? modelContext.save()

        // Registra l'uso della valuta
        if let currencyRecord = currencyToUse {
            CurrencyService.shared.recordUsage(of: currencyRecord, context: modelContext)
        }

        // Registra l'uso della categoria (solo per transazioni eseguite)
        if transaction.status == .executed, let category = selectedCategory {
            category.recordUsage()
        }

        // Haptic feedback for successful transaction save (immediate feedback)
        HapticManager.shared.transactionSaved()
        NotificationCenter.default.post(name: .orbSaveFeedback, object: nil)

        // Dismiss UI immediately for better UX (don't make user wait)
        dismiss()

        // ⚡️ PERFORMANCE: Do heavy operations asynchronously after dismiss
        Task { @MainActor in
            // Update balance only for executed transactions
            // NOTA: Questo deve avvenire DOPO save() per assicurare che le relazioni siano stabilite
            if transaction.status == .executed {
                account.updateBalance(context: modelContext)

                if let destinationAccount = selectedDestinationAccount {
                    destinationAccount.updateBalance(context: modelContext)
                }

                // Salva di nuovo dopo l'aggiornamento dei bilanci
                try? modelContext.save()
            }

            // Generate recurring instances if this is a recurring template
            if isRecurring && isScheduled {
                await RecurringTransactionManager.shared.generateInstances(
                    for: transaction,
                    monthsAhead: 12,
                    modelContext: modelContext
                )
            } else if isScheduled {
                // Schedule local notification for single scheduled transactions
                await LocalNotificationManager.shared.scheduleNotification(for: transaction)
            }

            LogManager.shared.success("Transaction created successfully", category: "Transaction")

            // Notify TodayView to refresh its transaction list
            NotificationCenter.default.post(name: .transactionsDidChange, object: nil)
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

    @ViewBuilder
    private func accountRowLabel(title: String, account: Account?) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(Color.orbText)

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
                        .foregroundStyle(Color.orbMuted)

                    if let currency = account.currencyRecord {
                        Text(currency.flagEmoji)
                            .font(.orbCaption)
                    }
                }
            } else {
                Text("Seleziona")
                    .foregroundStyle(Color.orbMuted)
            }
        }
    }
}

#Preview {
    AddTransactionView(transactionType: .expense)
        .modelContainer(for: [Account.self, Transaction.self, Category.self, CategoryGroup.self])
}
