//
//  RecurringExpensesView.swift
//  MoneyTracker
//
//  Created on 2026-01-08.
//

import SwiftUI
import SwiftData

struct RecurringExpensesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appSettings) var appSettings
    @Query private var categories: [Category]

    @State private var showingAddBudget = false
    @State private var selectedCategoryForBudget: Category?

    var recurringCategories: [Category] {
        categories.filter { $0.isRecurring }
            .sorted { $0.usageCount > $1.usageCount }
    }

    var body: some View {
        NavigationStack {
            Group {
                if recurringCategories.isEmpty {
                    emptyStateView
                } else {
                    categoriesList
                }
            }
            .navigationTitle("Spese Ricorrenti")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $selectedCategoryForBudget) { category in
                AddBudgetViewForCategory(category: category)
            }
        }
    }

    // MARK: - Categories List

    private var categoriesList: some View {
        List {
            Section {
                ForEach(recurringCategories) { category in
                    categoryRow(category)
                }
            } header: {
                Text("Categorie usate 3+ volte negli ultimi 30 giorni")
            } footer: {
                Text("Queste categorie vengono utilizzate frequentemente. Considera di impostare un budget per controllarle meglio.")
            }.listRowBackground(Color.orbCard)
        }.orbScreen()
        .listStyle(.insetGrouped)
    }

    // MARK: - Category Row

    private func categoryRow(_ category: Category) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Category icon (custom image or SF Symbol)
                if let imageData = category.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                } else {
                    ZStack {
                        Circle()
                            .fill(category.color.opacity(0.15))
                            .frame(width: 48, height: 48)

                        Image(systemName: category.icon)
                            .font(.orbTitle3)
                            .foregroundStyle(category.color)
                    }
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.name)
                        .font(.orbHeadline)

                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.orbCaption2)
                        Text("\(category.usageCount) utilizzi")
                            .font(.orbCaption)

                        if let lastUsed = category.lastUsedDate {
                            Text("•")
                                .font(.orbCaption)
                            Text(lastUsed, style: .relative)
                                .font(.orbCaption)
                        }
                    }
                    .foregroundStyle(Color.orbMuted)
                }

                Spacer()

                // Action
                if let activeBudget = category.activeBudget {
                    budgetBadge(activeBudget)
                } else {
                    Button {
                        selectedCategoryForBudget = category
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                            Text("Budget")
                        }
                        .font(.orbCaption.bold())
                        .foregroundStyle(Color.orbOnAccent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.orbAccent)
                        )
                    }
                }
            }

            // Usage in last 30 days detail
            if category.usageInLastDays(30) > 0 {
                HStack {
                    Label("\(category.usageInLastDays(30)) transazioni negli ultimi 30 giorni", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.orbCaption)
                        .foregroundStyle(Color.orbMuted)

                    Spacer()
                }
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Budget Badge

    private func budgetBadge(_ budget: Budget) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
            Text("Budget Attivo")
        }
        .font(.orbCaption.bold())
        .foregroundStyle(Color.orbPositive)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orbPositive.opacity(0.15))
        )
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.clockwise.circle")
                .font(.system(size: 60))
                .foregroundStyle(Color.orbAccent.opacity(0.3))

            Text("Nessuna Spesa Ricorrente")
                .font(.orbTitle3.bold())
                .foregroundStyle(Color.orbText)

            Text("Le categorie utilizzate frequentemente appariranno qui dopo almeno 3 transazioni negli ultimi 30 giorni")
                .font(.orbSubheadline)
                .foregroundStyle(Color.orbMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

// MARK: - Add Budget For Category

struct AddBudgetViewForCategory: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appSettings) var appSettings
    @Query private var allCurrencies: [CurrencyRecord]

    let category: Category

    @State private var amount: String = ""
    @State private var selectedPeriod: BudgetPeriod = .monthly
    @State private var startDate = Date()
    @State private var hasEndDate = false
    @State private var endDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var selectedCurrency: CurrencyRecord?
    @State private var alertAt80Percent = true
    @State private var alertAt100Percent = true

    var preferredCurrency: CurrencyRecord? {
        allCurrencies.first { $0.code == appSettings.preferredCurrencyEnum.rawValue }
    }

    var canSave: Bool {
        guard let amountValue = Decimal(string: amount), amountValue > 0 else { return false }
        guard let _ = selectedCurrency else { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                // Category Display (non-editable)
                Section {
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
                            .font(.orbHeadline)

                        Spacer()

                        Text("Ricorrente")
                            .font(.orbCaption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.orbAccent.opacity(0.15))
                            )
                            .foregroundStyle(Color.orbHighlight)
                    }
                } header: {
                    Text("Categoria")
                }.listRowBackground(Color.orbCard)

                // Amount
                Section {
                    HStack {
                        Text(selectedCurrency?.symbol ?? "€")
                            .foregroundStyle(Color.orbMuted)

                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                            .font(.orbTitle3.bold())
                    }
                } header: {
                    Text("Importo Budget")
                } footer: {
                    Text("Importo massimo da spendere per \(category.name)")
                }.listRowBackground(Color.orbCard)

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
                }.listRowBackground(Color.orbCard)

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
                                    .foregroundStyle(Color.orbMuted)
                            }
                        }
                    }
                }.listRowBackground(Color.orbCard)

                // Alerts
                Section {
                    Toggle(isOn: $alertAt80Percent) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.orbHighlight)
                            Text("Avviso all'80%")
                        }
                    }

                    Toggle(isOn: $alertAt100Percent) {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(Color.orbNegative)
                            Text("Avviso al 100%")
                        }
                    }
                } header: {
                    Text("Notifiche")
                } footer: {
                    Text("Ricevi notifiche quando raggiungi queste soglie del budget")
                }.listRowBackground(Color.orbCard)
            }.orbScreen()
            .navigationTitle("Nuovo Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Crea") {
                        saveBudget()
                    }
                    .disabled(!canSave)
                }
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
        guard let amountValue = Decimal(string: amount),
              let currency = selectedCurrency else {
            return
        }

        let budget = Budget(
            amount: amountValue,
            period: selectedPeriod,
            currencyRecord: currency,
            startDate: selectedPeriod == .custom ? startDate : Date(),
            endDate: (selectedPeriod == .custom && hasEndDate) ? endDate : nil,
            category: category
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

#Preview {
    RecurringExpensesView()
        .environment(\.appSettings, AppSettings.shared)
        .modelContainer(for: [Category.self, Budget.self])
}
