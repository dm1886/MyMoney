//
//  EditAccountView.swift
//  MoneyTracker
//
//  Created on 2026-01-01.
//

import SwiftUI
import SwiftData
import PhotosUI

struct EditAccountView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appSettings) var appSettings
    @Bindable var account: Account

    @Query private var allCurrencies: [CurrencyRecord]

    @State private var name: String
    @State private var selectedType: AccountType
    @State private var selectedCurrency: Currency  // DEPRECATED
    @State private var selectedCurrencyRecord: CurrencyRecord?  // NUOVO
    @State private var selectedIcon: String
    @State private var selectedColor: Color
    @State private var accountDescription: String
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var showingIconPicker = false
    @State private var initialBalance: String
    @State private var isPositiveBalance: Bool

    init(account: Account) {
        self.account = account
        _name = State(initialValue: account.name)
        _selectedType = State(initialValue: account.accountType)
        _selectedCurrency = State(initialValue: account.currency)
        _selectedCurrencyRecord = State(initialValue: account.currencyRecord)
        _selectedIcon = State(initialValue: account.icon)
        _selectedColor = State(initialValue: account.color)
        _accountDescription = State(initialValue: account.accountDescription)
        _photoData = State(initialValue: account.imageData)

        // Convert Decimal to String properly (use absolute value for display)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        let absBalance = abs(account.initialBalance)
        let balanceString = formatter.string(from: absBalance as NSDecimalNumber) ?? "0"
        _initialBalance = State(initialValue: balanceString)

        // Determine if balance is positive (for credit cards)
        _isPositiveBalance = State(initialValue: account.initialBalance >= 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Informazioni Base") {
                    TextField("Nome del Conto", text: $name)

                    Picker("Tipo di Conto", selection: $selectedType) {
                        ForEach(AccountType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }

                    NavigationLink {
                        CurrencySelectionView(selectedCurrency: $selectedCurrencyRecord)
                    } label: {
                        HStack {
                            Text("Valuta")
                                .foregroundStyle(.primary)

                            Spacer()

                            if let currency = selectedCurrencyRecord {
                                HStack(spacing: 8) {
                                    Text(currency.flagEmoji)
                                    Text(currency.code)
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                Text("Seleziona")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section {
                    HStack {
                        Text(selectedCurrencyRecord?.code ?? selectedCurrency.rawValue)
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $initialBalance)
                            .keyboardType(.decimalPad)
                            .font(.title3.bold())
                    }

                    // Toggle for positive balance (only for credit cards)
                    if selectedType == .creditCard {
                        Toggle(isOn: $isPositiveBalance) {
                            HStack {
                                Image(systemName: isPositiveBalance ? "plus.circle.fill" : "minus.circle.fill")
                                    .foregroundStyle(isPositiveBalance ? .green : .red)
                                Text("Saldo in Positivo")
                            }
                        }
                    }
                } header: {
                    Text(selectedType == .creditCard ? (isPositiveBalance ? "Credito Iniziale" : "Debito Iniziale") : "Saldo Iniziale")
                } footer: {
                    if selectedType == .creditCard {
                        Text("Attiva 'Saldo in Positivo' se la carta ha un credito invece di un debito. Questo modificherà il saldo base prima di sommare le transazioni.")
                    } else {
                        Text("Modifica il saldo iniziale del conto. Attenzione: questo modificherà il saldo base prima di sommare le transazioni.")
                    }
                }

                Section("Personalizzazione") {
                    Button {
                        showingIconPicker = true
                    } label: {
                        HStack {
                            Text("Icona")
                            Spacer()
                            Image(systemName: selectedIcon)
                                .font(.title2)
                                .foregroundStyle(selectedColor)
                        }
                    }

                    ColorPicker("Colore", selection: $selectedColor)

                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        HStack {
                            Text("Foto")
                            Spacer()
                            if let photoData, let uiImage = UIImage(data: photoData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 40, height: 40)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                Image(systemName: "photo")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Descrizione") {
                    TextField("Aggiungi una descrizione (opzionale)", text: $accountDescription, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Modifica Conto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        saveChanges()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .sheet(isPresented: $showingIconPicker) {
                IconPickerView(selectedIcon: $selectedIcon)
            }
            .onChange(of: selectedPhoto) { oldValue, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        photoData = data
                    }
                }
            }
        }
    }

    private func saveChanges() {
        LogManager.shared.info("Saving account changes for: \(account.name)", category: "AccountEdit")

        // Track what changed
        var changes: [String] = []

        if account.name != name {
            changes.append("name: '\(account.name)' → '\(name)'")
            account.name = name
        }

        if account.accountType != selectedType {
            changes.append("type: '\(account.accountType.rawValue)' → '\(selectedType.rawValue)'")
            account.accountType = selectedType
        }

        // Update both currency properties
        if let currencyRecord = selectedCurrencyRecord {
            let newCurrency = Currency(rawValue: currencyRecord.code) ?? .EUR
            if account.currency != newCurrency {
                changes.append("currency: '\(account.currency.rawValue)' → '\(newCurrency.rawValue)'")
            }
            account.currency = newCurrency
            account.currencyRecord = currencyRecord
        }

        if account.icon != selectedIcon {
            changes.append("icon: '\(account.icon)' → '\(selectedIcon)'")
            account.icon = selectedIcon
        }

        let newColorHex = selectedColor.toHex() ?? "#007AFF"
        if account.colorHex != newColorHex {
            changes.append("color: '\(account.colorHex)' → '\(newColorHex)'")
            account.colorHex = newColorHex
        }

        if account.accountDescription != accountDescription {
            changes.append("description updated")
            account.accountDescription = accountDescription
        }

        if account.imageData != photoData {
            changes.append("image updated")
            account.imageData = photoData
        }

        // Update initial balance - CRITICAL: parse correctly and update balance
        let cleanedBalance = initialBalance
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)

        if var balanceDecimal = Decimal(string: cleanedBalance) {
            // For credit cards: respect the isPositiveBalance toggle
            if selectedType == .creditCard {
                if isPositiveBalance {
                    // Saldo in positivo = credito
                    balanceDecimal = abs(balanceDecimal)
                } else {
                    // Saldo in negativo = debito
                    balanceDecimal = -abs(balanceDecimal)
                }
            } else if selectedType == .liability {
                // Liabilities always stored as negative (debt)
                balanceDecimal = -abs(balanceDecimal)
            }

            let oldBalance = account.initialBalance
            if oldBalance != balanceDecimal {
                changes.append("initialBalance: \(oldBalance) → \(balanceDecimal)")
                account.initialBalance = balanceDecimal

                // IMPORTANT: Recalculate the account balance with new initial balance
                account.updateBalance(context: modelContext)

                LogManager.shared.info("Initial balance changed from \(oldBalance) to \(balanceDecimal). Balance recalculated.", category: "AccountEdit")
            }
        } else {
            LogManager.shared.error("Failed to parse initial balance: '\(initialBalance)' (cleaned: '\(cleanedBalance)')", category: "AccountEdit")
        }

        if changes.isEmpty {
            LogManager.shared.debug("No changes detected for account: \(account.name)", category: "AccountEdit")
        } else {
            LogManager.shared.success("Account '\(account.name)' updated. Changes: \(changes.joined(separator: ", "))", category: "AccountEdit")
        }

        do {
            try modelContext.save()
            LogManager.shared.success("Account '\(account.name)' saved successfully", category: "AccountEdit")
        } catch {
            LogManager.shared.error("Failed to save account '\(account.name)': \(error.localizedDescription)", category: "AccountEdit")
        }

        dismiss()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Account.self, configurations: config)

    let account = Account(name: "Test Account", accountType: .payment, currency: .EUR)
    container.mainContext.insert(account)

    return EditAccountView(account: account)
        .modelContainer(container)
}
