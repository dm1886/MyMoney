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

        // Convert Decimal to String properly
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        let balanceString = formatter.string(from: account.initialBalance as NSDecimalNumber) ?? "0"
        _initialBalance = State(initialValue: balanceString)
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
                        Text(selectedCurrencyRecord?.symbol ?? selectedCurrency.symbol)
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $initialBalance)
                            .keyboardType(.decimalPad)
                            .font(.title3.bold())
                    }
                } header: {
                    Text("Saldo Iniziale")
                } footer: {
                    Text("Modifica il saldo iniziale del conto. Attenzione: questo modificherà la base di calcolo del saldo corrente.")
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
        account.name = name
        account.accountType = selectedType

        // Update both currency properties
        if let currencyRecord = selectedCurrencyRecord {
            account.currency = Currency(rawValue: currencyRecord.code) ?? .EUR
            account.currencyRecord = currencyRecord
        }

        account.icon = selectedIcon
        account.colorHex = selectedColor.toHex() ?? "#007AFF"
        account.accountDescription = accountDescription
        account.imageData = photoData

        // Update initial balance
        if let balanceDecimal = Decimal(string: initialBalance.replacingOccurrences(of: ",", with: ".")) {
            account.initialBalance = balanceDecimal
        }

        try? modelContext.save()
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
