//
//  IncomeVsExpensesWidget.swift
//  MoneyTracker
//
//  Created on 2026-01-27.
//

import SwiftUI
import SwiftData
import Charts

enum IncomeExpensePeriod: String, CaseIterable {
    case month = "1M"
    case threeMonths = "3M"
    case sixMonths = "6M"
    case year = "1A"

    var displayName: String {
        switch self {
        case .month: return "1 Mese"
        case .threeMonths: return "3 Mesi"
        case .sixMonths: return "6 Mesi"
        case .year: return "1 Anno"
        }
    }

    var monthCount: Int {
        switch self {
        case .month: return 1
        case .threeMonths: return 3
        case .sixMonths: return 6
        case .year: return 12
        }
    }
}

struct IncomeVsExpensesWidget: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appSettings) var appSettings

    // PERFORMANCE: Accept data as parameters instead of @Query
    let transactions: [Transaction]
    let allCurrencies: [CurrencyRecord]
    let accounts: [Account]

    @State private var selectedAccountId: UUID?
    @State private var selectedPeriod: IncomeExpensePeriod = .sixMonths

    var preferredCurrencyRecord: CurrencyRecord? {
        allCurrencies.first { $0.code == appSettings.preferredCurrencyEnum.rawValue }
    }

    var monthlyData: [(month: String, income: Decimal, expenses: Decimal)] {
        guard let preferredCurrency = preferredCurrencyRecord else { return [] }

        let calendar = Calendar.current
        let now = Date()
        let tracker = DeletedTransactionTracker.shared

        var result: [(month: String, income: Decimal, expenses: Decimal)] = []

        // Per 1M mostra i giorni, per gli altri periodi mostra i mesi
        if selectedPeriod == .month {
            // Mostra i giorni del mese corrente
            guard calendar.date(from: calendar.dateComponents([.year, .month], from: now)) != nil else { return [] }
            let dayOfMonth = calendar.component(.day, from: now)

            for dayOffset in (0..<dayOfMonth).reversed() {
                guard let dayDate = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
                let startOfDay = calendar.startOfDay(for: dayDate)
                let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

                let dayTransactions = transactions.filter { transaction in
                    guard !tracker.isDeleted(transaction.id) else { return false }
                    guard transaction.modelContext != nil else { return false }
                    guard transaction.currencyRecord != nil else { return false }

                    if let accountId = selectedAccountId {
                        guard transaction.account?.id == accountId else { return false }
                    }

                    return transaction.date >= startOfDay &&
                           transaction.date < endOfDay &&
                           transaction.status == .executed &&
                           (transaction.transactionType == .income || transaction.transactionType == .expense)
                }

                var income: Decimal = 0
                var expenses: Decimal = 0

                for transaction in dayTransactions {
                    guard let transactionCurrency = transaction.currencyRecord else { continue }

                    let converted = CurrencyService.shared.convert(
                        amount: transaction.amount,
                        from: transactionCurrency,
                        to: preferredCurrency,
                        context: modelContext
                    )

                    if transaction.transactionType == .income {
                        income += converted
                    } else {
                        expenses += converted
                    }
                }

                let formatter = DateFormatter()
                formatter.dateFormat = "d"
                formatter.locale = Locale(identifier: "it_IT")
                let dayName = formatter.string(from: dayDate)

                result.append((month: dayName, income: income, expenses: expenses))
            }
        } else {
            // Mostra i mesi per gli altri periodi
            let monthCount = selectedPeriod.monthCount

            for monthOffset in (0..<monthCount).reversed() {
                guard let monthDate = calendar.date(byAdding: .month, value: -monthOffset, to: now),
                      let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate)) else { continue }

                // Calcola l'ultimo giorno del mese correttamente
                let nextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
                let endOfMonth = calendar.date(byAdding: .day, value: -1, to: nextMonth)!

            // DEBUG: Stampa il range di date per questo mese
            let debugFormatter = DateFormatter()
            debugFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            debugFormatter.locale = Locale(identifier: "it_IT")
            #if DEBUG
            print("📊 [IncomeVsExpenses] Mese \(monthOffset): Range \(debugFormatter.string(from: startOfMonth)) - \(debugFormatter.string(from: endOfMonth))")
            #endif

            let monthTransactions = transactions.filter { transaction in
                guard !tracker.isDeleted(transaction.id) else { return false }
                guard transaction.modelContext != nil else { return false }

                // IMPORTANTE: Salta transazioni senza currency record (dati corrotti)
                guard transaction.currencyRecord != nil else {
                    #if DEBUG
                    print("📊   ⚠️ Trans SALTATA (no currencyRecord): \(transaction.notes)")
                    #endif
                    return false
                }

                // Filter by account if one is selected
                if let accountId = selectedAccountId {
                    guard transaction.account?.id == accountId else { return false }
                }

                let isInRange = transaction.date >= startOfMonth &&
                                transaction.date <= endOfMonth &&
                                transaction.status == .executed &&
                                (transaction.transactionType == .income || transaction.transactionType == .expense)

                // DEBUG: Stampa le transazioni trovate
                #if DEBUG
                if isInRange {
                    print("📊   ✅ Trans [\(transaction.transactionType == .income ? "ENTRATA" : "USCITA")]: \(transaction.amount) - \(transaction.notes) - Data: \(debugFormatter.string(from: transaction.date))")
                }
                #endif

                return isInRange
            }

            #if DEBUG
            print("📊 [IncomeVsExpenses] Totale transazioni trovate per questo mese: \(monthTransactions.count)")
            #endif

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
                } else {
                    expenses += converted
                }
            }

            let formatter = DateFormatter()
            formatter.dateFormat = "MMM"
            formatter.locale = Locale(identifier: "it_IT")
            let monthName = formatter.string(from: monthDate)

            #if DEBUG
            print("📊 [IncomeVsExpenses] RISULTATO \(monthName): Entrate=\(income), Uscite=\(expenses), Transazioni=\(monthTransactions.count)")
            #endif

                result.append((month: monthName, income: income, expenses: expenses))
            }
        }

        #if DEBUG
        print("📊 [IncomeVsExpenses] RIEPILOGO FINALE:")
        for data in result {
            print("📊   \(data.month): Entrate=\(data.income), Uscite=\(data.expenses)")
        }
        #endif

        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Entrate e uscite").font(.orbHeadline).lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                OrbCompactPeriod(values: IncomeExpensePeriod.allCases, selection: $selectedPeriod)
            }
            Menu {
                Button {
                    selectedAccountId = nil
                } label: {
                    Label("Tutti i Conti", systemImage: selectedAccountId == nil ? "checkmark" : "")
                }

                Divider()

                ForEach(accounts) { account in
                    Button {
                        selectedAccountId = account.id
                    } label: {
                        Label(account.name, systemImage: selectedAccountId == account.id ? "checkmark" : "")
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(selectedAccountId == nil ? "Tutti i Conti" : (accounts.first(where: { $0.id == selectedAccountId })?.name ?? "Tutti"))
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

            OrbColumnsChart(points: monthlyData.map { OrbChartPoint(label: $0.month, amount: NSDecimalNumber(decimal: $0.income).doubleValue, second: NSDecimalNumber(decimal: $0.expenses).doubleValue) }, symbol: preferredCurrencyRecord?.displaySymbol ?? "€", paired: true, title: "Entrate e uscite")

        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .orbSurface()
    }
}
