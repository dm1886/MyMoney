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

    @State private var name = ""
    @State private var selectedType: AccountType = .payment
    @State private var selectedCurrency: Currency = .EUR
    @State private var initialBalance = ""
    @State private var selectedIcon = "creditcard.fill"
    @State private var selectedColor = Color.blue
    @State private var accountDescription = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var showingIconPicker = false

    let accountIcons = [
        "creditcard.fill", "banknote.fill", "dollarsign.circle.fill",
        "eurosign.circle.fill", "yensign.circle.fill", "sterlingsign.circle.fill",
        "building.columns.fill", "chart.line.uptrend.xyaxis", "wallet.pass.fill",
        "briefcase.fill", "bag.fill", "cart.fill"
    ]

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

                    HStack {
                        Text("Saldo Iniziale")
                        Spacer()
                        TextField("0.00", text: $initialBalance)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text(selectedCurrency.symbol)
                            .foregroundStyle(.secondary)
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
        }
    }

    private func saveAccount() {
        let balance = Decimal(string: initialBalance.replacingOccurrences(of: ",", with: ".")) ?? 0

        let account = Account(
            name: name,
            accountType: selectedType,
            currency: selectedCurrency,
            initialBalance: balance,
            icon: selectedIcon,
            colorHex: selectedColor.toHex() ?? "#007AFF",
            imageData: photoData,
            accountDescription: accountDescription
        )

        modelContext.insert(account)
        try? modelContext.save()

        dismiss()
    }
}

struct IconPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedIcon: String

    let accountIcons = [
        "creditcard.fill", "banknote.fill", "dollarsign.circle.fill",
        "eurosign.circle.fill", "yensign.circle.fill", "sterlingsign.circle.fill",
        "building.columns.fill", "chart.line.uptrend.xyaxis", "wallet.pass.fill",
        "briefcase.fill", "bag.fill", "cart.fill", "house.fill",
        "car.fill", "airplane", "tram.fill", "bicycle", "figure.walk",
        "fork.knife", "cup.and.saucer.fill", "heart.fill", "star.fill",
        "bolt.fill", "flame.fill", "drop.fill", "leaf.fill"
    ]

    let columns = [
        GridItem(.adaptive(minimum: 60))
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(accountIcons, id: \.self) { icon in
                        Button {
                            selectedIcon = icon
                            dismiss()
                        } label: {
                            VStack {
                                Image(systemName: icon)
                                    .font(.title)
                                    .foregroundStyle(selectedIcon == icon ? .blue : .primary)
                                    .frame(width: 50, height: 50)
                                    .background(
                                        Circle()
                                            .fill(selectedIcon == icon ? Color.blue.opacity(0.2) : Color.clear)
                                    )
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Scegli Icona")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fatto") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    AddAccountView()
        .modelContainer(for: [Account.self])
}
