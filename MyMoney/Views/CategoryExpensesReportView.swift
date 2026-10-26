//
//  CategoryExpensesReportView.swift
//  MoneyTracker
//
//  Created on 2026-02-04.
//

import SwiftUI
import SwiftData
import Charts

struct CategoryExpenseData: Identifiable {
    let id = UUID()
    let category: Category
    let amount: Decimal
    let percentage: Double
}

struct CategoryExpensesReportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appSettings) var appSettings
    @Query private var transactions: [Transaction]
    @Query private var accounts: [Account]
    @Query private var allCurrencies: [CurrencyRecord]
    @Query private var categories: [Category]
    
    @State private var selectedPeriod: TimePeriod = .thisMonth
    @State private var selectedAccounts: Set<UUID> = []
    @State private var showingAccountPicker = false
    @State private var showingCustomDatePicker = false
    @State private var chartType: ChartType = .pie
    @State private var isLoading = true
    @State private var cachedCategoryData: [CategoryExpenseData] = []
    
    // Custom date range
    @State private var customStartDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var customEndDate = Date()
    
    var preferredCurrencyRecord: CurrencyRecord? {
        allCurrencies.first { $0.code == appSettings.preferredCurrencyEnum.rawValue }
    }
    
    var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedPeriod {
        case .today:
            let startOfToday = calendar.startOfDay(for: now)
            let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now
            return (startOfToday, endOfToday)
        case .yesterday:
            let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)) ?? now
            let endOfYesterday = calendar.startOfDay(for: now)
            return (startOfYesterday, endOfYesterday)
        case .last7Days:
            let start = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            return (start, now)
        case .last30Days:
            let start = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            return (start, now)
        case .last90Days:
            let start = calendar.date(byAdding: .day, value: -90, to: now) ?? now
            return (start, now)
        case .thisMonth:
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            return (start, now)
        case .lastMonth:
            let start = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            let startOfLastMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: start)) ?? start
            let endOfLastMonth = calendar.date(byAdding: .day, value: -1, to: calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now) ?? now
            return (startOfLastMonth, endOfLastMonth)
        case .thisYear:
            let start = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now
            return (start, now)
        case .custom:
            let startOfDay = calendar.startOfDay(for: customStartDate)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: customEndDate)) ?? customEndDate
            return (startOfDay, endOfDay)
        }
    }
    
    var filteredTransactions: [Transaction] {
        let range = dateRange
        
        return transactions.filter { transaction in
            guard transaction.status == .executed else { return false }
            guard transaction.transactionType == .expense else { return false }
            guard transaction.date >= range.start && transaction.date <= range.end else { return false }
            
            // Se nessun conto è selezionato, mostra tutti
            if selectedAccounts.isEmpty {
                return true
            }
            
            // Altrimenti filtra per conti selezionati
            if let accountId = transaction.account?.id {
                return selectedAccounts.contains(accountId)
            }
            
            return false
        }
    }
    
    var categoryExpenseData: [CategoryExpenseData] {
        return cachedCategoryData
    }
    
    var totalExpenses: Decimal {
        cachedCategoryData.reduce(0) { $0 + $1.amount }
    }
    
    // MARK: - Load Data Async
    
    private func loadDataAsync() {
        isLoading = true
        
        Task { @MainActor in
            // Small delay to show skeleton animation
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            // Compute data
            var categoryTotals: [UUID: Decimal] = [:]
            
            if let preferredCurrency = preferredCurrencyRecord {
                // Con conversione
                for transaction in filteredTransactions {
                    guard let category = transaction.category else { continue }
                    guard let transactionCurrency = transaction.currencyRecord else { continue }
                    
                    let converted = CurrencyService.shared.convert(
                        amount: transaction.amount,
                        from: transactionCurrency,
                        to: preferredCurrency,
                        context: modelContext
                    )
                    
                    categoryTotals[category.id, default: 0] += converted
                }
            } else {
                // Senza conversione
                for transaction in filteredTransactions {
                    guard let category = transaction.category else { continue }
                    categoryTotals[category.id, default: 0] += transaction.amount
                }
            }
            
            let total = categoryTotals.values.reduce(0, +)
            
            let result = categoryTotals.compactMap { categoryId, amount -> CategoryExpenseData? in
                guard let category = categories.first(where: { $0.id == categoryId }) else { return nil }
                let percentage = total > 0 ? Double(truncating: (amount / total * 100) as NSDecimalNumber) : 0
                return CategoryExpenseData(category: category, amount: amount, percentage: percentage)
            }
            .sorted { $0.amount > $1.amount }
            
            // Update UI with animation
            withAnimation(.easeOut(duration: 0.3)) {
                cachedCategoryData = result
                isLoading = false
            }
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
                        
                        // Account Filter
                        accountFilterButton
                            .padding(.horizontal)
                        
                        // Total Card
                        totalCard
                            .padding(.horizontal)
                        
                        // Chart Type Toggle
                        chartTypeToggle
                            .padding(.horizontal)
                        
                        // Chart
                        chartView
                            .padding(.horizontal)
                        
                        if selectedPeriod == .thisMonth || selectedPeriod == .lastMonth {
                            OrbCalendarChart(transactions: filteredTransactions, currency: preferredCurrencyRecord, month: dateRange.start).padding(.horizontal)
                        }
                        // Category List
                        categoryList
                            .padding(.horizontal)
                            .padding(.bottom, 20)
                    }
                }.orbScreen()
                .transition(.opacity)
            }
        }
        .background(Color.orbBackground)
        .navigationTitle("Spese per Categoria")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAccountPicker) {
            AccountFilterSheet(
                accounts: accounts,
                selectedAccounts: $selectedAccounts
            )
        }
        .sheet(isPresented: $showingCustomDatePicker) {
            CustomDateRangeSheet(
                startDate: $customStartDate,
                endDate: $customEndDate,
                onApply: {
                    selectedPeriod = .custom
                    showingCustomDatePicker = false
                    loadDataAsync()
                }
            )
        }
        .onAppear {
            // Inizializza con tutti i conti selezionati
            if selectedAccounts.isEmpty {
                selectedAccounts = Set(accounts.map { $0.id })
            }
            loadDataAsync()
        }
        .onChange(of: selectedPeriod) { _, _ in
            loadDataAsync()
        }
        .onChange(of: selectedAccounts) { _, _ in
            loadDataAsync()
        }
    }
    
    // MARK: - Period Selector
    
    private var periodSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Periodo")
                .font(.orbHeadline)
                .foregroundStyle(Color.orbText)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(TimePeriod.allCases, id: \.self) { period in
                        PeriodButton(
                            period: period,
                            isSelected: selectedPeriod == period,
                            action: {
                                withAnimation(.spring(response: 0.3)) {
                                    if period == .custom {
                                        showingCustomDatePicker = true
                                    } else {
                                        HapticManager.shared.periodChanged()
                                        selectedPeriod = period
                                    }
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 4)
            }.orbScreen()
            
            // Show date range
            Text(formatDateRange(dateRange))
                .font(.orbCaption)
                .foregroundStyle(Color.orbMuted)
                .padding(.leading, 4)
        }
    }
    
    // MARK: - Account Filter Button
    
    private var accountFilterButton: some View {
        Button {
            showingAccountPicker = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Conti")
                        .font(.orbHeadline)
                        .foregroundStyle(Color.orbText)
                    
                    if selectedAccounts.isEmpty || selectedAccounts.count == accounts.count {
                        Text("Tutti i conti")
                            .font(.orbSubheadline)
                            .foregroundStyle(Color.orbMuted)
                    } else {
                        Text("\(selectedAccounts.count) conti selezionati")
                            .font(.orbSubheadline)
                            .foregroundStyle(Color.orbHighlight)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.orbCaption)
                    .foregroundStyle(Color.orbMuted)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.orbCard)
            )
        }
    }
    
    // MARK: - Total Card
    
    private var totalCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.orbTitle2)
                    .foregroundStyle(Color.orbNegative)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Totale Spese")
                        .font(.orbSubheadline)
                        .foregroundStyle(Color.orbMuted)
                    
                    Text(formatAmount(totalExpenses))
                        .font(.orbTitle2.bold())
                        .foregroundStyle(Color.orbText)
                }
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.orbCard)
            )
        }
    }
    
    // MARK: - Chart Type Toggle
    
    private var chartTypeToggle: some View {
        HStack(spacing: 12) {
            Button {
                HapticManager.shared.chartTypeChanged()
                withAnimation(.spring(response: 0.3)) {
                    chartType = .pie
                }
            } label: {
                HStack {
                    Image(systemName: "chart.pie.fill")
                    Text("Torta")
                }
                .font(.orbSubheadline.bold())
                .foregroundStyle(chartType == .pie ? Color.orbOnAccent : Color.orbAccent)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(chartType == .pie ? Color.orbAccent : Color.orbCard)
                )
            }
            
            Button {
                HapticManager.shared.chartTypeChanged()
                withAnimation(.spring(response: 0.3)) {
                    chartType = .bar
                }
            } label: {
                HStack {
                    Image(systemName: "chart.bar.fill")
                    Text("Barre")
                }
                .font(.orbSubheadline.bold())
                .foregroundStyle(chartType == .bar ? Color.orbOnAccent : Color.orbAccent)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(chartType == .bar ? Color.orbAccent : Color.orbCard)
                )
            }
        }
    }
    
    // MARK: - Chart View
    
    @ViewBuilder
    private var chartView: some View {
        if categoryExpenseData.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "chart.pie")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.orbMuted)
                
                Text("Nessuna spesa nel periodo selezionato")
                    .font(.orbSubheadline)
                    .foregroundStyle(Color.orbMuted)
            }
            .frame(height: 280)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.orbCard)
            )
        } else {
            VStack(alignment: .leading, spacing: 16) {
                if chartType == .pie {
                    pieChartView
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))
                } else {
                    barChartView
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.orbCard)
            )
        }
    }
    
    private var pieChartView: some View {
        OrbDonutChart(slices: categoryExpenseData.map { OrbCategorySlice(id: $0.category.id.uuidString, name: $0.category.name, amount: NSDecimalNumber(decimal: $0.amount).doubleValue, color: $0.category.color) }, symbol: preferredCurrencyRecord?.displaySymbol ?? "€")
    }
    
    private var barChartView: some View {
        VStack(spacing: 14) {
            OrbRankedBars(slices: categoryExpenseData.map { OrbCategorySlice(id: $0.category.id.uuidString, name: $0.category.name, amount: NSDecimalNumber(decimal: $0.amount).doubleValue, color: $0.category.color) }, symbol: preferredCurrencyRecord?.displaySymbol ?? "€")
            OrbChartTable(title: "Spese per categoria", points: categoryExpenseData.map { OrbChartPoint(label: $0.category.name, amount: NSDecimalNumber(decimal: $0.amount).doubleValue) }, symbol: preferredCurrencyRecord?.displaySymbol ?? "€")
        }
    }
    
    // MARK: - Category List
    
    private var categoryList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dettaglio per Categoria")
                .font(.orbHeadline)
                .foregroundStyle(Color.orbText)
                .padding(.horizontal, 4)
            
            if categoryExpenseData.isEmpty {
                Text("Nessuna categoria con spese")
                    .font(.orbSubheadline)
                    .foregroundStyle(Color.orbMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                VStack(spacing: 8) {
                    ForEach(categoryExpenseData) { data in
                        CategoryExpenseRow(data: data, total: totalExpenses)
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.numberStyle = .currency
        formatter.currencyCode = appSettings.preferredCurrencyEnum.rawValue
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }
    
    private func formatDateRange(_ range: (start: Date, end: Date)) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        
        if Calendar.current.isDate(range.start, inSameDayAs: range.end) {
            return formatter.string(from: range.start)
        } else {
            return "\(formatter.string(from: range.start)) - \(formatter.string(from: range.end))"
        }
    }
}

// MARK: - Category Expense Row

struct CategoryExpenseRow: View {
    let data: CategoryExpenseData
    let total: Decimal
    @Environment(\.appSettings) var appSettings
    
    var body: some View {
        HStack(spacing: 12) {
            // Category Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill((Color(hex: data.category.colorHex) ?? Color.orbMuted).opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: data.category.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(Color(hex: data.category.colorHex) ?? Color.orbMuted)
            }
            
            // Category Name
            VStack(alignment: .leading, spacing: 2) {
                Text(data.category.name)
                    .font(.orbSubheadline.bold())
                    .foregroundStyle(Color.orbText)
                
                Text("\(String(format: "%.1f", locale: Locale(identifier: "it_IT"), data.percentage))%")
                    .font(.orbCaption)
                    .foregroundStyle(Color.orbMuted)
            }
            
            Spacer()
            
            // Amount
            Text(formatAmount(data.amount))
                .font(.orbSubheadline.bold())
                .foregroundStyle(Color.orbText)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orbCard)
        )
    }
    
    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.numberStyle = .currency
        formatter.currencyCode = appSettings.preferredCurrencyEnum.rawValue
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }
}

#Preview {
    NavigationStack {
        CategoryExpensesReportView()
            .environment(\.appSettings, AppSettings.shared)
            .modelContainer(for: [Transaction.self, Account.self, Category.self])
    }
}
