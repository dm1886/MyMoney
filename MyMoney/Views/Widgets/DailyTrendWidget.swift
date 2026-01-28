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
    @Query private var transactions: [Transaction]
    @Query private var allCurrencies: [CurrencyRecord]
    @Query private var exchangeRates: [ExchangeRate]
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

    var dailyData: [DailyData] {
        _ = exchangeRates.count
        guard let preferredCurrency = preferredCurrencyRecord else { return [] }

        let calendar = Calendar.current
        let now = Date()

        var startDate: Date
        var component: Calendar.Component
        var count: Int

        switch selectedPeriod {
        case .day:
            startDate = calendar.date(byAdding: .hour, value: -23, to: now)!
            component = .hour
            count = 24
        case .month:
            startDate = calendar.date(byAdding: .day, value: -29, to: now)!
            component = .day
            count = 30
        case .year:
            startDate = calendar.date(byAdding: .month, value: -11, to: now)!
            component = .month
            count = 12
        }

        let tracker = DeletedTransactionTracker.shared
        let relevantTransactions = transactions.filter { transaction in
            guard !tracker.isDeleted(transaction.id) else { return false }
            guard transaction.modelContext != nil else { return false }
            guard transaction.status != .pending else { return false }
            return transaction.date >= startDate && transaction.date <= now
        }

        var dataMap: [Date: (expenses: Decimal, income: Decimal)] = [:]

        // Initialize all periods with zero
        for offset in 0..<count {
            if let date = calendar.date(byAdding: component, value: -offset, to: now) {
                let key: Date
                if selectedPeriod == .day {
                    key = calendar.date(bySetting: .minute, value: 0, of: date)!
                    let _ = calendar.date(bySetting: .second, value: 0, of: key)!
                } else if selectedPeriod == .month {
                    key = calendar.startOfDay(for: date)
                } else {
                    let components = calendar.dateComponents([.year, .month], from: date)
                    key = calendar.date(from: components)!
                }
                dataMap[key] = (0, 0)
            }
        }

        // Populate with transaction data
        for transaction in relevantTransactions {
            let key: Date
            if selectedPeriod == .day {
                var components = calendar.dateComponents([.year, .month, .day, .hour], from: transaction.date)
                components.minute = 0
                components.second = 0
                key = calendar.date(from: components)!
            } else if selectedPeriod == .month {
                key = calendar.startOfDay(for: transaction.date)
            } else {
                let components = calendar.dateComponents([.year, .month], from: transaction.date)
                key = calendar.date(from: components)!
            }

            guard let transactionCurrency = transaction.currencyRecord else { continue }
            let convertedAmount = CurrencyService.shared.convert(
                amount: transaction.amount,
                from: transactionCurrency,
                to: preferredCurrency,
                context: modelContext
            )

            var current = dataMap[key] ?? (0, 0)

            if transaction.transactionType == .expense {
                current.expenses += convertedAmount
            } else if transaction.transactionType == .income {
                current.income += convertedAmount
            }

            dataMap[key] = current
        }

        return dataMap.map { date, values in
            DailyData(
                date: date,
                expenses: Double(truncating: values.expenses as NSDecimalNumber),
                income: Double(truncating: values.income as NSDecimalNumber)
            )
        }.sorted { $0.date < $1.date }
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "chart.xyaxis.line")
                    .font(.title3)
                    .foregroundStyle(.blue)

                Text("Andamento")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Spacer()

                // Period Picker
                Picker("Periodo", selection: $selectedPeriod) {
                    ForEach(TrendPeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            if dailyData.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.downtrend.xyaxis")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)

                    Text("Nessun dato disponibile")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(height: 200)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    // Legend
                    HStack(spacing: 20) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                            Text("Spese")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text("Entrate")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Chart {
                        ForEach(dailyData) { data in
                            // Expenses Line
                            LineMark(
                                x: .value("Data", data.date),
                                y: .value("Spese", data.expenses)
                            )
                            .foregroundStyle(Color.red)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                            .interpolationMethod(.catmullRom)

                            AreaMark(
                                x: .value("Data", data.date),
                                y: .value("Spese", data.expenses)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.red.opacity(0.25), Color.red.opacity(0.0)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .interpolationMethod(.catmullRom)

                            // Income Line
                            LineMark(
                                x: .value("Data", data.date),
                                y: .value("Entrate", data.income)
                            )
                            .foregroundStyle(Color.green)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                            .interpolationMethod(.catmullRom)

                            AreaMark(
                                x: .value("Data", data.date),
                                y: .value("Entrate", data.income)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.green.opacity(0.25), Color.green.opacity(0.0)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .interpolationMethod(.catmullRom)
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: xAxisStride()) { value in
                            if let date = value.as(Date.self) {
                                AxisValueLabel {
                                    Text(formatXAxisLabel(date))
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let amount = value.as(Double.self) {
                                    Text(formatShortAmount(amount))
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                    .frame(height: 220)
                    .animation(.easeInOut(duration: 0.5), value: selectedPeriod)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        )
        .animation(.easeInOut(duration: 0.3), value: dailyData.count)
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
            return date.formatted(.dateTime.hour())
        case .month:
            return date.formatted(.dateTime.day().month(.narrow))
        case .year:
            return date.formatted(.dateTime.month(.narrow))
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
