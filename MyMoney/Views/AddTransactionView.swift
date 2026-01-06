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

                        NavigationLink {
                            AccountSelectionView(selectedAccount: $selectedDestinationAccount, showNavigationBar: false)
                        } label: {
                            accountRowLabel(title: "A Conto", account: selectedDestinationAccount)
                        }
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
                    }
                }

                Section {
                    DatePicker("Data", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
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
                // Auto-seleziona il conto predefinito della categoria
                if let category = newValue, let defaultAccount = category.defaultAccount {
                    selectedAccount = defaultAccount
                }
            }
            .onAppear {
                if let firstAccount = accounts.first {
                    selectedAccount = firstAccount
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

        modelContext.insert(transaction)

        account.updateBalance(context: modelContext)

        if let destinationAccount = selectedDestinationAccount {
            destinationAccount.updateBalance(context: modelContext)
        }

        // Registra l'uso della valuta
        if let currencyRecord = currencyToUse {
            CurrencyService.shared.recordUsage(of: currencyRecord, context: modelContext)
        }

        try? modelContext.save()

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
