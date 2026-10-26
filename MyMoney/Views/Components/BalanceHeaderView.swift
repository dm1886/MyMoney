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
    var orbSize: CGFloat = 74
    var orbitLabels: [String] = []

    private var orbAmount: Decimal {
        switch appSettings.balanceHeaderStyle {
        case .onlyPositive: positiveBalance
        case .onlyNegative: abs(negativeBalance)
        default: totalBalance
        }
    }
    private var orbLabel: String {
        switch appSettings.balanceHeaderStyle {
        case .onlyPositive: "Saldo Positivo"
        case .onlyNegative: "Debiti Totali"
        default: "Saldo totale"
        }
    }
    var body: some View {
        VStack(spacing: 16) {
            if orbSize > 100 {
                OrbView(size: orbSize, orbitLabels: orbitLabels) {
                    VStack(spacing: 8) {
                        Text(orbLabel).font(.orbCaption)
                        OrbAmountLabel(amount: orbAmount, format: formatAmount).font(.orb(38, weight: .bold, relativeTo: .largeTitle))
                            .monospacedDigit().lineLimit(1).minimumScaleFactor(0.1)
                            .frame(width: orbSize * 0.66)
                    }
                }.padding(.vertical, 24).frame(maxWidth: .infinity)
            } else {
                HStack(spacing: 16) {
                    OrbView(size: orbSize) {
                        EmptyView()
                    }.accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(orbLabel).font(.orbCaption).foregroundStyle(Color.orbMuted)
                        AmountText(amount: orbAmount, symbol: currencySymbol + " ")
                            .font(.orbTitle).lineLimit(1).minimumScaleFactor(0.5)
                    }
                    Spacer(minLength: 0)
                }
            }
            switch appSettings.balanceHeaderStyle {
            case .assetsDebts: assetsDebtsHeader.padding(14).orbSurface()
            case .horizontalBars: horizontalBarsHeader.padding(14).orbSurface()
            case .weeklyTrend: weeklyTrendHeader.padding(14).orbSurface()
            case .totalBalance:
                HStack(spacing: 8) {
                    StatTile(label: "Attivi", value: formatAmount(positiveBalance), color: .orbPositive)
                    StatTile(label: "Debiti", value: formatAmount(abs(negativeBalance)), color: .orbNegative)
                }
                if orbSize <= 100 {
                    GeometryReader { g in
                        let total = NSDecimalNumber(decimal: positiveBalance + abs(negativeBalance)).doubleValue
                        let fraction = total > 0 ? NSDecimalNumber(decimal: positiveBalance).doubleValue / total : 0
                        HStack(spacing: 3) {
                            Capsule().fill(Color.chartIncome).frame(width: max(0, (g.size.width - 3) * fraction))
                            Capsule().fill(Color.chartExpense)
                        }
                    }.frame(height: 8)
                }
            case .onlyPositive:
                Text("Da \(countPositiveAccounts) conti").font(.orbCaption).foregroundStyle(Color.orbMuted)
            case .onlyNegative:
                Text(negativeBalance < 0 ? "Da ripagare" : "Nessun debito!").font(.orbCaption).foregroundStyle(Color.orbMuted)
            }
        }.padding(.horizontal, 16).padding(.top, 8)
    }

    // MARK: - Total Balance Style
    private var totalBalanceHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "wallet.pass.fill")
                    .font(.orbTitle3)
                    .foregroundStyle(Color.orbHighlight)
                Text("Saldo Totale")
                    .font(.orbSubheadline.weight(.medium))
                    .foregroundStyle(Color.orbMuted)
            }

            Text(formatAmount(totalBalance))
                .font(.orb(42, weight: .bold, relativeTo: .title))
                .foregroundColor(totalBalance >= 0 ? Color.orbText : Color.orbNegative)

            // Mini bar showing positive/negative ratio
            if positiveBalance > 0 || abs(negativeBalance) > 0 {
                HStack(spacing: 16) {
                    Label(formatCompact(positiveBalance), systemImage: "arrow.up.circle.fill")
                        .font(.orbCaption.weight(.medium))
                        .foregroundStyle(Color.orbPositive)

                    Label(formatCompact(abs(negativeBalance)), systemImage: "arrow.down.circle.fill")
                        .font(.orbCaption.weight(.medium))
                        .foregroundStyle(Color.orbNegative)
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
                    .foregroundStyle(Color.orbHighlight)
                Text("Panoramica")
                    .font(.orbSubheadline.weight(.medium))
                    .foregroundStyle(Color.orbMuted)
            }

            // Circular progress indicator
            HStack(spacing: 24) {
                // Mini donut chart
                ZStack {
                    Circle()
                        .stroke(Color.orbNegative.opacity(0.3), lineWidth: 8)
                        .frame(width: 70, height: 70)

                    Circle()
                        .trim(from: 0, to: positiveRatio)
                        .stroke(Color.orbPositive, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(-90))

                    Text("\(Int(positiveRatio * 100))%")
                        .font(.orbCaption.bold())
                        .foregroundStyle(Color.orbText)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Circle()
                            .fill(Color.orbPositive)
                            .frame(width: 10, height: 10)
                        Text("Attivi")
                            .font(.orbCaption)
                            .foregroundStyle(Color.orbMuted)
                        Spacer()
                        Text(formatAmount(positiveBalance))
                            .font(.orbSubheadline.bold())
                            .foregroundStyle(Color.orbPositive)
                    }

                    HStack {
                        Circle()
                            .fill(Color.orbNegative)
                            .frame(width: 10, height: 10)
                        Text("Debiti")
                            .font(.orbCaption)
                            .foregroundStyle(Color.orbMuted)
                        Spacer()
                        Text(formatAmount(abs(negativeBalance)))
                            .font(.orbSubheadline.bold())
                            .foregroundStyle(Color.orbNegative)
                    }

                    Divider()

                    HStack {
                        Text("Netto")
                            .font(.orbCaption.weight(.medium))
                            .foregroundStyle(Color.orbMuted)
                        Spacer()
                        Text(formatAmount(totalBalance))
                            .font(.orbHeadline.bold())
                            .foregroundColor(totalBalance >= 0 ? Color.orbText : Color.orbNegative)
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
                    .font(.orbTitle3)
                    .foregroundStyle(Color.orbPositive)
                Text("Saldo Positivo")
                    .font(.orbSubheadline.weight(.medium))
                    .foregroundStyle(Color.orbMuted)
            }

            Text(formatAmount(positiveBalance))
                .font(.orb(42, weight: .bold, relativeTo: .title))
                .foregroundStyle(Color.orbPositive)

            Text("Da \(countPositiveAccounts) conti")
                .font(.orbCaption)
                .foregroundStyle(Color.orbMuted)
        }
    }

    // MARK: - Only Negative Style
    private var onlyNegativeHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.orbTitle3)
                    .foregroundStyle(Color.orbNegative)
                Text("Debiti Totali")
                    .font(.orbSubheadline.weight(.medium))
                    .foregroundStyle(Color.orbMuted)
            }

            Text(formatAmount(abs(negativeBalance)))
                .font(.orb(42, weight: .bold, relativeTo: .title))
                .foregroundStyle(Color.orbNegative)

            if negativeBalance < 0 {
                Text("Da ripagare")
                    .font(.orbCaption)
                    .foregroundStyle(Color.orbMuted)
            } else {
                Text("Nessun debito!")
                    .font(.orbCaption)
                    .foregroundStyle(Color.orbPositive)
            }
        }
    }

    // MARK: - Horizontal Bars Style
    private var horizontalBarsHeader: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.xaxis")
                    .foregroundStyle(Color.orbHighlight)
                Text("Bilancio")
                    .font(.orbSubheadline.weight(.medium))
                    .foregroundStyle(Color.orbMuted)
                Spacer()
                Text(formatAmount(totalBalance))
                    .font(.orbHeadline.bold())
                    .foregroundStyle(totalBalance >= 0 ? Color.orbText : Color.orbNegative)
            }

            VStack(spacing: 12) {
                // Positive bar
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Attivi")
                            .font(.orbCaption)
                            .foregroundStyle(Color.orbMuted)
                        Spacer()
                        Text(formatAmount(positiveBalance))
                            .font(.orbCaption.bold())
                            .foregroundStyle(Color.orbPositive)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.orbPositive.opacity(0.2))
                                .frame(height: 12)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    Color.orbPositive
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
                            .font(.orbCaption)
                            .foregroundStyle(Color.orbMuted)
                        Spacer()
                        Text(formatAmount(abs(negativeBalance)))
                            .font(.orbCaption.bold())
                            .foregroundStyle(Color.orbNegative)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.orbNegative.opacity(0.2))
                                .frame(height: 12)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    Color.orbNegative
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
                    .foregroundStyle(Color.orbHighlight)
                Text("Spese Ultimi 7 Giorni")
                    .font(.orbSubheadline.weight(.medium))
                    .foregroundStyle(Color.orbMuted)
                Spacer()
                Text(formatAmount(weeklyTotal))
                    .font(.orbHeadline.bold())
                    .foregroundStyle(Color.orbNegative)
            }

            // Bar chart for weekly expenses
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(weeklyExpenses, id: \.date) { day in
                    VStack(spacing: 4) {
                        // Bar
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                day.isToday ?
                                    Color.orbAccent :
                                    Color.orbMuted.opacity(0.5)
                            )
                            .frame(height: barHeight(for: day.amount))

                        // Day label
                        Text(day.dayName)
                            .font(.system(size: 10, weight: day.isToday ? .bold : .regular))
                            .foregroundColor(day.isToday ? Color.orbAccent : Color.orbMuted)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 80)

            // Legend
            HStack {
                Text("Media giornaliera:")
                    .font(.orbCaption)
                    .foregroundStyle(Color.orbMuted)
                Text(formatAmount(weeklyAverage))
                    .font(.orbCaption.bold())
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
        formatter.locale = Locale(identifier: "it_IT")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let amountString = formatter.string(from: amount as NSDecimalNumber) ?? "0.00"
        return "\(currencySymbol) \(amountString)"
    }

    private func formatCompact(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "it_IT")
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
