//
//  EditBudgetView.swift
//  MoneyTracker
//
//  Created on 2026-01-08.
//

import SwiftUI
import SwiftData

struct EditBudgetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appSettings) var appSettings
    @Query private var categories: [Category]
    @Query private var allCurrencies: [CurrencyRecord]

    let budget: Budget

    @State private var selectedCategory: Category?
    @State private var amount: String = ""
    @State private var selectedPeriod: BudgetPeriod = .monthly
    @State private var startDate = Date()
    @State private var hasEndDate = false
    @State private var endDate = Date()
    @State private var selectedCurrency: CurrencyRecord?
    @State private var alertAt80Percent = true
    @State private var alertAt100Percent = true
    @State private var isActive = true
    @State private var showingCategorySelection = false

    var canSave: Bool {
        guard let _ = selectedCategory else { return false }
        guard let amountValue = Decimal(string: amount), amountValue > 0 else { return false }
        guard let _ = selectedCurrency else { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                // Category Selection
                Section {
                    Button {
                        showingCategorySelection = true
                    } label: {
                        HStack {
                            Text("Categoria")
                                .foregroundStyle(.primary)

                            Spacer()

                            if let category = selectedCategory {
                                HStack(spacing: 8) {
                                    if let imageData = category.imageData,
                                       let uiImage = UIImage(data: imageData) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 24, height: 24)
                                            .clipShape(Circle())
                                    } else {
                                        Image(systemName: category.icon)
                                            .foregroundStyle(category.color)
                                    }
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
                } header: {
                    Text("Dettagli")
                }

                // Amount
                Section {
                    HStack {
                        Text(selectedCurrency?.symbol ?? "€")
                            .foregroundStyle(.secondary)

                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                            .font(.title3.bold())
                    }
                } header: {
                    Text("Importo Budget")
                }

                // Period
                Section {
                    Picker("Periodo", selection: $selectedPeriod) {
                        ForEach(BudgetPeriod.allCases, id: \.self) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.menu)

                    if selectedPeriod == .custom {
                        DatePicker("Data Inizio", selection: $startDate, displayedComponents: .date)

                        Toggle("Imposta Data Fine", isOn: $hasEndDate)

                        if hasEndDate {
                            DatePicker("Data Fine", selection: $endDate, in: startDate..., displayedComponents: .date)
                        }
                    }
                } header: {
                    Text("Periodo")
                }

                // Currency
                Section {
                    NavigationLink {
                        CurrencySelectionView(selectedCurrency: $selectedCurrency)
                    } label: {
                        HStack {
                            Text("Valuta")

                            Spacer()

                            if let currency = selectedCurrency {
                                Text(currency.flagEmoji)
                                Text(currency.code)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Alerts
                Section {
                    Toggle(isOn: $alertAt80Percent) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("Avviso all'80%")
                        }
                    }

                    Toggle(isOn: $alertAt100Percent) {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.red)
                            Text("Avviso al 100%")
                        }
                    }
                } header: {
                    Text("Notifiche")
                }

                // Status
                Section {
                    Toggle("Budget Attivo", isOn: $isActive)
                } footer: {
                    Text("Disattiva il budget per non conteggiare più le spese")
                }
            }
            .navigationTitle("Modifica Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        updateBudget()
                    }
                    .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showingCategorySelection) {
                CategorySelectionView(selectedCategory: $selectedCategory)
            }
            .onAppear {
                loadBudgetData()
            }
        }
    }

    // MARK: - Load Data

    private func loadBudgetData() {
        selectedCategory = budget.category
        amount = budget.amount.description
        selectedPeriod = budget.period
        startDate = budget.startDate
        hasEndDate = budget.endDate != nil
        if let endDate = budget.endDate {
            self.endDate = endDate
        }
        selectedCurrency = budget.currencyRecord
        alertAt80Percent = budget.alertAt80Percent
        alertAt100Percent = budget.alertAt100Percent
        isActive = budget.isActive
    }

    // MARK: - Update Budget

    private func updateBudget() {
        guard let category = selectedCategory,
              let amountValue = Decimal(string: amount),
              let currency = selectedCurrency else {
            return
        }

        budget.category = category
        budget.amount = amountValue
        budget.period = selectedPeriod
        budget.startDate = selectedPeriod == .custom ? startDate : budget.startDate
        budget.endDate = (selectedPeriod == .custom && hasEndDate) ? endDate : nil
        budget.currencyRecord = currency
        budget.alertAt80Percent = alertAt80Percent
        budget.alertAt100Percent = alertAt100Percent
        budget.isActive = isActive

        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Error updating budget: \(error)")
        }
    }
}

//#Preview {
//    let config = ModelConfiguration(isStoredInMemoryOnly: true)
//    let container = try! ModelContainer(for: Budget.self, Category.self, CurrencyRecord.self, configurations: config)
//    let context = container.mainContext
//
//    let category = Category(name: "Caffè", icon: "cup.and.saucer.fill", colorHex: "#A2845E")
//    context.insert(category)
//
//    let currency = CurrencyRecord(code: "EUR", name: "Euro", symbol: "€", countryCode: "EU", flagEmoji: "🇪🇺")
//    context.insert(currency)
//
//    let budget = Budget(amount: 400, period: .monthly, currencyRecord: currency, category: category)
//    context.insert(budget)
//
//    EditBudgetView(budget: budget)
//        .environment(\.appSettings, AppSettings.shared)
//        .modelContainer(container)
//}
