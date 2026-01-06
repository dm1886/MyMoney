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
    @Bindable var account: Account

    @State private var name: String
    @State private var selectedType: AccountType
    @State private var selectedCurrency: Currency
    @State private var selectedIcon: String
    @State private var selectedColor: Color
    @State private var accountDescription: String
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var showingIconPicker = false

    init(account: Account) {
        self.account = account
        _name = State(initialValue: account.name)
        _selectedType = State(initialValue: account.accountType)
        _selectedCurrency = State(initialValue: account.currency)
        _selectedIcon = State(initialValue: account.icon)
        _selectedColor = State(initialValue: account.color)
        _accountDescription = State(initialValue: account.accountDescription)
        _photoData = State(initialValue: account.imageData)
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

                    Picker("Valuta", selection: $selectedCurrency) {
                        ForEach(Currency.allCases, id: \.self) { currency in
                            Text("\(currency.flag) \(currency.rawValue) - \(currency.fullName)")
                                .foregroundStyle(.primary)
                                .tag(currency)
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
        account.currency = selectedCurrency
        account.icon = selectedIcon
        account.colorHex = selectedColor.toHex() ?? "#007AFF"
        account.accountDescription = accountDescription
        account.imageData = photoData

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
