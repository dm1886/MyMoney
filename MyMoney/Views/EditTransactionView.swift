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
            }
            .sheet(isPresented: $showingCategoryPicker) {
                CategoryPickerView(selectedCategory: $selectedCategory, transactionType: transaction.transactionType)
            }
        }
    }

    private func saveTransaction() {
        guard let amountDecimal = Decimal(string: amount.replacingOccurrences(of: ",", with: ".")) else { return }

        // Update transaction
        transaction.amount = amountDecimal
        transaction.account = selectedAccount
        transaction.category = selectedCategory
        transaction.notes = notes
        transaction.date = selectedDate
        transaction.currencyRecord = selectedTransactionCurrencyRecord

        // Update account balance
        if let account = selectedAccount {
            account.updateBalance(context: modelContext)
        }

        try? modelContext.save()
        dismiss()
    }
}
