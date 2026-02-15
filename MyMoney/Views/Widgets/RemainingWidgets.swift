//
//  RemainingWidgets.swift
//  MoneyTracker
//
//  Created on 2026-01-27.
//

import SwiftUI
import SwiftData
import Charts

// MARK: - Net Worth Period Selection
enum NetWorthPeriod: String, CaseIterable {
    case threeMonths = "3 Mesi"
    case sixMonths = "6 Mesi"
    case year = "Anno"
}

// MARK: - Net Worth Trend Widget
struct NetWorthTrendWidget: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appSettings) var appSettings

    // PERFORMANCE: Accept data as parameters instead of @Query
    let accounts: [Account]
    let allCurrencies: [CurrencyRecord]

    @State private var selectedPeriod: NetWorthPeriod = .sixMonths

    var preferredCurrencyRecord: CurrencyRecord? {
        allCurrencies.first { $0.code == appSettings.preferredCurrencyEnum.rawValue }
    }

    var monthlyNetWorth: [(month: String, netWorth: Decimal)] {
        guard let preferredCurrency = preferredCurrencyRecord else { return [] }

        let calendar = Calendar.current
        let now = Date()
        var result: [(month: String, netWorth: Decimal)] = []

        let monthCount: Int
        switch selectedPeriod {
        case .threeMonths:
            monthCount = 3
        case .sixMonths:
            monthCount = 6
        case .year:
            monthCount = 12
        }

        for monthOffset in (0..<monthCount).reversed() {
            guard let monthDate = calendar.date(byAdding: .month, value: -monthOffset, to: now) else { continue }

            var totalNetWorth: Decimal = 0

            for account in accounts {
                guard let accountCurrency = account.currencyRecord else { continue }
                // Use pre-calculated currentBalance instead of recalculating
                let converted = CurrencyService.shared.convert(
                    amount: account.currentBalance,
                    from: accountCurrency,
                    to: preferredCurrency,
                    context: modelContext
                )
                totalNetWorth += converted
            }

            let formatter = DateFormatter()
            formatter.dateFormat = "MMM"
            formatter.locale = Locale(identifier: "it_IT")

            result.append((month: formatter.string(from: monthDate), netWorth: totalNetWorth))
        }

        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Andamento Patrimonio")
                    .font(.headline.bold())
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Spacer()
            }

            // Period Selector
            Menu {
                ForEach(NetWorthPeriod.allCases, id: \.self) { period in
                    Button {
                        selectedPeriod = period
                    } label: {
                        HStack {
                            Text(period.rawValue)
                            if selectedPeriod == period {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(selectedPeriod.rawValue)
                        .font(.caption)
                        .foregroundStyle(.blue)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.blue.opacity(0.1))
                )
            }

            if monthlyNetWorth.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)

                    Text("Nessun dato disponibile")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                Chart {
                    ForEach(monthlyNetWorth, id: \.month) { data in
                        LineMark(
                            x: .value("Month", data.month),
                            y: .value("Net Worth", Double(truncating: data.netWorth as NSDecimalNumber))
                        )
                        .foregroundStyle(.blue.gradient)
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Month", data.month),
                            y: .value("Net Worth", Double(truncating: data.netWorth as NSDecimalNumber))
                        )
                        .foregroundStyle(.blue.opacity(0.1).gradient)
                        .interpolationMethod(.catmullRom)
                    }
                }
                .frame(height: 180)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .drawingGroup() // Optimize rendering performance
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        )
    }
}

// MARK: - Savings Rate Period Selection
enum SavingsPeriod: String, CaseIterable {
    case thisMonth = "Questo Mese"
    case lastMonth = "Mese Scorso"
    case threeMonths = "3 Mesi"
    case sixMonths = "6 Mesi"
    case year = "Anno"
}

// MARK: - Savings Rate & Daily Average Combined Widget
struct SavingsRateWidget: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appSettings) var appSettings

    // PERFORMANCE: Accept data as parameters instead of @Query
    let transactions: [Transaction]
    let allCurrencies: [CurrencyRecord]

    @State private var selectedPeriod: SavingsPeriod = .thisMonth

    var preferredCurrencyRecord: CurrencyRecord? {
        allCurrencies.first { $0.code == appSettings.preferredCurrencyEnum.rawValue }
    }

    var monthlyStats: (savingsRate: Double, dailyAverage: Decimal, income: Decimal, expenses: Decimal) {
        guard let preferredCurrency = preferredCurrencyRecord else { return (0, 0, 0, 0) }

        let calendar = Calendar.current
        let now = Date()

        // Calculate date range based on selected period
        let (startDate, endDate): (Date, Date)

        switch selectedPeriod {
        case .thisMonth:
            guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else { return (0, 0, 0, 0) }
            startDate = startOfMonth
            endDate = now
        case .lastMonth:
            guard let startOfThisMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
                  let startOfLastMonth = calendar.date(byAdding: .month, value: -1, to: startOfThisMonth) else { return (0, 0, 0, 0) }
            startDate = startOfLastMonth
            endDate = calendar.date(byAdding: .day, value: -1, to: startOfThisMonth) ?? now
        case .threeMonths:
            guard let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now) else { return (0, 0, 0, 0) }
            startDate = threeMonthsAgo
            endDate = now
        case .sixMonths:
            guard let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: now) else { return (0, 0, 0, 0) }
            startDate = sixMonthsAgo
            endDate = now
        case .year:
            guard let oneYearAgo = calendar.date(byAdding: .year, value: -1, to: now) else { return (0, 0, 0, 0) }
            startDate = oneYearAgo
            endDate = now
        }

        let tracker = DeletedTransactionTracker.shared
        let monthTransactions = transactions.filter { transaction in
            guard !tracker.isDeleted(transaction.id) else { return false }
            guard transaction.modelContext != nil else { return false }
            return transaction.date >= startDate &&
                   transaction.date <= endDate &&
                   transaction.status == .executed
        }

        var income: Decimal = 0
        var expenses: Decimal = 0

        for transaction in monthTransactions {
            guard let transactionCurrency = transaction.currencyRecord else { continue }

            let converted = CurrencyService.shared.convert(
                amount: transaction.amount,
                from: transactionCurrency,
                to: preferredCurrency,
                context: modelContext
            )

            if transaction.transactionType == .income {
                income += converted
            } else if transaction.transactionType == .expense {
                expenses += converted
            }
        }

        // Calculate savings rate
        let savingsRate: Double
        if income > 0 {
            let savings = income - expenses
            savingsRate = Double(truncating: savings as NSDecimalNumber) / Double(truncating: income as NSDecimalNumber) * 100
        } else {
            savingsRate = 0
        }

        // Calculate daily average based on period length
        let daysDifference = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 1
        let numberOfDays = max(daysDifference, 1)
        let dailyAverage = expenses / Decimal(numberOfDays)

        return (savingsRate, dailyAverage, income, expenses)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.mint, .green],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Risparmio & Spesa Media")
                    .font(.headline.bold())
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.mint, .green],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Spacer()
            }

            // Period Selector
            Menu {
                ForEach(SavingsPeriod.allCases, id: \.self) { period in
                    Button {
                        selectedPeriod = period
                    } label: {
                        HStack {
                            Text(period.rawValue)
                            if selectedPeriod == period {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(selectedPeriod.rawValue)
                        .font(.caption)
                        .foregroundStyle(.blue)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.blue.opacity(0.1))
                )
            }

            // Savings Rate & Daily Average Side by Side
            HStack(spacing: 12) {
                // Savings Rate Section
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(Int(monthlyStats.savingsRate))%")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(monthlyStats.savingsRate >= 20 ? .green : monthlyStats.savingsRate >= 10 ? .orange : .red)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text("Risparmio")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    Text("(Entrate - Uscite) / Entrate")
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(monthlyStats.savingsRate >= 20 ? Color.green.opacity(0.1) : monthlyStats.savingsRate >= 10 ? Color.orange.opacity(0.1) : Color.red.opacity(0.1))
                )

                // Daily Average Section
                VStack(alignment: .leading, spacing: 6) {
                    Text(formatAmount(monthlyStats.dailyAverage))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    Text("al giorno")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    Text("Spesa media del mese")
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: .rect(cornerRadius: 16))
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let symbol = preferredCurrencyRecord?.displaySymbol ?? "$"
        let flag = preferredCurrencyRecord?.flagEmoji ?? ""
        return "\(symbol)\(FormatterCache.formatCurrency(amount)) \(flag)"
    }
}

// MARK: - Daily Average Widget (Legacy - kept for backwards compatibility)
struct DailyAverageWidget: View {
    // PERFORMANCE: Accept data as parameters to pass to SavingsRateWidget
    let transactions: [Transaction]
    let allCurrencies: [CurrencyRecord]

    var body: some View {
        SavingsRateWidget(transactions: transactions, allCurrencies: allCurrencies)
    }
}

// MARK: - Monthly Comparison Widget
struct MonthlyComparisonWidget: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appSettings) var appSettings

    // PERFORMANCE: Accept data as parameters instead of @Query
    let transactions: [Transaction]
    let allCurrencies: [CurrencyRecord]

    var preferredCurrencyRecord: CurrencyRecord? {
        allCurrencies.first { $0.code == appSettings.preferredCurrencyEnum.rawValue }
    }

    var comparison: (thisMonth: Decimal, lastMonth: Decimal, change: Double, isIncrease: Bool) {
        guard let preferredCurrency = preferredCurrencyRecord else {
            return (0, 0, 0, false)
        }

        let calendar = Calendar.current
        let now = Date()

        // This month
        guard let startOfThisMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
            return (0, 0, 0, false)
        }

        // Last month
        guard let startOfLastMonth = calendar.date(byAdding: .month, value: -1, to: startOfThisMonth),
              let endOfLastMonth = calendar.date(byAdding: .day, value: -1, to: startOfThisMonth) else {
            return (0, 0, 0, false)
        }

        let tracker = DeletedTransactionTracker.shared

        // Calculate this month expenses
        let thisMonthTransactions = transactions.filter { transaction in
            guard !tracker.isDeleted(transaction.id) else { return false }
            guard transaction.modelContext != nil else { return false }
            return transaction.date >= startOfThisMonth &&
                   transaction.date <= now &&
                   transaction.transactionType == .expense &&
                   transaction.status == .executed
        }

        var thisMonthTotal: Decimal = 0
        for transaction in thisMonthTransactions {
            guard let transactionCurrency = transaction.currencyRecord else { continue }
            let converted = CurrencyService.shared.convert(
                amount: transaction.amount,
                from: transactionCurrency,
                to: preferredCurrency,
                context: modelContext
            )
            thisMonthTotal += converted
        }

        // Calculate last month expenses
        let lastMonthTransactions = transactions.filter { transaction in
            guard !tracker.isDeleted(transaction.id) else { return false }
            guard transaction.modelContext != nil else { return false }
            return transaction.date >= startOfLastMonth &&
                   transaction.date <= endOfLastMonth &&
                   transaction.transactionType == .expense &&
                   transaction.status == .executed
        }

        var lastMonthTotal: Decimal = 0
        for transaction in lastMonthTransactions {
            guard let transactionCurrency = transaction.currencyRecord else { continue }
            let converted = CurrencyService.shared.convert(
                amount: transaction.amount,
                from: transactionCurrency,
                to: preferredCurrency,
                context: modelContext
            )
            lastMonthTotal += converted
        }

        let change: Double
        let isIncrease: Bool

        if lastMonthTotal > 0 {
            let difference = thisMonthTotal - lastMonthTotal
            change = abs(Double(truncating: difference as NSDecimalNumber) / Double(truncating: lastMonthTotal as NSDecimalNumber) * 100)
            isIncrease = difference > 0
        } else {
            change = 0
            isIncrease = false
        }

        return (thisMonthTotal, lastMonthTotal, change, isIncrease)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.left.arrow.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.indigo, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Confronto Mensile")
                    .font(.headline.bold())
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.indigo, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Spacer()
            }

            Text("Confronta le spese di questo mese con quelle del mese precedente")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 4)

            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Questo Mese")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(formatAmount(comparison.thisMonth))
                            .font(.title3.bold())
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(comparison.isIncrease ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mese Scorso")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(formatAmount(comparison.lastMonth))
                            .font(.title3.bold())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Divider()

                HStack {
                    Image(systemName: comparison.isIncrease ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .foregroundStyle(comparison.isIncrease ? .red : .green)

                    Text("\(Int(comparison.change))%")
                        .font(.headline.bold())
                        .foregroundStyle(comparison.isIncrease ? .red : .green)

                    Text(comparison.isIncrease ? "in più rispetto al mese scorso" : "in meno rispetto al mese scorso")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        )
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        formatter.groupingSeparator = "."
        formatter.decimalSeparator = ","
        let amountString = formatter.string(from: amount as NSDecimalNumber) ?? "0"
        let symbol = preferredCurrencyRecord?.displaySymbol ?? "$"
        let flag = preferredCurrencyRecord?.flagEmoji ?? ""
        return "\(symbol)\(amountString) \(flag)"
    }
}

// MARK: - Account Balances Widget
struct AccountBalancesWidget: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appSettings) var appSettings

    // PERFORMANCE: Accept data as parameters instead of @Query
    let accounts: [Account]
    let allCurrencies: [CurrencyRecord]

    var preferredCurrencyRecord: CurrencyRecord? {
        allCurrencies.first { $0.code == appSettings.preferredCurrencyEnum.rawValue }
    }

    // Raggruppa conti per tipologia
    var accountsByType: [(type: AccountType, accounts: [Account])] {
        let grouped = Dictionary(grouping: accounts, by: { $0.accountType })
        return AccountType.allCases.compactMap { type in
            guard let accountsForType = grouped[type], !accountsForType.isEmpty else { return nil }
            let sorted = accountsForType.sorted { $0.currentBalance > $1.currentBalance }
            return (type: type, accounts: sorted)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "creditcard.fill")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.teal, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Saldi Conti")
                    .font(.headline.bold())
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.teal, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Spacer()
            }

            if accounts.isEmpty {
                Text("Nessun conto")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 16) {
                    ForEach(accountsByType, id: \.type) { typeGroup in
                        VStack(alignment: .leading, spacing: 8) {
                            // Header tipologia
                            HStack(spacing: 6) {
                                Image(systemName: typeGroup.type.icon)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(typeGroup.type.rawValue)
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(.secondarySystemGroupedBackground))
                            )

                            // Conti della tipologia
                            VStack(spacing: 8) {
                                ForEach(typeGroup.accounts) { account in
                                    HStack {
                                        ZStack {
                                            Circle()
                                                .fill(account.color.opacity(0.15))
                                                .frame(width: 32, height: 32)

                                            Image(systemName: account.icon)
                                                .font(.caption)
                                                .foregroundStyle(account.color)
                                        }

                                        Text(account.name)
                                            .font(.body)
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)

                                        Spacer()

                                        Text(formatAmount(account.currentBalance, currency: account.currency))
                                            .font(.body.bold())
                                            .foregroundStyle(account.currentBalance < 0 ? .red : .primary)
                                    }
                                }
                            }
                            .padding(.leading, 8)
                        }
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: .rect(cornerRadius: 16))
    }

    private func formatAmount(_ amount: Decimal, currency: Currency) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        formatter.groupingSeparator = "."
        formatter.decimalSeparator = ","
        let amountString = formatter.string(from: amount as NSDecimalNumber) ?? "0"

        // Get symbol and flag emoji for the currency
        if let currencyRecord = allCurrencies.first(where: { $0.code == currency.rawValue }) {
            return "\(currencyRecord.displaySymbol)\(amountString) \(currencyRecord.flagEmoji)"
        }
        // Fallback: use $ only for USD
        let fallbackSymbol = currency.rawValue == "USD" ? "$" : currency.rawValue
        return "\(fallbackSymbol)\(amountString) \(currency.flag)"
    }
}

// MARK: - Recent Transactions Widget
struct RecentTransactionsWidget: View {
    @Environment(\.appSettings) var appSettings

    // PERFORMANCE: Accept data as parameters instead of @Query
    let transactions: [Transaction]
    let allCurrencies: [CurrencyRecord]

    var preferredCurrencyRecord: CurrencyRecord? {
        allCurrencies.first { $0.code == appSettings.preferredCurrencyEnum.rawValue }
    }

    var recentTransactions: [Transaction] {
        let tracker = DeletedTransactionTracker.shared
        return transactions
            .filter { !tracker.isDeleted($0.id) && $0.modelContext != nil && $0.status == .executed }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.pink, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Transazioni Recenti")
                    .font(.headline.bold())
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.pink, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Spacer()
            }

            if recentTransactions.isEmpty {
                Text("Nessuna transazione")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 12) {
                    ForEach(recentTransactions) { transaction in
                        VStack(spacing: 8) {
                            HStack(alignment: .center, spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill((transaction.category?.color ?? .blue).opacity(0.15))
                                        .frame(width: 36, height: 36)

                                    Image(systemName: transaction.category?.icon ?? "questionmark")
                                        .font(.caption)
                                        .foregroundStyle(transaction.category?.color ?? .blue)
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(transaction.category?.name ?? "Altro")
                                            .font(.body.bold())
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)

                                        Image(systemName: transactionTypeIcon(for: transaction))
                                            .font(.caption2)
                                            .foregroundStyle(transactionTypeColor(for: transaction))
                                    }

                                    if !transaction.notes.isEmpty {
                                        Text(transaction.notes)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }

                                    HStack(spacing: 6) {
                                        if let account = transaction.account {
                                            Text(account.name)
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                        }

                                        Text("•")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)

                                        Text(formatDateShort(transaction.date))
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }

                                Spacer()

                                Text(formatTransactionAmount(transaction))
                                    .font(.body.bold())
                                    .foregroundStyle(transactionTypeColor(for: transaction))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }

                            if transaction != recentTransactions.last {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: .rect(cornerRadius: 16))
    }

    private func transactionTypeIcon(for transaction: Transaction) -> String {
        switch transaction.transactionType {
        case .expense: return "arrow.down"
        case .income: return "arrow.up"
        case .transfer: return "arrow.left.arrow.right"
        case .liabilityPayment: return "creditcard.and.123"
        case .adjustment: return "slider.horizontal.3"
        }
    }

    private func transactionTypeColor(for transaction: Transaction) -> Color {
        switch transaction.transactionType {
        case .expense: return .red
        case .income: return .green
        case .transfer: return .blue
        case .liabilityPayment: return .orange
        case .adjustment: return .purple
        }
    }

    private func formatTransactionAmount(_ transaction: Transaction) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = "."
        formatter.decimalSeparator = ","
        let amountString = formatter.string(from: transaction.amount as NSDecimalNumber) ?? "0"

        let sign = transaction.transactionType == .expense ? "-" : "+"

        // Get symbol and flag emoji for the currency
        if let currencyRecord = allCurrencies.first(where: { $0.code == transaction.currency.rawValue }) {
            return "\(sign)\(currencyRecord.displaySymbol)\(amountString) \(currencyRecord.flagEmoji)"
        }
        // Fallback: use $ only for USD
        let fallbackSymbol = transaction.currency.rawValue == "USD" ? "$" : transaction.currency.rawValue
        return "\(sign)\(fallbackSymbol)\(amountString) \(transaction.currency.flag)"
    }

    private func formatDateShort(_ date: Date) -> String {
        return FormatterCache.italianDateShort.string(from: date)
    }
}

// MARK: - Upcoming Bills Widget
struct UpcomingBillsWidget: View {
    @Environment(\.appSettings) var appSettings

    // PERFORMANCE: Accept data as parameters instead of @Query
    let transactions: [Transaction]
    let allCurrencies: [CurrencyRecord]

    var preferredCurrencyRecord: CurrencyRecord? {
        allCurrencies.first { $0.code == appSettings.preferredCurrencyEnum.rawValue }
    }

    var upcomingBills: [Transaction] {
        let now = Date()
        let calendar = Calendar.current
        guard let futureDate = calendar.date(byAdding: .day, value: 30, to: now) else { return [] }

        return transactions.filter { transaction in
            return transaction.isScheduled &&
                   transaction.status == .pending &&
                   transaction.date >= now &&
                   transaction.date <= futureDate
        }
        .sorted { $0.date < $1.date }
        .prefix(5)
        .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bell.fill")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .yellow],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Prossime Scadenze")
                    .font(.headline.bold())
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .yellow],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Spacer()

                Text("30 Giorni")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            if upcomingBills.isEmpty {
                Text("Nessuna scadenza")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 12) {
                    ForEach(upcomingBills) { transaction in
                        VStack(spacing: 8) {
                            HStack(alignment: .center, spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill((transaction.category?.color ?? .blue).opacity(0.15))
                                        .frame(width: 36, height: 36)

                                    Image(systemName: transaction.category?.icon ?? "questionmark")
                                        .font(.caption)
                                        .foregroundStyle(transaction.category?.color ?? .blue)
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(transaction.category?.name ?? "Altro")
                                            .font(.body.bold())
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)

                                        // Transaction type badge
                                        HStack(spacing: 3) {
                                            Image(systemName: transactionTypeIcon(for: transaction))
                                                .font(.system(size: 8))
                                            Text(transactionTypeLabel(for: transaction))
                                                .font(.system(size: 9, weight: .medium))
                                        }
                                        .foregroundStyle(transactionTypeColor(for: transaction))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(
                                            Capsule()
                                                .fill(transactionTypeColor(for: transaction).opacity(0.15))
                                        )
                                    }

                                    if !transaction.notes.isEmpty {
                                        Text(transaction.notes)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }

                                    HStack(spacing: 6) {
                                        if let account = transaction.account {
                                            Text(account.name)
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                        }

                                        Text("•")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)

                                        Text(formatDate(transaction.date))
                                            .font(.caption2)
                                            .foregroundStyle(.orange)
                                    }
                                }

                                Spacer()

                                Text(formatAmount(transaction))
                                    .font(.body.bold())
                                    .foregroundStyle(transactionTypeColor(for: transaction))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }

                            if transaction != upcomingBills.last {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: .rect(cornerRadius: 16))
    }

    private func transactionTypeIcon(for transaction: Transaction) -> String {
        switch transaction.transactionType {
        case .expense: return "arrow.down"
        case .income: return "arrow.up"
        case .transfer: return "arrow.left.arrow.right"
        case .liabilityPayment: return "creditcard.and.123"
        case .adjustment: return "slider.horizontal.3"
        }
    }

    private func transactionTypeLabel(for transaction: Transaction) -> String {
        switch transaction.transactionType {
        case .expense: return "Uscita"
        case .income: return "Entrata"
        case .transfer: return "Trasf"
        case .liabilityPayment: return "Pag Pass"
        case .adjustment: return "Ajust"
        }
    }

    private func transactionTypeColor(for transaction: Transaction) -> Color {
        switch transaction.transactionType {
        case .expense: return .red
        case .income: return .green
        case .transfer: return .blue
        case .liabilityPayment: return .orange
        case .adjustment: return .purple
        }
    }

    private func formatAmount(_ transaction: Transaction) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = "."
        formatter.decimalSeparator = ","
        let amountString = formatter.string(from: transaction.amount as NSDecimalNumber) ?? "0"

        // Get symbol and flag emoji for the currency
        if let currencyRecord = allCurrencies.first(where: { $0.code == transaction.currency.rawValue }) {
            return "\(currencyRecord.displaySymbol)\(amountString) \(currencyRecord.flagEmoji)"
        }
        // Fallback: use $ only for USD
        let fallbackSymbol = transaction.currency.rawValue == "USD" ? "$" : transaction.currency.rawValue
        return "\(fallbackSymbol)\(amountString) \(transaction.currency.flag)"
    }

    private func formatDate(_ date: Date) -> String {
        return FormatterCache.italianDate.string(from: date)
    }
}
