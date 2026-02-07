//
//  AddAccountView.swift
//  MoneyTracker
//
//  Created on 2026-01-01.
//

import SwiftUI
import SwiftData
import PhotosUI

struct AddAccountView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appSettings) var appSettings

    @Query private var allCurrencies: [CurrencyRecord]

    @State private var name = ""
    @State private var selectedType: AccountType = .payment
    @State private var selectedCurrency: Currency = .EUR  // DEPRECATED: Keep for backward compatibility
    @State private var selectedCurrencyRecord: CurrencyRecord?  // NUOVO: SwiftData currency
    @State private var initialBalance = ""
    @State private var creditLimit = ""
    @State private var selectedIcon = "creditcard.fill"
    @State private var selectedColor = Color.blue
    @State private var accountDescription = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var showingIconPicker = false
    @State private var showingCurrencyPicker = false
    @State private var isPositiveBalance = false  // Per carte di credito in positivo

    var balanceLabel: String {
        switch selectedType {
        case .creditCard:
            return isPositiveBalance ? "Credito Iniziale" : "Debito Iniziale"
        case .liability:
            return "Debito Iniziale"
        case .asset:
            return "Bilancio Iniziale"
        case .payment, .cash, .prepaidCard:
            return "Saldo Iniziale"
        }
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

                    HStack {
                        Text(balanceLabel)
                        Spacer()
                        TextField("0,00", text: $initialBalance)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: initialBalance) { oldValue, newValue in
                                // Filtra caratteri non validi: permetti solo numeri, virgola e segno meno
                                let filtered = newValue.filter { "0123456789,-".contains($0) }
                                
                                // Assicurati che ci sia al massimo una virgola
                                let commaCount = filtered.filter { $0 == "," }.count
                                if commaCount > 1 {
                                    var result = ""
                                    var commaFound = false
                                    for char in filtered {
                                        if char == "," {
                                            if !commaFound {
                                                result.append(char)
                                                commaFound = true
                                            }
                                        } else {
                                            result.append(char)
                                        }
                                    }
                                    initialBalance = result
                                } else if filtered != newValue {
                                    initialBalance = filtered
                                }
                            }
                        Text(selectedCurrencyRecord?.symbol ?? "€")
                            .foregroundStyle(.secondary)
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

                    // Credit limit field (only for credit cards)
                    if selectedType == .creditCard {
                        HStack {
                            Text("Limite Massimo")
                            Spacer()
                            TextField("0.00", text: $creditLimit)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                            Text(selectedCurrencyRecord?.symbol ?? "€")
                                .foregroundStyle(.secondary)
                        }
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
            .navigationTitle("Nuovo Conto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        saveAccount()
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
            .onAppear {
                // Set default currency to EUR if not already set
                if selectedCurrencyRecord == nil {
                    selectedCurrencyRecord = allCurrencies.first { $0.code == "EUR" }
                }
            }
        }
    }

    private func saveAccount() {
        // Rimuovi TUTTI i punti (separatori migliaia) e sostituisci virgola con punto per il parsing
        let cleanedBalance = initialBalance
            .replacingOccurrences(of: ".", with: "")  // Rimuovi punti delle migliaia
            .replacingOccurrences(of: ",", with: ".")  // Virgola decimale → punto per Decimal
        var balance = Decimal(string: cleanedBalance) ?? 0

        // For credit cards: respect the isPositiveBalance toggle
        // For liabilities: always store as negative (debt)
        if selectedType == .creditCard {
            if isPositiveBalance {
                // Saldo in positivo = credito
                balance = abs(balance)
                LogManager.shared.info("Creating credit card '\(name)' with positive balance (credit): \(balance)", category: "Account")
            } else {
                // Saldo in negativo = debito
                balance = -abs(balance)
                LogManager.shared.info("Creating credit card '\(name)' with negative balance (debt): \(balance)", category: "Account")
            }
        } else if selectedType == .liability {
            balance = -abs(balance)
        }

        // Use selected currency or default to EUR
        let currencyToUse = selectedCurrencyRecord ?? allCurrencies.first { $0.code == "EUR" }

        // Parse credit limit (only for credit cards)
        var limit: Decimal? = nil
        if selectedType == .creditCard {
            let cleanedLimit = creditLimit
                .replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: ",", with: ".")
            limit = Decimal(string: cleanedLimit)
        }

        let account = Account(
            name: name,
            accountType: selectedType,
            currency: Currency(rawValue: currencyToUse?.code ?? "EUR") ?? .EUR,  // Enum for compatibility
            initialBalance: balance,
            creditLimit: limit,
            icon: selectedIcon,
            colorHex: selectedColor.toHex() ?? "#007AFF",
            imageData: photoData,
            accountDescription: accountDescription
        )

        // Set SwiftData currency record
        account.currencyRecord = currencyToUse

        modelContext.insert(account)
        try? modelContext.save()

        // Haptic feedback for successful account creation
        HapticManager.shared.accountSaved()

        dismiss()
    }
}

#Preview {
    AddAccountView()
        .modelContainer(for: [Account.self])
}
