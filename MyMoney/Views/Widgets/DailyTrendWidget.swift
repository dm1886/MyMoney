//
//  DailyTrendWidget.swift
//  MoneyTracker
//
//  Created on 2026-01-28.
//

import SwiftUI
import SwiftData
import Charts

enum TrendPeriod: String, CaseIterable {
    case day = "Giorno"
    case month = "Mese"
    case year = "Anno"
}

struct DailyTrendWidget: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appSettings) var appSettings

    // PERFORMANCE: Accept data as parameters instead of @Query
    let transactions: [Transaction]
    let allCurrencies: [CurrencyRecord]

    @State private var selectedPeriod: TrendPeriod = .month

    var preferredCurrencyRecord: CurrencyRecord? {
        allCurrencies.first { $0.code == appSettings.preferredCurrencyEnum.rawValue }
    }

    struct DailyData: Identifiable {
        let id = UUID()
        let date: Date
        let expenses: Double
        let income: Double
    }

    var totalExpenses: Double {
        dailyData.reduce(0) { $0 + $1.expenses }
    }

    var totalIncome: Double {
        dailyData.reduce(0) { $0 + $1.income }
    }

    var dailyData: [DailyData] {
        guard let preferredCurrency = preferredCurrencyRecord else { return [] }
        let calendar = Calendar.current, now = Date()
        let start: Date
        let component: Calendar.Component
        let count: Int
        switch selectedPeriod {
        case .day:
            start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now))!
            component = .day; count = 7
        case .month:
            start = calendar.dateInterval(of: .month, for: now)!.start
            component = .day; count = calendar.range(of: .day, in: .month, for: now)!.count
        case .year:
            start = calendar.dateInterval(of: .year, for: now)!.start
            component = .month; count = 12
        }
        let tracker = DeletedTransactionTracker.shared
        let valid = transactions.filter { !tracker.isDeleted($0.id) && $0.modelContext != nil && $0.status != .pending && $0.date >= start && $0.date <= now }
        return (0..<count).map { offset in
            let date = calendar.date(byAdding: component, value: offset, to: start)!
            let end = calendar.date(byAdding: component, value: 1, to: date)!
            var expenses: Decimal = 0, income: Decimal = 0
            for transaction in valid where transaction.date >= date && transaction.date < end {
                guard let currency = transaction.currencyRecord else { continue }
                let amount = CurrencyService.shared.convert(amount: transaction.amount, from: currency, to: preferredCurrency, context: modelContext)
                if transaction.transactionType == .expense { expenses += amount }
                if transaction.transactionType == .income { income += amount }
            }
            return DailyData(date: date, expenses: NSDecimalNumber(decimal: expenses).doubleValue, income: NSDecimalNumber(decimal: income).doubleValue)
        }
    }

    var body: some View {
        OrbCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Spese").font(.orbHeadline).lineLimit(1)
                    Spacer(minLength: 4)
                    OrbCompactPeriod(values: TrendPeriod.allCases, selection: $selectedPeriod)
                }
                Text(OrbCurrency.string(totalExpenses, symbol: preferredCurrencyRecord?.displaySymbol ?? "€"))
                    .font(.orb(25, weight: .bold)).monospacedDigit()
                OrbColumnsChart(points: dailyData.map { OrbChartPoint(label: formatXAxisLabel($0.date), amount: $0.expenses, date: $0.date) }, symbol: preferredCurrencyRecord?.displaySymbol ?? "€")
            }
        }
    }

    private func xAxisStride() -> AxisMarkValues {
        switch selectedPeriod {
        case .day:
            return .stride(by: .hour, count: 6)
        case .month:
            return .stride(by: .day, count: 7)
        case .year:
            return .stride(by: .month, count: 2)
        }
    }

    private func formatXAxisLabel(_ date: Date) -> String {
        switch selectedPeriod {
        case .day:
            return date.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "it_IT")))
        case .month:
            return date.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "it_IT")))
        case .year:
            return date.formatted(.dateTime.month(.abbreviated).locale(Locale(identifier: "it_IT")))
        }
    }

    private func formatShortAmount(_ amount: Double) -> String {
        let absAmount = abs(amount)
        if absAmount >= 1000 {
            return String(format: "%.0fK", absAmount / 1000)
        } else {
            return String(format: "%.0f", absAmount)
        }
    }
}
