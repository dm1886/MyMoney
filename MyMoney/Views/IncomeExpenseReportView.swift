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
    case last7Days = "Ultimi 7 giorni"
    case last30Days = "Ultimi 30 giorni"
    case last90Days = "Ultimi 90 giorni"
    case thisMonth = "Questo mese"
    case lastMonth = "Mese scorso"
    case thisYear = "Quest'anno"
    case custom = "Personalizzato"

    var icon: String {
        switch self {
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

    @State private var selectedPeriod: TimePeriod = .thisMonth
    @State private var selectedAccounts: Set<UUID> = []
    @State private var showingAccountPicker = false
    @State private var showingCustomDatePicker = false
    @State private var chartType: ChartType = .bar

    // Custom date range
    @State private var customStartDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var customEndDate = Date()

    var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()

        switch selectedPeriod {
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
            return (customStartDate, customEndDate)
        }
    }

    var filteredTransactions: [Transaction] {
        let range = dateRange

        return transactions.filter { transaction in
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
    }

    var totalIncome: Decimal {
        filteredTransactions
            .filter { $0.transactionType == .income }
            .reduce(0) { $0 + $1.amount }
    }

    var totalExpense: Decimal {
        filteredTransactions
            .filter { $0.transactionType == .expense }
            .reduce(0) { $0 + $1.amount }
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

                // Chart Type Toggle
                chartTypeToggle
                    .padding(.horizontal)

                // Chart
                chartView
                    .padding(.horizontal)
                    .padding(.bottom, 20)
            }
        }
        .background(Color(.systemGroupedBackground))
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
                .font(.headline)
                .foregroundStyle(.primary)

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
            }

            // Show date range
            Text(formatDateRange(dateRange))
                .font(.caption)
                .foregroundStyle(.secondary)
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
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if selectedAccounts.isEmpty || selectedAccounts.count == accounts.count {
                        Text("Tutti i conti")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(selectedAccounts.count) conti selezionati")
                            .font(.subheadline)
                            .foregroundStyle(appSettings.accentColor)
                    }
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

    // MARK: - Summary Cards

    private var summaryCards: some View {
        HStack(spacing: 12) {
            // Income Card
            IncomeExpenseSummaryCard(
                title: "Entrate",
                amount: totalIncome,
                color: .green,
                icon: "arrow.down.circle.fill",
                currency: appSettings.preferredCurrencyEnum.rawValue
            )

            // Expense Card
            IncomeExpenseSummaryCard(
                title: "Uscite",
                amount: totalExpense,
                color: .red,
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
                .font(.subheadline.bold())
                .foregroundStyle(chartType == .bar ? .white : appSettings.accentColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(chartType == .bar ? appSettings.accentColor : Color(.secondarySystemGroupedBackground))
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
                .font(.subheadline.bold())
                .foregroundStyle(chartType == .pie ? .white : appSettings.accentColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(chartType == .pie ? appSettings.accentColor : Color(.secondarySystemGroupedBackground))
                )
            }
        }
    }

    // MARK: - Chart View

    @ViewBuilder
    private var chartView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Bilancio: \(formatAmount(netBalance))")
                .font(.title3.bold())
                .foregroundStyle(netBalance >= 0 ? .green : .red)
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
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var barChartView: some View {
        Chart {
            BarMark(
                x: .value("Importo", Double(truncating: totalIncome as NSDecimalNumber)),
                y: .value("Tipo", "Entrate")
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [.green.opacity(0.8), .green],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .annotation(position: .trailing) {
                Text(formatAmount(totalIncome))
                    .font(.caption.bold())
                    .foregroundStyle(.green)
            }

            BarMark(
                x: .value("Importo", Double(truncating: totalExpense as NSDecimalNumber)),
                y: .value("Tipo", "Uscite")
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [.red.opacity(0.8), .red],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .annotation(position: .trailing) {
                Text(formatAmount(totalExpense))
                    .font(.caption.bold())
                    .foregroundStyle(.red)
            }
        }
        .chartXAxis {
            AxisMarks(position: .bottom) { value in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel()
            }
        }
        .frame(height: 200)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: totalIncome)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: totalExpense)
    }

    private var pieChartView: some View {
        VStack(spacing: 20) {
            ZStack {
                Chart {
                    SectorMark(
                        angle: .value("Importo", Double(truncating: totalIncome as NSDecimalNumber)),
                        innerRadius: .ratio(0.618),
                        angularInset: 1.5
                    )
                    .foregroundStyle(.green.gradient)
                    .annotation(position: .overlay) {
                        if totalIncome > 0 {
                            VStack(spacing: 2) {
                                Text(formatPercentage(totalIncome, of: totalIncome + totalExpense))
                                    .font(.title3.bold())
                                    .foregroundStyle(.white)
                                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                            }
                        }
                    }

                    SectorMark(
                        angle: .value("Importo", Double(truncating: totalExpense as NSDecimalNumber)),
                        innerRadius: .ratio(0.618),
                        angularInset: 1.5
                    )
                    .foregroundStyle(.red.gradient)
                    .annotation(position: .overlay) {
                        if totalExpense > 0 {
                            VStack(spacing: 2) {
                                Text(formatPercentage(totalExpense, of: totalIncome + totalExpense))
                                    .font(.title3.bold())
                                    .foregroundStyle(.white)
                                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                            }
                        }
                    }
                }
                .frame(height: 280)
                .chartLegend(.hidden)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: totalIncome)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: totalExpense)

                // Testo al centro
                VStack(spacing: 4) {
                    if totalIncome > 0 && totalExpense > 0 {
                        Text("Totale")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(formatAmount(totalIncome + totalExpense))
                            .font(.headline.bold())
                            .foregroundStyle(.primary)
                    } else if totalIncome > 0 {
                        Text("100%")
                            .font(.title.bold())
                            .foregroundStyle(.green)
                        Text("Entrate")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if totalExpense > 0 {
                        Text("100%")
                            .font(.title.bold())
                            .foregroundStyle(.red)
                        Text("Uscite")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Nessun dato")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Legend con percentuali
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    // Entrate
                    HStack(spacing: 8) {
                        Circle()
                            .fill(.green)
                            .frame(width: 16, height: 16)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text("Entrate")
                                    .font(.subheadline.bold())
                                Text("(\(formatPercentage(totalIncome, of: totalIncome + totalExpense)))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Text(formatAmount(totalIncome))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.green.opacity(0.1))
                    )
                }

                HStack(spacing: 12) {
                    // Uscite
                    HStack(spacing: 8) {
                        Circle()
                            .fill(.red)
                            .frame(width: 16, height: 16)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text("Uscite")
                                    .font(.subheadline.bold())
                                Text("(\(formatPercentage(totalExpense, of: totalIncome + totalExpense)))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Text(formatAmount(totalExpense))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.red.opacity(0.1))
                    )
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func formatDateRange(_ range: (start: Date, end: Date)) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateFormat = "d MMM yyyy"

        return "\(formatter.string(from: range.start)) - \(formatter.string(from: range.end))"
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let amountString = formatter.string(from: amount as NSDecimalNumber) ?? "0.00"
        return "\(appSettings.preferredCurrencyEnum.rawValue) \(amountString)"
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
                    .font(.caption)
                Text(period.rawValue)
                    .font(.subheadline.bold())
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.accentColor : Color(.tertiarySystemGroupedBackground))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Income Expense Summary Card

struct IncomeExpenseSummaryCard: View {
    let title: String
    let amount: Decimal
    let color: Color
    let icon: String
    let currency: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(formatAmount(amount, currency: currency))
                    .font(.title3.bold())
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
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let amountString = formatter.string(from: amount as NSDecimalNumber) ?? "0.00"
        return "\(currency) \(amountString)"
    }
}

// MARK: - Account Filter Sheet

struct AccountFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appSettings) var appSettings

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
                                .foregroundStyle(.primary)

                            Spacer()

                            if tempSelectedAccounts.count == accounts.count {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(appSettings.accentColor)
                            }
                        }
                    }
                } header: {
                    Text("\(tempSelectedAccounts.count) di \(accounts.count) selezionati")
                }

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
                                            .font(.body)
                                            .foregroundStyle(.primary)

                                        Text(formatAmount(account.currentBalance, currency: account.currency.rawValue))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    if tempSelectedAccounts.contains(account.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(appSettings.accentColor)
                                            .font(.title3)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundStyle(.tertiary)
                                            .font(.title3)
                                    }
                                }
                            }
                        }
                    } header: {
                        HStack(spacing: 6) {
                            Image(systemName: section.type.icon)
                                .foregroundStyle(appSettings.accentColor)
                            Text(section.type.rawValue)
                                .foregroundStyle(.primary)
                        }
                        .font(.subheadline.bold())
                        .textCase(nil)
                    }
                }
            }
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
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let amountString = formatter.string(from: amount as NSDecimalNumber) ?? "0.00"
        return "\(currency) \(amountString)"
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
                }
            }
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
