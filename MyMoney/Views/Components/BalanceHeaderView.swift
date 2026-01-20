//
//  BalanceHeaderView.swift
//  MoneyTracker
//
//  Created on 2026-01-19.
//

import SwiftUI
import SwiftData

struct BalanceHeaderView: View {
    @Environment(\.appSettings) var appSettings

    let totalBalance: Decimal
    let positiveBalance: Decimal
    let negativeBalance: Decimal
    let weeklyExpenses: [DailyExpense]
    let currencySymbol: String

    var body: some View {
        Group {
            switch appSettings.balanceHeaderStyle {
            case .totalBalance:
                totalBalanceHeader
            case .assetsDebts:
                assetsDebtsHeader
            case .onlyPositive:
                onlyPositiveHeader
            case .onlyNegative:
                onlyNegativeHeader
            case .horizontalBars:
                horizontalBarsHeader
            case .weeklyTrend:
                weeklyTrendHeader
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
        )
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Total Balance Style
    private var totalBalanceHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "wallet.pass.fill")
                    .font(.title3)
                    .foregroundStyle(appSettings.accentColor)
                Text("Saldo Totale")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Text(formatAmount(totalBalance))
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundColor(totalBalance >= 0 ? .primary : .red)

            // Mini bar showing positive/negative ratio
            if positiveBalance > 0 || abs(negativeBalance) > 0 {
                HStack(spacing: 16) {
                    Label(formatCompact(positiveBalance), systemImage: "arrow.up.circle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.green)

                    Label(formatCompact(abs(negativeBalance)), systemImage: "arrow.down.circle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.red)
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Assets & Debts Style
    private var assetsDebtsHeader: some View {
        VStack(spacing: 16) {
            // Title
            HStack {
                Image(systemName: "chart.pie.fill")
                    .foregroundStyle(appSettings.accentColor)
                Text("Panoramica")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            // Circular progress indicator
            HStack(spacing: 24) {
                // Mini donut chart
                ZStack {
                    Circle()
                        .stroke(Color.red.opacity(0.3), lineWidth: 8)
                        .frame(width: 70, height: 70)

                    Circle()
                        .trim(from: 0, to: positiveRatio)
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(-90))

                    Text("\(Int(positiveRatio * 100))%")
                        .font(.caption.bold())
                        .foregroundStyle(.primary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Circle()
                            .fill(.green)
                            .frame(width: 10, height: 10)
                        Text("Attivi")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatAmount(positiveBalance))
                            .font(.subheadline.bold())
                            .foregroundStyle(.green)
                    }

                    HStack {
                        Circle()
                            .fill(.red)
                            .frame(width: 10, height: 10)
                        Text("Debiti")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatAmount(abs(negativeBalance)))
                            .font(.subheadline.bold())
                            .foregroundStyle(.red)
                    }

                    Divider()

                    HStack {
                        Text("Netto")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatAmount(totalBalance))
                            .font(.headline.bold())
                            .foregroundColor(totalBalance >= 0 ? .primary : .red)
                    }
                }
            }
        }
    }

    // MARK: - Only Positive Style
    private var onlyPositiveHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.green)
                Text("Saldo Positivo")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Text(formatAmount(positiveBalance))
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(.green)

            Text("Da \(countPositiveAccounts) conti")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Only Negative Style
    private var onlyNegativeHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.red)
                Text("Debiti Totali")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Text(formatAmount(abs(negativeBalance)))
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(.red)

            if negativeBalance < 0 {
                Text("Da ripagare")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Nessun debito!")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
    }

    // MARK: - Horizontal Bars Style
    private var horizontalBarsHeader: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.xaxis")
                    .foregroundStyle(appSettings.accentColor)
                Text("Bilancio")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatAmount(totalBalance))
                    .font(.headline.bold())
                    .foregroundStyle(totalBalance >= 0 ? Color.primary : Color.red)
            }

            VStack(spacing: 12) {
                // Positive bar
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Attivi")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatAmount(positiveBalance))
                            .font(.caption.bold())
                            .foregroundStyle(.green)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.green.opacity(0.2))
                                .frame(height: 12)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [.green, .green.opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * positiveRatio, height: 12)
                        }
                    }
                    .frame(height: 12)
                }

                // Negative bar
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Debiti")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatAmount(abs(negativeBalance)))
                            .font(.caption.bold())
                            .foregroundStyle(.red)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.red.opacity(0.2))
                                .frame(height: 12)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [.red, .red.opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * negativeRatio, height: 12)
                        }
                    }
                    .frame(height: 12)
                }
            }
        }
    }

    // MARK: - Weekly Trend Style
    private var weeklyTrendHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(appSettings.accentColor)
                Text("Spese Ultimi 7 Giorni")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatAmount(weeklyTotal))
                    .font(.headline.bold())
                    .foregroundStyle(.red)
            }

            // Bar chart for weekly expenses
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(weeklyExpenses, id: \.date) { day in
                    VStack(spacing: 4) {
                        // Bar
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                day.isToday ?
                                    LinearGradient(colors: [appSettings.accentColor, appSettings.accentColor.opacity(0.7)], startPoint: .top, endPoint: .bottom) :
                                    LinearGradient(colors: [.gray.opacity(0.5), .gray.opacity(0.3)], startPoint: .top, endPoint: .bottom)
                            )
                            .frame(height: barHeight(for: day.amount))

                        // Day label
                        Text(day.dayName)
                            .font(.system(size: 10, weight: day.isToday ? .bold : .regular))
                            .foregroundColor(day.isToday ? appSettings.accentColor : Color.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 80)

            // Legend
            HStack {
                Text("Media giornaliera:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(formatAmount(weeklyAverage))
                    .font(.caption.bold())
            }
        }
    }

    // MARK: - Helpers
    private var positiveRatio: CGFloat {
        let total = positiveBalance + abs(negativeBalance)
        guard total > 0 else { return 0.5 }
        return CGFloat(truncating: (positiveBalance / total) as NSDecimalNumber)
    }

    private var negativeRatio: CGFloat {
        let total = positiveBalance + abs(negativeBalance)
        guard total > 0 else { return 0.5 }
        return CGFloat(truncating: (abs(negativeBalance) / total) as NSDecimalNumber)
    }

    private var countPositiveAccounts: Int {
        // This would need to be passed in, using placeholder
        return 3
    }

    private var weeklyTotal: Decimal {
        weeklyExpenses.reduce(Decimal(0)) { $0 + $1.amount }
    }

    private var weeklyAverage: Decimal {
        guard !weeklyExpenses.isEmpty else { return 0 }
        return weeklyTotal / Decimal(weeklyExpenses.count)
    }

    private func barHeight(for amount: Decimal) -> CGFloat {
        let maxAmount = weeklyExpenses.map { $0.amount }.max() ?? 1
        guard maxAmount > 0 else { return 10 }
        let ratio = CGFloat(truncating: (amount / maxAmount) as NSDecimalNumber)
        return max(10, 60 * ratio)
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let amountString = formatter.string(from: amount as NSDecimalNumber) ?? "0.00"
        return "\(currencySymbol) \(amountString)"
    }

    private func formatCompact(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        let amountString = formatter.string(from: amount as NSDecimalNumber) ?? "0"
        return "\(currencySymbol) \(amountString)"
    }
}

// MARK: - Daily Expense Model
struct DailyExpense {
    let date: Date
    let amount: Decimal
    let dayName: String

    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
}
