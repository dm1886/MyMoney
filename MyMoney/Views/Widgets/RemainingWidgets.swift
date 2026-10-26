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
                let snapshotDate = min(now, calendar.dateInterval(of: .month, for: monthDate)!.end.addingTimeInterval(-1))
                let ledger = Array(Dictionary(grouping: (account.transactions ?? []) + (account.incomingTransfers ?? []), by: \.id).values.compactMap(\.first))
                let historical = monthOffset == 0 ? account.investmentNetWorth : OrbHistorySnapshot.balance(account: account, transactions: ledger, at: snapshotDate)
                let converted = CurrencyService.shared.convert(
                    amount: historical,
                    from: accountCurrency,
                    to: preferredCurrency,
                    context: modelContext
                )
                totalNetWorth += converted
            }

            let formatter = DateFormatter()
            formatter.dateFormat = "MMM"
            formatter.locale = Locale(identifier: "it_IT")

            let snapshotDate = min(now, calendar.dateInterval(of: .month, for: monthDate)!.end.addingTimeInterval(-1))
            if accounts.contains(where: { $0.createdAt <= snapshotDate }) {
                result.append((month: formatter.string(from: monthDate), netWorth: totalNetWorth))
            }
        }

        return result
    }

    var body: some View {
        OrbCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Patrimonio nel tempo").font(.orbHeadline).lineLimit(1)
                OrbCompactPeriod(values: NetWorthPeriod.allCases, selection: $selectedPeriod)
                OrbAreaChart(points: monthlyNetWorth.map { OrbChartPoint(label: $0.month, amount: NSDecimalNumber(decimal: $0.netWorth).doubleValue) }, symbol: preferredCurrencyRecord?.displaySymbol ?? "€")
            }
        }
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
                    .font(.orbTitle2)
                    .foregroundStyle(
                        Color.orbPositive
                    )

                Text("Risparmio & Spesa Media")
                    .font(.orbHeadline.bold())
                    .foregroundStyle(
                        Color.orbPositive
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
                        .font(.orbCaption)
                        .foregroundStyle(Color.orbHighlight)
                    Image(systemName: "chevron.down")
                        .font(.orbCaption2)
                        .foregroundStyle(Color.orbHighlight)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.orbAccent.opacity(0.1))
                )
            }

            // Savings Rate & Daily Average Side by Side
            HStack(spacing: 12) {
                // Savings Rate Section
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(Int(monthlyStats.savingsRate))%")
                        .font(.orb(32, weight: .bold, relativeTo: .title))
                        .foregroundStyle(monthlyStats.savingsRate >= 20 ? Color.orbPositive : monthlyStats.savingsRate >= 10 ? Color.orbHighlight : Color.orbNegative)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text("Risparmio")
                        .font(.orbCaption.bold())
                        .foregroundStyle(Color.orbMuted)

                    Text("(Entrate - Uscite) / Entrate")
                        .font(.system(size: 8))
                        .foregroundStyle(Color.orbMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(monthlyStats.savingsRate >= 20 ? Color.orbPositive.opacity(0.1) : monthlyStats.savingsRate >= 10 ? Color.orbHighlight.opacity(0.1) : Color.orbNegative.opacity(0.1))
                )

                // Daily Average Section
                VStack(alignment: .leading, spacing: 6) {
                    Text(formatAmount(monthlyStats.dailyAverage))
                        .font(.orb(28, weight: .bold, relativeTo: .title))
                        .foregroundStyle(Color.orbText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    Text("al giorno")
                        .font(.orbCaption.bold())
                        .foregroundStyle(Color.orbMuted)

                    Text("Spesa media del mese")
                        .font(.system(size: 8))
                        .foregroundStyle(Color.orbMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.orbCard)
                )
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .orbSurface()
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let symbol = preferredCurrencyRecord?.displaySymbol ?? "$"

        return "\(symbol) \(FormatterCache.formatCurrencyFixed(amount))"
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
        OrbCard { OrbCumulativeChart(transactions: transactions, currency: preferredCurrencyRecord) }
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        formatter.groupingSeparator = "."
        formatter.decimalSeparator = ","
        let amountString = formatter.string(from: amount as NSDecimalNumber) ?? "0"
        let symbol = preferredCurrencyRecord?.displaySymbol ?? "$"

        return "\(symbol) \(amountString)"
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
            let sorted = accountsForType.sorted { $0.investmentNetWorth > $1.investmentNetWorth }
            return (type: type, accounts: sorted)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "creditcard.fill")
                    .font(.orbTitle2)
                    .foregroundStyle(
                        Color.orbSecondary
                    )

                Text("Saldi Conti")
                    .font(.orbHeadline.bold())
                    .foregroundStyle(
                        Color.orbSecondary
                    )

                Spacer()
            }

            if accounts.isEmpty {
                Text("Nessun conto")
                    .font(.orbSubheadline)
                    .foregroundStyle(Color.orbMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 16) {
                    ForEach(accountsByType, id: \.type) { typeGroup in
                        VStack(alignment: .leading, spacing: 8) {
                            // Header tipologia
                            HStack(spacing: 6) {
                                Image(systemName: typeGroup.type.icon)
                                    .font(.orbCaption)
                                    .foregroundStyle(Color.orbMuted)
                                Text(typeGroup.type.rawValue)
                                    .font(.orbCaption.bold())
                                    .foregroundStyle(Color.orbMuted)
                                    .textCase(.uppercase)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.orbCard)
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
                                                .font(.orbCaption)
                                                .foregroundStyle(account.color)
                                        }

                                        Text(account.name)
                                            .font(.orbBody)
                                            .foregroundStyle(Color.orbText)
                                            .lineLimit(1)

                                        Spacer()

                                        Text(formatAmount(account.investmentNetWorth, currency: account.currency))
                                            .font(.orbBody.bold())
                                            .foregroundStyle(account.investmentNetWorth < 0 ? Color.orbNegative : Color.orbText)
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
        .orbSurface()
    }

    private func formatAmount(_ amount: Decimal, currency: Currency) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        formatter.groupingSeparator = "."
        formatter.decimalSeparator = ","
        let amountString = formatter.string(from: amount as NSDecimalNumber) ?? "0"

        // Get symbol and flag emoji for the currency
        if let currencyRecord = allCurrencies.first(where: { $0.code == currency.rawValue }) {
            return "\(currencyRecord.displaySymbol) \(amountString)"
        }
        // Fallback: use $ only for USD
        let fallbackSymbol = currency.rawValue == "USD" ? "$" : currency.rawValue
        return "\(fallbackSymbol) \(amountString)"
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
                    .font(.orbTitle2)
                    .foregroundStyle(
                        Color.orbSecondary
                    )

                Text("Transazioni Recenti")
                    .font(.orbHeadline.bold())
                    .foregroundStyle(
                        Color.orbSecondary
                    )

                Spacer()
            }

            if recentTransactions.isEmpty {
                Text("Nessuna transazione")
                    .font(.orbSubheadline)
                    .foregroundStyle(Color.orbMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 12) {
                    ForEach(recentTransactions) { transaction in
                        VStack(spacing: 8) {
                            HStack(alignment: .center, spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill((transaction.category?.color ?? Color.orbAccent).opacity(0.15))
                                        .frame(width: 36, height: 36)

                                    Image(systemName: transaction.category?.icon ?? "questionmark")
                                        .font(.orbCaption)
                                        .foregroundStyle(transaction.category?.color ?? Color.orbAccent)
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(transaction.category?.name ?? "Altro")
                                            .font(.orbBody.bold())
                                            .foregroundStyle(Color.orbText)
                                            .lineLimit(1)

                                        Image(systemName: transactionTypeIcon(for: transaction))
                                            .font(.orbCaption2)
                                            .foregroundStyle(transactionTypeColor(for: transaction))
                                    }

                                    if !transaction.notes.isEmpty {
                                        Text(transaction.notes)
                                            .font(.orbCaption)
                                            .foregroundStyle(Color.orbMuted)
                                            .lineLimit(1)
                                    }

                                    HStack(spacing: 6) {
                                        if let account = transaction.account {
                                            Text(account.name)
                                                .font(.orbCaption2)
                                                .foregroundStyle(Color.orbMuted)
                                        }

                                        Text("•")
                                            .font(.orbCaption2)
                                            .foregroundStyle(Color.orbMuted)

                                        Text(formatDateShort(transaction.date))
                                            .font(.orbCaption2)
                                            .foregroundStyle(Color.orbMuted)
                                    }
                                }

                                Spacer()

                                Text(formatTransactionAmount(transaction))
                                    .font(.orbBody.bold())
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
        .orbSurface()
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
        case .expense: return Color.orbNegative
        case .income: return Color.orbPositive
        case .transfer: return Color.orbAccent
        case .liabilityPayment: return Color.orbHighlight
        case .adjustment: return Color.orbAccent
        }
    }

    private func formatTransactionAmount(_ transaction: Transaction) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = "."
        formatter.decimalSeparator = ","
        let amountString = formatter.string(from: transaction.amount as NSDecimalNumber) ?? "0"

        let sign = transaction.transactionType == .expense ? "-" : "+"

        // Get symbol and flag emoji for the currency
        if let currencyRecord = allCurrencies.first(where: { $0.code == transaction.currency.rawValue }) {
            return "\(sign)\(currencyRecord.displaySymbol) \(amountString)"
        }
        // Fallback: use $ only for USD
        let fallbackSymbol = transaction.currency.rawValue == "USD" ? "$" : transaction.currency.rawValue
        return "\(sign)\(fallbackSymbol) \(amountString)"
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
                    .font(.orbTitle2)
                    .foregroundStyle(
                        Color.orbHighlight
                    )

                Text("Prossime Scadenze")
                    .font(.orbHeadline.bold())
                    .foregroundStyle(
                        Color.orbHighlight
                    )

                Spacer()

                Text("30 Giorni")
                    .font(.orbCaption)
                    .foregroundStyle(Color.orbMuted)
            }

            if upcomingBills.isEmpty {
                Text("Nessuna scadenza")
                    .font(.orbSubheadline)
                    .foregroundStyle(Color.orbMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 12) {
                    ForEach(upcomingBills) { transaction in
                        VStack(spacing: 8) {
                            HStack(alignment: .center, spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill((transaction.category?.color ?? Color.orbAccent).opacity(0.15))
                                        .frame(width: 36, height: 36)

                                    Image(systemName: transaction.category?.icon ?? "questionmark")
                                        .font(.orbCaption)
                                        .foregroundStyle(transaction.category?.color ?? Color.orbAccent)
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(transaction.category?.name ?? "Altro")
                                            .font(.orbBody.bold())
                                            .foregroundStyle(Color.orbText)
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
                                            .font(.orbCaption)
                                            .foregroundStyle(Color.orbMuted)
                                            .lineLimit(1)
                                    }

                                    HStack(spacing: 6) {
                                        if let account = transaction.account {
                                            Text(account.name)
                                                .font(.orbCaption2)
                                                .foregroundStyle(Color.orbMuted)
                                        }

                                        Text("•")
                                            .font(.orbCaption2)
                                            .foregroundStyle(Color.orbMuted)

                                        Text(formatDate(transaction.date))
                                            .font(.orbCaption2)
                                            .foregroundStyle(Color.orbHighlight)
                                    }
                                }

                                Spacer()

                                Text(formatAmount(transaction))
                                    .font(.orbBody.bold())
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
        .orbSurface()
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
        case .expense: return Color.orbNegative
        case .income: return Color.orbPositive
        case .transfer: return Color.orbAccent
        case .liabilityPayment: return Color.orbHighlight
        case .adjustment: return Color.orbAccent
        }
    }

    private func formatAmount(_ transaction: Transaction) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = "."
        formatter.decimalSeparator = ","
        let amountString = formatter.string(from: transaction.amount as NSDecimalNumber) ?? "0"

        // Get symbol and flag emoji for the currency
        if let currencyRecord = allCurrencies.first(where: { $0.code == transaction.currency.rawValue }) {
            return "\(currencyRecord.displaySymbol) \(amountString)"
        }
        // Fallback: use $ only for USD
        let fallbackSymbol = transaction.currency.rawValue == "USD" ? "$" : transaction.currency.rawValue
        return "\(fallbackSymbol) \(amountString)"
    }

    private func formatDate(_ date: Date) -> String {
        return FormatterCache.italianDate.string(from: date)
    }
}
