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

    let transactionType: TransactionType

    @State private var amount = ""
    @State private var selectedAccount: Account?
    @State private var selectedDestinationAccount: Account?
    @State private var selectedCategory: Category?
    @State private var notes = ""
    @State private var selectedDate = Date()
    @State private var showingCategoryPicker = false
    @State private var showingNewCategorySheet = false
    @State private var selectedTransactionCurrency: Currency?

    var transactionCurrency: Currency {
        selectedTransactionCurrency ?? selectedAccount?.currency ?? .EUR
    }

    var accountCurrency: Currency {
        selectedAccount?.currency ?? .EUR
    }

    var needsConversion: Bool {
        transactionCurrency != accountCurrency
    }

    var convertedAmount: Decimal? {
        guard needsConversion,
              let amountDecimal = Decimal(string: amount.replacingOccurrences(of: ",", with: ".")) else {
            return nil
        }

        return CurrencyConverter.shared.convert(
            amount: amountDecimal,
            from: transactionCurrency,
            to: accountCurrency
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
                        Text(transactionCurrency.symbol)
                            .foregroundStyle(.secondary)
                    }

                    Picker("Valuta", selection: $selectedTransactionCurrency) {
                        Text("Valuta del conto (\(accountCurrency.rawValue))").tag(nil as Currency?)

                        let frequentCurrencies = CurrencyUsageTracker.shared.getFrequentCurrencies()
                        let recentCurrencies = CurrencyUsageTracker.shared.getRecentCurrenciesObjects()
                        let sortedCurrencies = CurrencyUsageTracker.shared.getSortedCurrencies()

                        // Sezione Frequenti
                        if !frequentCurrencies.isEmpty {
                            Section(header: Text("⭐️ Più Usate")) {
                                ForEach(frequentCurrencies, id: \.self) { currency in
                                    Text(currency.displayName).tag(currency as Currency?)
                                }
                            }
                        }

                        // Sezione Recenti
                        if !recentCurrencies.isEmpty {
                            Section(header: Text("🕒 Recenti")) {
                                ForEach(recentCurrencies, id: \.self) { currency in
                                    if !frequentCurrencies.contains(currency) {
                                        Text(currency.displayName).tag(currency as Currency?)
                                    }
                                }
                            }
                        }

                        // Tutte le altre
                        Section(header: Text("🌍 Tutte le Valute")) {
                            ForEach(sortedCurrencies, id: \.self) { currency in
                                if !frequentCurrencies.contains(currency) && !recentCurrencies.contains(currency) {
                                    Text(currency.displayName).tag(currency as Currency?)
                                }
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
                            Text("\(accountCurrency.symbol)\(formatDecimal(converted))")
                                .font(.headline)
                                .foregroundStyle(.blue)
                        }
                    }
                } footer: {
                    if needsConversion {
                        Text("L'importo verrà convertito da \(transactionCurrency.rawValue) a \(accountCurrency.rawValue) usando il tasso di cambio corrente.")
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

        let transaction = Transaction(
            transactionType: transactionType,
            amount: amountDecimal,
            currency: transactionCurrency, // Usa la valuta selezionata
            date: selectedDate,
            notes: notes,
            account: account,
            category: selectedCategory,
            destinationAccount: selectedDestinationAccount
        )

        modelContext.insert(transaction)

        account.updateBalance()

        if let destinationAccount = selectedDestinationAccount {
            destinationAccount.updateBalance()
        }

        // Registra l'uso della valuta
        CurrencyUsageTracker.shared.recordUsage(of: transactionCurrency)

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
