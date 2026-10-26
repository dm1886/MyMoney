//
//  IncomeExpenseReportView.swift
//  MoneyTracker
//
//  Created on 2026-01-26.
//

import SwiftUI
import SwiftData
import Charts

// MARK: - Period Selection
enum TimePeriod: String, CaseIterable {
    case today = "Oggi"
    case yesterday = "Ieri"
    case last7Days = "Ultimi 7 giorni"
    case last30Days = "Ultimi 30 giorni"
    case last90Days = "Ultimi 90 giorni"
    case thisMonth = "Questo mese"
    case lastMonth = "Mese scorso"
    case thisYear = "Quest'anno"
    case custom = "Personalizzato"

    var icon: String {
        switch self {
        case .today: return "calendar.badge.checkmark"
        case .yesterday: return "calendar.badge.minus"
        case .last7Days: return "7.circle.fill"
        case .last30Days: return "30.circle.fill"
        case .last90Days: return "90.circle.fill"
        case .thisMonth: return "calendar.circle.fill"
        case .lastMonth: return "calendar.badge.clock"
        case .thisYear: return "calendar"
        case .custom: return "slider.horizontal.3"
        }
    }
}

enum ChartType {
    case bar
    case pie
}

struct IncomeExpenseReportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appSettings) var appSettings
    @Query private var transactions: [Transaction]
    @Query private var accounts: [Account]
    @Query private var allCurrencies: [CurrencyRecord]

    @State private var selectedPeriod: TimePeriod = .thisMonth
    @State private var selectedAccounts: Set<UUID> = []
    @State private var showingAccountPicker = false
    @State private var showingCustomDatePicker = false
    @State private var chartType: ChartType = .bar

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
            // CRITICAL FIX: Usa startOfDay per la data di inizio e endOfDay per la data di fine
            // Questo permette di selezionare "da oggi a oggi" e vedere tutte le transazioni del giorno
            let startOfDay = calendar.startOfDay(for: customStartDate)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: customEndDate)) ?? customEndDate
            return (startOfDay, endOfDay)
        }
    }

    var filteredTransactions: [Transaction] {
        let range = dateRange

        // DEBUG: Analizza TUTTE le transazioni nel range (prima dei filtri)
        let inRange = transactions.filter { $0.date >= range.start && $0.date <= range.end }
        print("📊 IncomeExpenseReport: Periodo \(selectedPeriod.rawValue)")
        print("   Range: \(range.start) → \(range.end)")
        print("   Totale transazioni DB: \(transactions.count)")
        print("   Transazioni nel range (senza filtri): \(inRange.count)")

        // Analisi per tipo
        let allIncome = inRange.filter { $0.transactionType == .income }
        let allExpense = inRange.filter { $0.transactionType == .expense }
        let allTransfer = inRange.filter { $0.transactionType == .transfer }
        let allAdjustment = inRange.filter { $0.transactionType == .adjustment }
        print("   → Tutte nel range: Entrate=\(allIncome.count), Uscite=\(allExpense.count), Trasferimenti=\(allTransfer.count), Aggiustamenti=\(allAdjustment.count)")

        // Calcola i totali per tipo
        let totalIncomeAmount = allIncome.reduce(Decimal(0)) { $0 + $1.amount }
        let totalExpenseAmount = allExpense.reduce(Decimal(0)) { $0 + $1.amount }
        let totalTransferAmount = allTransfer.reduce(Decimal(0)) { $0 + $1.amount }
        let totalAdjustmentAmount = allAdjustment.reduce(Decimal(0)) { $0 + $1.amount }
        print("   → Totali per tipo: Entrate=\(totalIncomeAmount), Uscite=\(totalExpenseAmount), Trasferimenti=\(totalTransferAmount), Aggiustamenti=\(totalAdjustmentAmount)")
        print("   → SOMMA TOTALE DI TUTTO (incluso trasferimenti): \(totalIncomeAmount + totalExpenseAmount + totalTransferAmount + totalAdjustmentAmount)")

        // Analisi per status
        let executed = inRange.filter { $0.status == .executed }
        let pending = inRange.filter { $0.status == .pending }
        print("   → Per status: Eseguite=\(executed.count), In attesa=\(pending.count)")

        // Ora applica i filtri standard
        let filtered = transactions.filter { transaction in
            guard transaction.status == .executed else { return false }
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

        print("   Transazioni FILTRATE (executed + conti selezionati): \(filtered.count)")
        print("   Conti selezionati: \(selectedAccounts.count) / \(accounts.count)")

        let incomeCount = filtered.filter { $0.transactionType == .income }.count
        let expenseCount = filtered.filter { $0.transactionType == .expense }.count
        print("   → Filtrate: Entrate=\(incomeCount), Uscite=\(expenseCount)")

        // DETAILED LOGGING: Mostra ogni singola transazione contata
        print("   📋 DETTAGLIO TRANSAZIONI FILTRATE:")
        for transaction in filtered {
            let amount = transaction.amount
            let category = transaction.category?.name ?? "N/A"
            let account = transaction.account?.name ?? "N/A"
            let type = transaction.transactionType.rawValue
            let date = transaction.date
            print("      • \(type) | \(amount) | \(category) | \(account) | \(date)")
        }

        return filtered
    }

    var totalIncome: Decimal {
        guard let preferredCurrency = preferredCurrencyRecord else {
            let total = filteredTransactions
                .filter { $0.transactionType == .income }
                .reduce(0) { $0 + $1.amount }
            print("   💰 TOTAL INCOME CALCOLATO (no conversion): \(total)")
            return total
        }

        var total: Decimal = 0

        for transaction in filteredTransactions where transaction.transactionType == .income {
            guard let transactionCurrency = transaction.currencyRecord else { continue }

            let converted = CurrencyService.shared.convert(
                amount: transaction.amount,
                from: transactionCurrency,
                to: preferredCurrency,
                context: modelContext
            )

            total += converted
        }

        print("   💰 TOTAL INCOME CALCOLATO (with conversion): \(total)")
        return total
    }

    var totalExpense: Decimal {
        guard let preferredCurrency = preferredCurrencyRecord else {
            let total = filteredTransactions
                .filter { $0.transactionType == .expense }
                .reduce(0) { $0 + $1.amount }
            print("   💸 TOTAL EXPENSE CALCOLATO (no conversion): \(total)")
            return total
        }

        var total: Decimal = 0

        for transaction in filteredTransactions where transaction.transactionType == .expense {
            guard let transactionCurrency = transaction.currencyRecord else { continue }

            let converted = CurrencyService.shared.convert(
                amount: transaction.amount,
                from: transactionCurrency,
                to: preferredCurrency,
                context: modelContext
            )

            total += converted
        }

        print("   💸 TOTAL EXPENSE CALCOLATO (with conversion): \(total)")
        return total
    }

    var netBalance: Decimal {
        totalIncome - totalExpense
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Period Selector
                periodSelector
                    .padding(.horizontal)
                    .padding(.top, 16)

                // Account Filter
                accountFilterButton
                    .padding(.horizontal)

                // Summary Cards
                summaryCards
                    .padding(.horizontal)

                if selectedPeriod == .thisMonth {
                    OrbCard { OrbCumulativeChart(transactions: transactions.filter { selectedAccounts.isEmpty || selectedAccounts.contains($0.account?.id ?? UUID()) }, currency: preferredCurrencyRecord) }.padding(.horizontal)
                }
                // Chart Type Toggle
                chartTypeToggle
                    .padding(.horizontal)

                // Chart
                chartView
                    .padding(.horizontal)
                    .padding(.bottom, 20)
            }
        }.orbScreen()
        .background(Color.orbBackground)
        .navigationTitle("Entrate e Uscite")
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
                }
            )
        }
        .onAppear {
            // Inizializza con tutti i conti selezionati
            if selectedAccounts.isEmpty {
                selectedAccounts = Set(accounts.map { $0.id })
            }
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

    // MARK: - Summary Cards

    private var summaryCards: some View {
        HStack(spacing: 12) {
            // Income Card
            IncomeExpenseSummaryCard(
                title: "Entrate",
                amount: totalIncome,
                color: Color.orbPositive,
                icon: "arrow.down.circle.fill",
                currency: appSettings.preferredCurrencyEnum.rawValue
            )

            // Expense Card
            IncomeExpenseSummaryCard(
                title: "Uscite",
                amount: totalExpense,
                color: Color.orbNegative,
                icon: "arrow.up.circle.fill",
                currency: appSettings.preferredCurrencyEnum.rawValue
            )
        }
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Chart Type Toggle

    private var chartTypeToggle: some View {
        HStack(spacing: 12) {
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
        }
    }

    // MARK: - Chart View

    @ViewBuilder
    private var chartView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Bilancio: \(formatAmount(netBalance))")
                .font(.orbTitle3.bold())
                .foregroundStyle(netBalance >= 0 ? Color.orbPositive : Color.orbNegative)
                .padding(.horizontal, 4)

            if chartType == .bar {
                barChartView
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
            } else {
                pieChartView
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

    private var barChartView: some View {
        OrbColumnsChart(points: reportColumns, symbol: preferredCurrencyRecord?.displaySymbol ?? "€", paired: true, title: "Entrate e uscite")
    }
    private var reportColumns: [OrbChartPoint] {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: dateRange.start, to: dateRange.end).day ?? 0
        let component: Calendar.Component = days > 60 ? .month : .day
        let groups = Dictionary(grouping: filteredTransactions) { calendar.dateInterval(of: component, for: $0.date)!.start }
        return groups.keys.sorted().map { date in
            var income: Decimal = 0, expense: Decimal = 0
            for t in groups[date] ?? [] {
                let amount: Decimal
                if let to = preferredCurrencyRecord {
                    guard let from = t.currencyRecord else { continue }
                    amount = CurrencyService.shared.convert(amount: t.amount, from: from, to: to, context: modelContext)
                } else { amount = t.amount }
                if t.transactionType == .income { income += amount }
                if t.transactionType == .expense { expense += amount }
            }
            return OrbChartPoint(label: date.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "it_IT"))), amount: NSDecimalNumber(decimal: income).doubleValue, second: NSDecimalNumber(decimal: expense).doubleValue, date: date)
        }
    }

    private var pieChartView: some View {
        OrbDonutChart(slices: [
            OrbCategorySlice(id: "income", name: "↑ Entrate", amount: NSDecimalNumber(decimal: totalIncome).doubleValue, color: .chartIncome),
            OrbCategorySlice(id: "expense", name: "↓ Uscite", amount: NSDecimalNumber(decimal: totalExpense).doubleValue, color: .chartExpense)
        ], symbol: preferredCurrencyRecord?.displaySymbol ?? "€")
    }

    // MARK: - Helper Methods

    private func formatDateRange(_ range: (start: Date, end: Date)) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateFormat = "d MMM yyyy"

        return "\(formatter.string(from: range.start)) - \(formatter.string(from: range.end))"
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let symbol = preferredCurrencyRecord?.displaySymbol ?? "$"

        return "\(symbol) \(FormatterCache.formatCurrencyFixed(amount))"
    }

    private func formatPercentage(_ amount: Decimal, of total: Decimal) -> String {
        guard total > 0 else { return "0%" }

        // Converti a Double per il calcolo della percentuale
        let amountDouble = (amount as NSDecimalNumber).doubleValue
        let totalDouble = (total as NSDecimalNumber).doubleValue

        let percentage = (amountDouble / totalDouble) * 100

        // Arrotonda a 1 decimale se necessario
        if percentage < 1 && percentage > 0 {
            return String(format: "%.1f%%", percentage)
        } else {
            return String(format: "%.0f%%", percentage)
        }
    }
}

// MARK: - Period Button

struct PeriodButton: View {
    let period: TimePeriod
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: period.icon)
                    .font(.orbCaption)
                Text(period.rawValue)
                    .font(.orbSubheadline.bold())
            }
            .foregroundStyle(isSelected ? Color.orbOnAccent : Color.orbText)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.accentColor : Color.orbCard2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Income Expense Summary Card

struct IncomeExpenseSummaryCard: View {
    @Environment(\.appSettings) var appSettings
    @Query private var allCurrencies: [CurrencyRecord]

    let title: String
    let amount: Decimal
    let color: Color
    let icon: String
    let currency: String

    var preferredCurrencyRecord: CurrencyRecord? {
        allCurrencies.first { $0.code == appSettings.preferredCurrencyEnum.rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.orbTitle3)
                    .foregroundStyle(color)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.orbSubheadline)
                    .foregroundStyle(Color.orbMuted)

                Text(formatAmount(amount, currency: currency))
                    .font(.orbTitle3.bold())
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(color.opacity(0.3), lineWidth: 1)
        )
    }

    private func formatAmount(_ amount: Decimal, currency: String) -> String {
        let symbol = preferredCurrencyRecord?.displaySymbol ?? "$"

        return "\(symbol) \(FormatterCache.formatCurrencyFixed(amount))"
    }
}

// MARK: - Account Filter Sheet

struct AccountFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appSettings) var appSettings
    @Query private var allCurrencies: [CurrencyRecord]

    let accounts: [Account]
    @Binding var selectedAccounts: Set<UUID>

    @State private var tempSelectedAccounts: Set<UUID> = []

    // Raggruppa i conti per tipo
    var accountsByType: [(type: AccountType, accounts: [Account])] {
        let grouped = Dictionary(grouping: accounts) { $0.accountType }
        return AccountType.allCases.compactMap { type in
            guard let accountsForType = grouped[type], !accountsForType.isEmpty else {
                return nil
            }
            return (type: type, accounts: accountsForType.sorted { $0.name < $1.name })
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        if tempSelectedAccounts.count == accounts.count {
                            tempSelectedAccounts.removeAll()
                        } else {
                            tempSelectedAccounts = Set(accounts.map { $0.id })
                        }
                    } label: {
                        HStack {
                            Text("Tutti i conti")
                                .foregroundStyle(Color.orbText)

                            Spacer()

                            if tempSelectedAccounts.count == accounts.count {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.orbHighlight)
                            }
                        }
                    }
                } header: {
                    Text("\(tempSelectedAccounts.count) di \(accounts.count) selezionati")
                }.listRowBackground(Color.orbCard)

                // Sezioni per tipo di conto
                ForEach(accountsByType, id: \.type) { section in
                    Section {
                        ForEach(section.accounts) { account in
                            Button {
                                HapticManager.shared.itemSelected()
                                if tempSelectedAccounts.contains(account.id) {
                                    tempSelectedAccounts.remove(account.id)
                                } else {
                                    tempSelectedAccounts.insert(account.id)
                                }
                            } label: {
                                HStack {
                                    // Icona del conto
                                    ZStack {
                                        Circle()
                                            .fill(account.color.opacity(0.15))
                                            .frame(width: 40, height: 40)

                                        Image(systemName: account.icon)
                                            .foregroundStyle(account.color)
                                            .font(.system(size: 16))
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(account.name)
                                            .font(.orbBody)
                                            .foregroundStyle(Color.orbText)

                                        Text(formatAmount(account.currentBalance, currency: account.currency.rawValue))
                                            .font(.orbCaption)
                                            .foregroundStyle(Color.orbMuted)
                                    }

                                    Spacer()

                                    if tempSelectedAccounts.contains(account.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color.orbHighlight)
                                            .font(.orbTitle3)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundStyle(Color.orbMuted)
                                            .font(.orbTitle3)
                                    }
                                }
                            }
                        }
                    } header: {
                        HStack(spacing: 6) {
                            Image(systemName: section.type.icon)
                                .foregroundStyle(Color.orbHighlight)
                            Text(section.type.rawValue)
                                .foregroundStyle(Color.orbText)
                        }
                        .font(.orbSubheadline.bold())
                        .textCase(nil)
                    }.listRowBackground(Color.orbCard)
                }
            }.orbScreen()
            .navigationTitle("Seleziona Conti")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annulla") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Applica") {
                        HapticManager.shared.filterApplied()
                        selectedAccounts = tempSelectedAccounts
                        dismiss()
                    }
                    .bold()
                    .disabled(tempSelectedAccounts.isEmpty)
                }
            }
            .onAppear {
                tempSelectedAccounts = selectedAccounts
            }
        }
    }

    private func formatAmount(_ amount: Decimal, currency: String) -> String {
        let currencyRecord = allCurrencies.first { $0.code == currency }
        let symbol = currencyRecord?.displaySymbol ?? (currency == "USD" ? "$" : currency)

        return "\(symbol) \(FormatterCache.formatCurrencyFixed(amount))"
    }
}

// MARK: - Custom Date Range Sheet

struct CustomDateRangeSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var startDate: Date
    @Binding var endDate: Date
    let onApply: () -> Void

    @State private var tempStartDate: Date = Date()
    @State private var tempEndDate: Date = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(
                        "Data Inizio",
                        selection: $tempStartDate,
                        displayedComponents: [.date]
                    )

                    DatePicker(
                        "Data Fine",
                        selection: $tempEndDate,
                        in: tempStartDate...,
                        displayedComponents: [.date]
                    )
                } header: {
                    Text("Seleziona periodo personalizzato")
                } footer: {
                    Text("La data di fine non può essere precedente alla data di inizio")
                }.listRowBackground(Color.orbCard)
            }.orbScreen()
            .navigationTitle("Periodo Personalizzato")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annulla") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Applica") {
                        HapticManager.shared.periodChanged()
                        startDate = tempStartDate
                        endDate = tempEndDate
                        onApply()
                    }
                    .bold()
                }
            }
            .onAppear {
                tempStartDate = startDate
                tempEndDate = endDate
            }
        }
    }
}

#Preview {
    NavigationStack {
        IncomeExpenseReportView()
            .environment(\.appSettings, AppSettings.shared)
            .modelContainer(for: [Transaction.self, Account.self])
    }
}
