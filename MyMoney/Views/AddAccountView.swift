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
    @State private var assetMode: AssetMode = .simple
    @State private var annualRate = "0"
    @State private var investedBalance = "0"
    @State private var assetStart = Date()
    @State private var investmentPaywall = false
    @State private var saveError: String?
    @State private var initialBalance = ""
    @State private var creditLimit = ""
    @State private var creditInputAvailable = true
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
            return creditInputAvailable ? "Disponibilità iniziale" : (isPositiveBalance ? "Credito Iniziale" : "Debito Iniziale")
        case .liability:
            return "Debito Iniziale"
        case .asset:
            return assetMode == .stocks ? "Liquidità iniziale" : "Valore iniziale"
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
                                .foregroundStyle(Color.orbText)

                            Spacer()

                            if let currency = selectedCurrencyRecord {
                                HStack(spacing: 8) {
                                    Text(currency.flagEmoji)
                                    Text(currency.code)
                                        .foregroundStyle(Color.orbMuted)
                                }
                            } else {
                                Text("Seleziona")
                                    .foregroundStyle(Color.orbMuted)
                            }
                        }
                    }

                    if selectedType == .asset {
                        Picker("Modalità attività", selection: $assetMode) {
                            Text("Semplice · gratuita").tag(AssetMode.simple)
                            Text("Investimenti · Pro").tag(AssetMode.stocks)
                        }
                        if assetMode == .simple {
                            InvestmentNumberField(title: "Interesse annuo lordo %", text: $annualRate)
                            Text("Interesse semplice stimato, senza accrediti automatici o capitalizzazione.").font(.orbCaption).foregroundStyle(Color.orbMuted)
                        } else {
                            InvestmentNumberField(title: "Saldo investito iniziale", text: $investedBalance)
                            InvestmentNumberField(title: "Crescita annua attesa % (anche negativa)", text: $annualRate, allowsNegative: true)
                            Text("Proiezione locale senza API. Conferma il valore effettivo dal broker quando vuoi; liquidità e investimenti restano separati.").font(.orbCaption).foregroundStyle(Color.orbMuted)
                        }
                        DatePicker("Inizio monitoraggio", selection: $assetStart, in: ...Date(), displayedComponents: .date)
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
                            .foregroundStyle(Color.orbMuted)
                    }

                    // Toggle for positive balance (only for credit cards)
                    if selectedType == .creditCard {
                        Toggle("Inserisco disponibilità incluso plafond", isOn: $creditInputAvailable)
                        Text("Disponibilità 90.000 − limite 60.000 = saldo netto +30.000. Il plafond non è patrimonio.").font(.orbCaption)
                    }
                    if selectedType == .creditCard && !creditInputAvailable {
                        Toggle(isOn: $isPositiveBalance) {
                            HStack {
                                Image(systemName: isPositiveBalance ? "plus.circle.fill" : "minus.circle.fill")
                                    .foregroundStyle(isPositiveBalance ? Color.orbPositive : Color.orbNegative)
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
                                .foregroundStyle(Color.orbMuted)
                        }
                    }
                }.listRowBackground(Color.orbCard)

                Section("Personalizzazione") {
                    Button {
                        showingIconPicker = true
                    } label: {
                        HStack {
                            Text("Icona")
                            Spacer()
                            Image(systemName: selectedIcon)
                                .font(.orbTitle2)
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
                                    .foregroundStyle(Color.orbMuted)
                            }
                        }
                    }
                }.listRowBackground(Color.orbCard)

                Section("Descrizione") {
                    TextField("Aggiungi una descrizione (opzionale)", text: $accountDescription, axis: .vertical)
                        .lineLimit(3...6)
                }.listRowBackground(Color.orbCard)
            }.orbScreen()
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
            .sheet(isPresented: $investmentPaywall) { InvestmentPaywallView() }
            .alert("Conto non salvato", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) { Button("OK") { saveError = nil } } message: { Text(saveError ?? "") }
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
        if selectedType == .asset && assetMode == .stocks && !InvestmentAccess.shared.hasAccess { investmentPaywall = true; return }
        var newProfile: InvestmentProfile?
        if selectedType == .asset {
            guard let rate = InvestmentInput.decimal(annualRate), (assetMode == .simple ? Decimal(0)...Decimal(100) : Decimal(-100)...Decimal(100)).contains(rate),
                  let invested = InvestmentInput.decimal(investedBalance), invested >= 0,
                  let cash = InvestmentInput.decimal(initialBalance), cash >= 0 else {
                saveError = "Inserisci un valore iniziale valido, un tasso da 0 a 100 per attività semplici (da −100 a 100 per investimenti) e un saldo investito non negativo."; return
            }
            var profile = InvestmentProfile(mode: assetMode, startDate: assetStart, annualRate: rate)
            if assetMode == .stocks { profile.projection = InvestmentProjection(initialValue: invested, annualRate: rate); profile.annualRate = 0 }
            newProfile = profile
        }
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

        if selectedType == .creditCard && creditInputAvailable {
            guard let limit, limit >= 0, let available = InvestmentInput.decimal(initialBalance), available >= 0 else { saveError = "Inserisci disponibilità e limite validi."; return }
            balance = CreditCardMath.netBalance(available: available, limit: limit)
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

        do {
            if let newProfile {
                account.investmentData = try JSONEncoder().encode(newProfile)
                account.createdAt = assetStart
            }
            modelContext.insert(account)
            try modelContext.save()
        } catch {
            modelContext.delete(account)
            saveError = error.localizedDescription
            return
        }

        // Haptic feedback for successful account creation
        HapticManager.shared.accountSaved()
        NotificationCenter.default.post(name: .orbSaveFeedback, object: nil)

        dismiss()
    }
}

#Preview {
    AddAccountView()
        .modelContainer(for: [Account.self])
}
