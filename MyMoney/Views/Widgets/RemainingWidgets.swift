//
//  RemainingWidgets.swift
//  MoneyTracker
//
//  Created on 2026-01-27.
//

import SwiftUI
import SwiftData
import Charts

// MARK: - Net Worth Trend Widget
struct NetWorthTrendWidget: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appSettings) var appSettings
    @Query private var accounts: [Account]
    @Query private var allCurrencies: [CurrencyRecord]

    var preferredCurrencyRecord: CurrencyRecord? {
        allCurrencies.first { $0.code == appSettings.preferredCurrencyEnum.rawValue }
    }

    var monthlyNetWorth: [(month: String, netWorth: Decimal)] {
        guard let preferredCurrency = preferredCurrencyRecord else { return [] }

        let calendar = Calendar.current
        let now = Date()
        var result: [(month: String, netWorth: Decimal)] = []

        for monthOffset in (0..<6).reversed() {
            guard let monthDate = calendar.date(byAdding: .month, value: -monthOffset, to: now) else { continue }

            var totalNetWorth: Decimal = 0

            for account in accounts {
                guard let accountCurrency = account.currencyRecord else { continue }
                let accountBalance = calculateAccountBalance(account)
                let converted = CurrencyService.shared.convert(
                    amount: accountBalance,
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

    private func calculateAccountBalance(_ account: Account) -> Decimal {
        var balance = account.initialBalance
        let tracker = DeletedTransactionTracker.shared

        if let accountTransactions = account.transactions {
            for transaction in accountTransactions where !tracker.isDeleted(transaction.id) && transaction.modelContext != nil && transaction.status == .executed {
                switch transaction.transactionType {
                case .expense: balance -= transaction.amount
                case .income: balance += transaction.amount
                case .transfer: balance -= transaction.amount
                case .adjustment: balance += transaction.amount
                }
            }
        }

        if let incoming = account.incomingTransfers {
            for transfer in incoming where !tracker.isDeleted(transfer.id) && transfer.modelContext != nil && transfer.status == .executed && transfer.transactionType == .transfer {
                if let destAmount = transfer.destinationAmount {
                    balance += destAmount
                } else if let transferCurr = transfer.currencyRecord,
                          let accountCurr = account.currencyRecord {
                    let convertedAmount = CurrencyService.shared.convert(
                        amount: transfer.amount,
                        from: transferCurr,
                        to: accountCurr,
                        context: modelContext
                    )
                    balance += convertedAmount
                }
            }
        }

        return balance
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title3)
                    .foregroundStyle(.blue)

                Text("Andamento Patrimonio")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("Ultimi 6 Mesi")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
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

// MARK: - Savings Rate Widget
struct SavingsRateWidget: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appSettings) var appSettings
    @Query private var transactions: [Transaction]
    @Query private var allCurrencies: [CurrencyRecord]

    var preferredCurrencyRecord: CurrencyRecord? {
        allCurrencies.first { $0.code == appSettings.preferredCurrencyEnum.rawValue }
    }

    var savingsRate: Double {
        guard let preferredCurrency = preferredCurrencyRecord else { return 0 }

        let calendar = Calendar.current
        let now = Date()
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else { return 0 }

        let tracker = DeletedTransactionTracker.shared
        let monthTransactions = transactions.filter { transaction in
            guard !tracker.isDeleted(transaction.id) else { return false }
            guard transaction.modelContext != nil else { return false }
            return transaction.date >= startOfMonth &&
                   transaction.date <= now &&
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

        guard income > 0 else { return 0 }
        let savings = income - expenses
        return Double(truncating: savings as NSDecimalNumber) / Double(truncating: income as NSDecimalNumber) * 100
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "percent")
                    .font(.title3)
                    .foregroundStyle(.blue)

                Text("Tasso Risparmio")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            Text("\(Int(savingsRate))%")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(savingsRate >= 20 ? .green : savingsRate >= 10 ? .orange : .red)

            Text("Questo Mese")
                .font(.caption)
                .foregroundStyle(.secondary)
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

// MARK: - Daily Average Widget
struct DailyAverageWidget: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appSettings) var appSettings
    @Query private var transactions: [Transaction]
    @Query private var allCurrencies: [CurrencyRecord]

    var preferredCurrencyRecord: CurrencyRecord? {
        allCurrencies.first { $0.code == appSettings.preferredCurrencyEnum.rawValue }
    }

    var dailyAverage: Decimal {
        guard let preferredCurrency = preferredCurrencyRecord else { return 0 }

        let calendar = Calendar.current
        let now = Date()
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else { return 0 }

        let tracker = DeletedTransactionTracker.shared
        let monthTransactions = transactions.filter { transaction in
            guard !tracker.isDeleted(transaction.id) else { return false }
            guard transaction.modelContext != nil else { return false }
            return transaction.date >= startOfMonth &&
                   transaction.date <= now &&
                   transaction.transactionType == .expense &&
                   transaction.status == .executed
        }

        var total: Decimal = 0

        for transaction in monthTransactions {
            guard let transactionCurrency = transaction.currencyRecord else { continue }

            let converted = CurrencyService.shared.convert(
                amount: transaction.amount,
                from: transactionCurrency,
                to: preferredCurrency,
                context: modelContext
            )
            total += converted
        }

        let dayOfMonth = calendar.component(.day, from: now)
        guard dayOfMonth > 0 else { return 0 }

        return total / Decimal(dayOfMonth)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.title3)
                    .foregroundStyle(.blue)

                Text("Media Giornaliera")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            Text(formatAmount(dailyAverage))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text("Questo Mese")
                .font(.caption)
                .foregroundStyle(.secondary)
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
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let amountString = formatter.string(from: amount as NSDecimalNumber) ?? "0.00"
        return "\(appSettings.preferredCurrencyEnum.symbol)\(amountString)"
    }
}

// MARK: - Monthly Comparison Widget
struct MonthlyComparisonWidget: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appSettings) var appSettings
    @Query private var transactions: [Transaction]
    @Query private var allCurrencies: [CurrencyRecord]

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
                    .font(.title3)
                    .foregroundStyle(.blue)

                Text("Confronto Mensile")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Questo Mese")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(formatAmount(comparison.thisMonth))
                            .font(.title3.bold())
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mese Scorso")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(formatAmount(comparison.lastMonth))
                            .font(.title3.bold())
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Divider()

                HStack {
                    Image(systemName: comparison.isIncrease ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .foregroundStyle(comparison.isIncrease ? .red : .green)

                    Text("\(Int(comparison.change))%")
                        .font(.headline.bold())
                        .foregroundStyle(comparison.isIncrease ? .red : .green)

                    Text(comparison.isIncrease ? "in più" : "in meno")
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
        let amountString = formatter.string(from: amount as NSDecimalNumber) ?? "0"
        return "\(appSettings.preferredCurrencyEnum.symbol)\(amountString)"
    }
}

// MARK: - Account Balances Widget
struct AccountBalancesWidget: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var accounts: [Account]

    var topAccounts: [Account] {
        accounts.sorted { calculateAccountBalance($0) > calculateAccountBalance($1) }
            .prefix(5)
            .map { $0 }
    }

    private func calculateAccountBalance(_ account: Account) -> Decimal {
        var balance = account.initialBalance
        let tracker = DeletedTransactionTracker.shared

        if let accountTransactions = account.transactions {
            for transaction in accountTransactions where !tracker.isDeleted(transaction.id) && transaction.modelContext != nil && transaction.status == .executed {
                switch transaction.transactionType {
                case .expense: balance -= transaction.amount
                case .income: balance += transaction.amount
                case .transfer: balance -= transaction.amount
                case .adjustment: balance += transaction.amount
                }
            }
        }

        if let incoming = account.incomingTransfers {
            for transfer in incoming where !tracker.isDeleted(transfer.id) && transfer.modelContext != nil && transfer.status == .executed && transfer.transactionType == .transfer {
                if let destAmount = transfer.destinationAmount {
                    balance += destAmount
                } else if let transferCurr = transfer.currencyRecord,
                          let accountCurr = account.currencyRecord {
                    let convertedAmount = CurrencyService.shared.convert(
                        amount: transfer.amount,
                        from: transferCurr,
                        to: accountCurr,
                        context: modelContext
                    )
                    balance += convertedAmount
                }
            }
        }

        return balance
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "creditcard.fill")
                    .font(.title3)
                    .foregroundStyle(.blue)

                Text("Saldi Conti")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            if topAccounts.isEmpty {
                Text("Nessun conto")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 10) {
                    ForEach(topAccounts) { account in
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

                            Text(formatAmount(calculateAccountBalance(account), currency: account.currency))
                                .font(.body.bold())
                                .foregroundStyle(.primary)
                        }
                    }
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

    private func formatAmount(_ amount: Decimal, currency: Currency) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        let amountString = formatter.string(from: amount as NSDecimalNumber) ?? "0"
        return "\(currency.symbol)\(amountString)"
    }
}

// MARK: - Recent Transactions Widget
struct RecentTransactionsWidget: View {
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

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
                    .font(.title3)
                    .foregroundStyle(.blue)

                Text("Transazioni Recenti")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            if recentTransactions.isEmpty {
                Text("Nessuna transazione")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 10) {
                    ForEach(recentTransactions) { transaction in
                        HStack {
                            ZStack {
                                Circle()
                                    .fill((transaction.category?.color ?? .blue).opacity(0.15))
                                    .frame(width: 32, height: 32)

                                Image(systemName: transaction.category?.icon ?? "questionmark")
                                    .font(.caption)
                                    .foregroundStyle(transaction.category?.color ?? .blue)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(transaction.category?.name ?? "Altro")
                                    .font(.body)
                                    .foregroundStyle(.primary)

                                Text(transaction.date, style: .date)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text(formatTransactionAmount(transaction))
                                .font(.body.bold())
                                .foregroundStyle(transaction.transactionType == .expense ? .red : .green)
                        }
                    }
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

    private func formatTransactionAmount(_ transaction: Transaction) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        let amountString = formatter.string(from: transaction.amount as NSDecimalNumber) ?? "0"
        let sign = transaction.transactionType == .expense ? "-" : "+"
        return "\(sign)\(transaction.currency.symbol)\(amountString)"
    }
}

// MARK: - Upcoming Bills Widget
struct UpcomingBillsWidget: View {
    @Query private var transactions: [Transaction]

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
                    .font(.title3)
                    .foregroundStyle(.blue)

                Text("Prossime Scadenze")
                    .font(.headline)
                    .foregroundStyle(.secondary)

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
                VStack(spacing: 10) {
                    ForEach(upcomingBills) { transaction in
                        HStack {
                            ZStack {
                                Circle()
                                    .fill((transaction.category?.color ?? .blue).opacity(0.15))
                                    .frame(width: 32, height: 32)

                                Image(systemName: transaction.category?.icon ?? "questionmark")
                                    .font(.caption)
                                    .foregroundStyle(transaction.category?.color ?? .blue)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(transaction.category?.name ?? "Altro")
                                    .font(.body)
                                    .foregroundStyle(.primary)

                                Text(transaction.date, style: .date)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text(formatAmount(transaction))
                                .font(.body.bold())
                                .foregroundStyle(.primary)
                        }
                    }
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

    private func formatAmount(_ transaction: Transaction) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        let amountString = formatter.string(from: transaction.amount as NSDecimalNumber) ?? "0"
        return "\(transaction.currency.symbol)\(amountString)"
    }
}
