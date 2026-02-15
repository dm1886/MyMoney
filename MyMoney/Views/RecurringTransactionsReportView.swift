//
//  RecurringTransactionsReportView.swift
//  MoneyTracker
//
//  Created on 2026-02-07.
//

import SwiftUI
import SwiftData

enum RecurringReportPeriod: String, CaseIterable {
    case daily = "Giornaliere"
    case monthly = "Mensili"
    case yearly = "Annuali"
    case all = "Tutte"
}

enum RecurringReportGrouping: String, CaseIterable {
    case none = "Nessuno"
    case category = "Per Categoria"
    case categoryGroup = "Per Gruppo"
    case account = "Per Conto"
}

struct RecurringTransactionGroup: Identifiable {
    let id = UUID()
    let name: String
    let transactions: [Transaction]
    let total: Decimal
    let occurrences: Int
    let icon: String
    let color: Color
}

struct RecurringTransactionsReportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appSettings) var appSettings
    @Query private var allTransactions: [Transaction]
    @Query private var accounts: [Account]
    @Query private var categories: [Category]
    @Query private var categoryGroups: [CategoryGroup]
    @Query private var allCurrencies: [CurrencyRecord]
    
    @State private var selectedPeriod: RecurringReportPeriod = .all
    @State private var selectedGrouping: RecurringReportGrouping = .category
    @State private var selectedAccounts: Set<UUID> = []
    @State private var selectedCategories: Set<UUID> = []
    @State private var selectedCategoryGroups: Set<UUID> = []
    @State private var showingAccountPicker = false
    @State private var showingCategoryPicker = false
    @State private var showingGroupPicker = false
    @State private var isLoading = true
    @State private var groupedData: [RecurringTransactionGroup] = []
    
    var preferredCurrencyRecord: CurrencyRecord? {
        allCurrencies.first { $0.code == appSettings.preferredCurrencyEnum.rawValue }
    }
    
    // Filtra solo transazioni ricorrenti template (non istanze)
    var recurringTransactions: [Transaction] {
        allTransactions.filter { transaction in
            // Solo transazioni ricorrenti template (non istanze generate)
            guard transaction.isRecurring, transaction.recurrenceRule != nil else {
                return false
            }
            
            // NON filtriamo più per tipo di ricorrenza (daily/monthly/yearly)
            // Il periodo selezionato determina solo l'intervallo temporale per il calcolo delle occorrenze
            
            // Filtra per conti
            if !selectedAccounts.isEmpty {
                guard let accountId = transaction.account?.id, selectedAccounts.contains(accountId) else {
                    return false
                }
            }
            
            // Filtra per categorie
            if !selectedCategories.isEmpty {
                guard let categoryId = transaction.category?.id, selectedCategories.contains(categoryId) else {
                    return false
                }
            }
            
            // Filtra per gruppi di categorie
            if !selectedCategoryGroups.isEmpty {
                guard let groupId = transaction.category?.categoryGroup?.id, selectedCategoryGroups.contains(groupId) else {
                    return false
                }
            }
            
            return true
        }
    }
    
    // Calcola le istanze nel periodo selezionato per una transazione ricorrente
    private func calculateOccurrences(for transaction: Transaction) -> Int {
        guard let rule = transaction.recurrenceRule else { return 1 }
        
        let calendar = Calendar.current
        let now = Date()
        
        // Determina l'intervallo in base al periodo selezionato
        let (startDate, endDate): (Date, Date)
        
        switch selectedPeriod {
        case .daily:
            // Inizio e fine del giorno corrente
            startDate = calendar.startOfDay(for: now)
            endDate = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: startDate) ?? now
            
        case .monthly:
            // Inizio e fine del mese corrente
            guard let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
                  let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start) else {
                return 1
            }
            startDate = start
            endDate = end
            
        case .yearly:
            // Inizio e fine dell'anno corrente
            guard let start = calendar.date(from: calendar.dateComponents([.year], from: now)),
                  let end = calendar.date(byAdding: DateComponents(year: 1, day: -1), to: start) else {
                return 1
            }
            startDate = start
            endDate = end
            
        case .all:
            // Per "Tutte", usiamo l'anno corrente come riferimento
            guard let start = calendar.date(from: calendar.dateComponents([.year], from: now)),
                  let end = calendar.date(byAdding: DateComponents(year: 1, day: -1), to: start) else {
                return 1
            }
            startDate = start
            endDate = end
        }
        
        var occurrenceCount = 0
        var currentDate = transaction.date
        
        // Se la transazione inizia prima del periodo, trova la prima occorrenza nel periodo
        if currentDate < startDate {
            while currentDate < startDate {
                guard let nextDate = rule.nextOccurrence(from: currentDate, includeStartDayInCount: transaction.includeStartDayInCount) else {
                    break
                }
                currentDate = nextDate
                
                // Evita loop infiniti
                if occurrenceCount > 10000 {
                    break
                }
            }
        }
        
        // Conta tutte le occorrenze nel periodo
        while currentDate <= endDate {
            // Verifica se la transazione è terminata
            if let recEndDate = transaction.recurrenceEndDate, currentDate > recEndDate {
                break
            }
            
            // Se la data è nel periodo, conta l'occorrenza
            if currentDate >= startDate && currentDate <= endDate {
                occurrenceCount += 1
            }
            
            // Calcola la prossima occorrenza
            guard let nextDate = rule.nextOccurrence(from: currentDate, includeStartDayInCount: transaction.includeStartDayInCount) else {
                break
            }
            
            currentDate = nextDate
            
            // Evita loop infiniti
            if occurrenceCount > 1000 {
                break
            }
        }
        
        return max(1, occurrenceCount)
    }
    
    var totalAmount: Decimal {
        groupedData.reduce(0) { $0 + $1.total }
    }
    
    var totalOccurrences: Int {
        recurringTransactions.reduce(0) { total, transaction in
            total + calculateOccurrences(for: transaction)
        }
    }
    
    var body: some View {
        ZStack {
            if isLoading {
                CategoryReportSkeletonView()
                    .transition(.opacity)
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        // Period Selector
                        periodSelector
                            .padding(.horizontal)
                            .padding(.top, 16)
                        
                        // Grouping Selector
                        groupingSelector
                            .padding(.horizontal)
                        
                        // Filters
                        filtersSection
                            .padding(.horizontal)
                        
                        // Total Card
                        totalCard
                            .padding(.horizontal)
                        
                        // Grouped List
                        groupedList
                            .padding(.horizontal)
                            .padding(.bottom, 20)
                    }
                }
                .transition(.opacity)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Transazioni Ricorrenti")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAccountPicker) {
            AccountFilterSheet(
                accounts: accounts,
                selectedAccounts: $selectedAccounts
            )
        }
        .sheet(isPresented: $showingCategoryPicker) {
            CategoryFilterSheet(
                categories: categories,
                selectedCategories: $selectedCategories
            )
        }
        .sheet(isPresented: $showingGroupPicker) {
            CategoryGroupFilterSheet(
                groups: categoryGroups,
                selectedGroups: $selectedCategoryGroups
            )
        }
        .onAppear {
            if selectedAccounts.isEmpty {
                selectedAccounts = Set(accounts.map { $0.id })
            }
            loadDataAsync()
        }
        .onChange(of: selectedPeriod) { _, _ in
            loadDataAsync()
        }
        .onChange(of: selectedGrouping) { _, _ in
            loadDataAsync()
        }
        .onChange(of: selectedAccounts) { _, _ in
            loadDataAsync()
        }
        .onChange(of: selectedCategories) { _, _ in
            loadDataAsync()
        }
        .onChange(of: selectedCategoryGroups) { _, _ in
            loadDataAsync()
        }
    }
    
    // MARK: - Period Selector
    
    private var periodSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Frequenza")
                .font(.headline)
                .foregroundStyle(.primary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(RecurringReportPeriod.allCases, id: \.self) { period in
                        Button {
                            HapticManager.shared.periodChanged()
                            withAnimation(.spring(response: 0.3)) {
                                selectedPeriod = period
                            }
                        } label: {
                            Text(period.rawValue)
                                .font(.subheadline.bold())
                                .foregroundStyle(selectedPeriod == period ? .white : appSettings.accentColor)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedPeriod == period ? appSettings.accentColor : Color(.secondarySystemGroupedBackground))
                                )
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    // MARK: - Grouping Selector
    
    private var groupingSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Raggruppa")
                .font(.headline)
                .foregroundStyle(.primary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(RecurringReportGrouping.allCases, id: \.self) { grouping in
                        Button {
                            HapticManager.shared.periodChanged()
                            withAnimation(.spring(response: 0.3)) {
                                selectedGrouping = grouping
                            }
                        } label: {
                            Text(grouping.rawValue)
                                .font(.subheadline.bold())
                                .foregroundStyle(selectedGrouping == grouping ? .white : appSettings.accentColor)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedGrouping == grouping ? appSettings.accentColor : Color(.secondarySystemGroupedBackground))
                                )
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    // MARK: - Filters Section
    
    private var filtersSection: some View {
        VStack(spacing: 12) {
            // Account Filter
            Button {
                showingAccountPicker = true
            } label: {
                FilterButton(
                    title: "Conti",
                    subtitle: accountFilterText,
                    icon: "building.columns.fill",
                    color: .blue
                )
            }
            
            // Category Filter
            Button {
                showingCategoryPicker = true
            } label: {
                FilterButton(
                    title: "Categorie",
                    subtitle: categoryFilterText,
                    icon: "tag.fill",
                    color: .green
                )
            }
            
            // Category Group Filter
            Button {
                showingGroupPicker = true
            } label: {
                FilterButton(
                    title: "Gruppi",
                    subtitle: groupFilterText,
                    icon: "folder.fill",
                    color: .orange
                )
            }
        }
    }
    
    private var accountFilterText: String {
        if selectedAccounts.isEmpty || selectedAccounts.count == accounts.count {
            return "Tutti i conti"
        } else {
            return "\(selectedAccounts.count) selezionati"
        }
    }
    
    private var categoryFilterText: String {
        if selectedCategories.isEmpty {
            return "Tutte le categorie"
        } else {
            return "\(selectedCategories.count) selezionate"
        }
    }
    
    private var groupFilterText: String {
        if selectedCategoryGroups.isEmpty {
            return "Tutti i gruppi"
        } else {
            return "\(selectedCategoryGroups.count) selezionati"
        }
    }
    
    // MARK: - Total Card
    
    private var totalCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "repeat.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.purple)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Totale Ricorrenti")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Text(formatAmount(totalAmount))
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(totalOccurrences)")
                        .font(.title2.bold())
                        .foregroundStyle(.purple)
                    
                    Text(totalOccurrences == 1 ? "occorrenza" : "occorrenze")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }
    
    // MARK: - Grouped List
    
    private var groupedList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dettaglio")
                .font(.headline)
                .foregroundStyle(.primary)
                .padding(.horizontal, 4)
            
            if groupedData.isEmpty {
                emptyState
            } else {
                VStack(spacing: 8) {
                    ForEach(groupedData) { group in
                        RecurringGroupRow(group: group)
                    }
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "repeat")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("Nessuna transazione ricorrente")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
    
    // MARK: - Load Data Async
    
    private func loadDataAsync() {
        isLoading = true
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000)
            
            let filtered = recurringTransactions
            var groups: [RecurringTransactionGroup] = []
            
            switch selectedGrouping {
            case .none:
                // Nessun raggruppamento - mostra tutte le transazioni
                if !filtered.isEmpty {
                    let total = calculateTotal(for: filtered)
                    let occurrences = filtered.reduce(0) { $0 + calculateOccurrences(for: $1) }
                    groups.append(RecurringTransactionGroup(
                        name: "Tutte le Transazioni",
                        transactions: filtered,
                        total: total,
                        occurrences: occurrences,
                        icon: "list.bullet",
                        color: .gray
                    ))
                }
                
            case .category:
                // Raggruppa per categoria
                let categoryDict = Dictionary(grouping: filtered) { $0.category?.id }
                
                for (categoryId, transactions) in categoryDict {
                    guard let categoryId = categoryId,
                          let category = categories.first(where: { $0.id == categoryId }) else {
                        continue
                    }
                    
                    let total = calculateTotal(for: transactions)
                    let occurrences = transactions.reduce(0) { $0 + calculateOccurrences(for: $1) }
                    groups.append(RecurringTransactionGroup(
                        name: category.name,
                        transactions: transactions,
                        total: total,
                        occurrences: occurrences,
                        icon: category.icon,
                        color: Color(hex: category.colorHex) ?? .gray
                    ))
                }
                
            case .categoryGroup:
                // Raggruppa per gruppo di categorie
                let groupDict = Dictionary(grouping: filtered) { $0.category?.categoryGroup?.id }
                
                for (groupId, transactions) in groupDict {
                    guard let groupId = groupId,
                          let group = categoryGroups.first(where: { $0.id == groupId }) else {
                        continue
                    }
                    
                    let total = calculateTotal(for: transactions)
                    let occurrences = transactions.reduce(0) { $0 + calculateOccurrences(for: $1) }
                    groups.append(RecurringTransactionGroup(
                        name: group.name,
                        transactions: transactions,
                        total: total,
                        occurrences: occurrences,
                        icon: group.icon,
                        color: Color(hex: group.colorHex) ?? .gray
                    ))
                }
                
            case .account:
                // Raggruppa per conto
                let accountDict = Dictionary(grouping: filtered) { $0.account?.id }
                
                for (accountId, transactions) in accountDict {
                    guard let accountId = accountId,
                          let account = accounts.first(where: { $0.id == accountId }) else {
                        continue
                    }
                    
                    let total = calculateTotal(for: transactions)
                    let occurrences = transactions.reduce(0) { $0 + calculateOccurrences(for: $1) }
                    groups.append(RecurringTransactionGroup(
                        name: account.name,
                        transactions: transactions,
                        total: total,
                        occurrences: occurrences,
                        icon: account.icon,
                        color: account.color
                    ))
                }
            }
            
            // Ordina per totale decrescente
            groups.sort { $0.total > $1.total }
            
            withAnimation(.easeOut(duration: 0.3)) {
                groupedData = groups
                isLoading = false
            }
        }
    }
    
    private func calculateTotal(for transactions: [Transaction]) -> Decimal {
        guard let preferredCurrency = preferredCurrencyRecord else {
            return transactions.reduce(0) { total, transaction in
                let occurrences = Decimal(calculateOccurrences(for: transaction))
                return total + (transaction.amount * occurrences)
            }
        }
        
        return transactions.reduce(0) { total, transaction in
            guard let transactionCurrency = transaction.currencyRecord else {
                let occurrences = Decimal(calculateOccurrences(for: transaction))
                return total + (transaction.amount * occurrences)
            }
            
            let converted = CurrencyService.shared.convert(
                amount: transaction.amount,
                from: transactionCurrency,
                to: preferredCurrency,
                context: modelContext
            )
            
            let occurrences = Decimal(calculateOccurrences(for: transaction))
            return total + (converted * occurrences)
        }
    }
    
    // MARK: - Helper Functions
    
    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = appSettings.preferredCurrencyEnum.rawValue
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }
}

// MARK: - Filter Button

struct FilterButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .foregroundStyle(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

// MARK: - Recurring Group Row

struct RecurringGroupRow: View {
    @Environment(\.appSettings) var appSettings
    let group: RecurringTransactionGroup
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(group.color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: group.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(group.color)
                }
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.name)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    
                    Text("\(group.occurrences) \(group.occurrences == 1 ? "occorrenza" : "occorrenze")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Amount
                Text(formatAmount(group.total))
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }
    
    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = appSettings.preferredCurrencyEnum.rawValue
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }
}

// MARK: - Category Filter Sheet

struct CategoryFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    let categories: [Category]
    @Binding var selectedCategories: Set<UUID>
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        if selectedCategories.isEmpty {
                            selectedCategories = Set(categories.map { $0.id })
                        } else {
                            selectedCategories.removeAll()
                        }
                    } label: {
                        HStack {
                            Text(selectedCategories.isEmpty ? "Seleziona Tutte" : "Deseleziona Tutte")
                            Spacer()
                            if selectedCategories.count == categories.count || selectedCategories.isEmpty {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
                
                Section {
                    ForEach(categories) { category in
                        Button {
                            if selectedCategories.contains(category.id) {
                                selectedCategories.remove(category.id)
                            } else {
                                selectedCategories.insert(category.id)
                            }
                        } label: {
                            HStack {
                                Image(systemName: category.icon)
                                    .foregroundStyle(Color(hex: category.colorHex) ?? .gray)
                                
                                Text(category.name)
                                    .foregroundStyle(.primary)
                                
                                Spacer()
                                
                                if selectedCategories.contains(category.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filtra Categorie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fine") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Category Group Filter Sheet

struct CategoryGroupFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    let groups: [CategoryGroup]
    @Binding var selectedGroups: Set<UUID>
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        if selectedGroups.isEmpty {
                            selectedGroups = Set(groups.map { $0.id })
                        } else {
                            selectedGroups.removeAll()
                        }
                    } label: {
                        HStack {
                            Text(selectedGroups.isEmpty ? "Seleziona Tutti" : "Deseleziona Tutti")
                            Spacer()
                            if selectedGroups.count == groups.count || selectedGroups.isEmpty {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
                
                Section {
                    ForEach(groups) { group in
                        Button {
                            if selectedGroups.contains(group.id) {
                                selectedGroups.remove(group.id)
                            } else {
                                selectedGroups.insert(group.id)
                            }
                        } label: {
                            HStack {
                                Image(systemName: group.icon)
                                    .foregroundStyle(Color(hex: group.colorHex) ?? .gray)
                                
                                Text(group.name)
                                    .foregroundStyle(.primary)
                                
                                Spacer()
                                
                                if selectedGroups.contains(group.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filtra Gruppi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fine") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        RecurringTransactionsReportView()
            .environment(\.appSettings, AppSettings.shared)
            .modelContainer(for: [Transaction.self, Account.self, Category.self, CategoryGroup.self])
    }
}
