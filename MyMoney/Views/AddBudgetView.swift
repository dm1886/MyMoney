//
//  AddBudgetView.swift
//  MoneyTracker
//
//  Created on 2026-01-08.
//

import SwiftUI
import SwiftData

struct AddBudgetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appSettings) var appSettings
    @Query private var categories: [Category]
    @Query private var allCurrencies: [CurrencyRecord]

    @State private var selectedCategory: Category?
    @State private var amount: String = ""
    @State private var selectedPeriod: BudgetPeriod = .monthly
    @State private var startDate = Date()
    @State private var hasEndDate = false
    @State private var endDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var selectedCurrency: CurrencyRecord?
    @State private var alertAt80Percent = true
    @State private var alertAt100Percent = true
    @State private var showingCategorySelection = false
    @State private var startFromPeriodBeginning: Bool? = true

    var preferredCurrency: CurrencyRecord? {
        allCurrencies.first { $0.code == appSettings.preferredCurrencyEnum.rawValue }
    }

    var canSave: Bool {
        guard let _ = selectedCategory else { return false }
        guard let amountValue = Decimal(string: amount), amountValue > 0 else { return false }
        guard let _ = selectedCurrency else { return false }
        return true
    }

    var startPeriodDescription: String {
        let calendar = Calendar.current
        let now = Date()

        switch selectedPeriod {
        case .daily:
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: calendar.startOfDay(for: now))
        case .weekly:
            let start = calendar.startOfWeek(for: now) ?? now
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: start)
        case .monthly:
            let start = calendar.startOfMonth(for: now) ?? now
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: start)
        case .yearly:
            let start = calendar.startOfYear(for: now) ?? now
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy"
            return formatter.string(from: start)
        case .custom:
            return ""
        }
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
                } footer: {
                    Text("Importo massimo che vuoi spendere in questa categoria")
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
                } footer: {
                    if selectedPeriod != .custom {
                        Text("Il budget si rinnova automaticamente ogni \(selectedPeriod.rawValue.lowercased())")
                    }
                }

                // Data Inizio Budget
                if selectedPeriod != .custom {
                    Section {
                        Toggle(isOn: Binding(
                            get: { startFromPeriodBeginning ?? true },
                            set: { startFromPeriodBeginning = $0 }
                        )) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Inizia da inizio periodo")
                                Text((startFromPeriodBeginning ?? true) ? startPeriodDescription : "Inizia da oggi")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } footer: {
                        if startFromPeriodBeginning ?? true {
                            Text("Il budget utilizzerà i dati dall'inizio del periodo corrente (\(startPeriodDescription))")
                        } else {
                            Text("Il budget partirà da oggi e si rinnoverà automaticamente ogni \(selectedPeriod.rawValue.lowercased())")
                        }
                    }
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
                } footer: {
                    Text("Ricevi notifiche quando raggiungi queste soglie del budget")
                }
            }
            .navigationTitle("Nuovo Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        saveBudget()
                    }
                    .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showingCategorySelection) {
                CategorySelectionView(selectedCategory: $selectedCategory)
            }
            .onAppear {
                if selectedCurrency == nil {
                    selectedCurrency = preferredCurrency
                }
            }
        }
    }

    // MARK: - Save Budget

    private func saveBudget() {
        guard let category = selectedCategory,
              let amountValue = Decimal(string: amount),
              let currency = selectedCurrency else {
            return
        }

        // Calcola la startDate corretta in base al periodo e al toggle
        let calculatedStartDate: Date
        if selectedPeriod == .custom {
            calculatedStartDate = startDate
        } else if startFromPeriodBeginning ?? true {
            // Toggle ON: inizia dall'inizio del periodo corrente
            let calendar = Calendar.current
            let now = Date()
            switch selectedPeriod {
            case .daily:
                calculatedStartDate = calendar.startOfDay(for: now)
            case .weekly:
                calculatedStartDate = calendar.startOfWeek(for: now) ?? now
            case .monthly:
                calculatedStartDate = calendar.startOfMonth(for: now) ?? now
            case .yearly:
                calculatedStartDate = calendar.startOfYear(for: now) ?? now
            case .custom:
                calculatedStartDate = startDate
            }
        } else {
            // Toggle OFF: inizia da oggi
            calculatedStartDate = Date()
        }

        let budget = Budget(
            amount: amountValue,
            period: selectedPeriod,
            currencyRecord: currency,
            startDate: calculatedStartDate,
            endDate: (selectedPeriod == .custom && hasEndDate) ? endDate : nil,
            category: category,
            startFromPeriodBeginning: startFromPeriodBeginning
        )

        budget.alertAt80Percent = alertAt80Percent
        budget.alertAt100Percent = alertAt100Percent

        modelContext.insert(budget)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Error saving budget: \(error)")
        }
    }
}

// MARK: - Category Selection View

struct CategorySelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appSettings) var appSettings
    @Query private var categoryGroups: [CategoryGroup]
    @Binding var selectedCategory: Category?

    var body: some View {
        NavigationStack {
            List {
                ForEach(categoryGroups) { group in
                    if let categories = group.categories, !categories.isEmpty {
                        Section(group.name) {
                            ForEach(categories) { category in
                                Button {
                                    selectedCategory = category
                                    dismiss()
                                } label: {
                                    HStack {
                                        if let imageData = category.imageData,
                                           let uiImage = UIImage(data: imageData) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 32, height: 32)
                                                .clipShape(Circle())
                                        } else {
                                            Image(systemName: category.icon)
                                                .foregroundStyle(category.color)
                                                .frame(width: 32)
                                        }

                                        Text(category.name)
                                            .foregroundStyle(.primary)

                                        Spacer()

                                        if selectedCategory?.id == category.id {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(appSettings.accentColor)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Seleziona Categoria")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    AddBudgetView()
        .environment(\.appSettings, AppSettings.shared)
        .modelContainer(for: [Budget.self, Category.self, CurrencyRecord.self])
}
