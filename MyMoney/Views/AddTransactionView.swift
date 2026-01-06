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

    var body: some View {
        NavigationStack {
            Form {
                // CATEGORIA - Ora in cima
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

                // IMPORTO E VALUTA
                Section {
                    HStack {
                        Text("Importo")
                        Spacer()
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.title2.bold())
                        Text(transactionCurrencyRecord?.symbol ?? transactionCurrency.symbol)
                            .foregroundStyle(.secondary)
                    }

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
                    if needsConversion, let transCurr = transactionCurrencyRecord, let accCurr = accountCurrencyRecord {
                        Text("L'importo verrà convertito da \(transCurr.code) a \(accCurr.code) usando il tasso di cambio corrente.")
                    }
                }

                // CONTO
                Section {
                    Picker("Conto", selection: $selectedAccount) {
                        Text("Seleziona un conto").tag(nil as Account?)
                        ForEach(accounts) { account in
                            HStack {
                                Image(systemName: account.icon)
                                Text(account.name)
                            }
                            .tag(account as Account?)
                        }
                    }

                    if transactionType == .transfer {
                        Picker("A Conto", selection: $selectedDestinationAccount) {
                            Text("Seleziona destinazione").tag(nil as Account?)
                            ForEach(accounts.filter { $0.id != selectedAccount?.id }) { account in
                                HStack {
                                    Image(systemName: account.icon)
                                    Text(account.name)
                                }
                                .tag(account as Account?)
                            }
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
}

#Preview {
    AddTransactionView(transactionType: .expense)
        .modelContainer(for: [Account.self, Transaction.self, Category.self, CategoryGroup.self])
}
