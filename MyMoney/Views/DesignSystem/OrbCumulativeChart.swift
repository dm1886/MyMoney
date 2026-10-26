import SwiftUI
import Charts
import SwiftData

struct OrbCumulativeChart: View {
    let transactions: [Transaction]
    let currency: CurrencyRecord?
    @Environment(\.modelContext) private var context
    @Environment(\.orbMotionAllowed) private var motion
    private func points(monthOffset: Int) -> [OrbChartPoint] {
        guard let currency else { return [] }
        let cal = Calendar.current, now = Date()
        let month = cal.date(byAdding: .month, value: monthOffset, to: now)!
        let start = cal.dateInterval(of: .month, for: month)!.start
        let count = monthOffset == 0 ? cal.component(.day, from: now) : cal.range(of: .day, in: .month, for: month)!.count
        let valid = transactions.filter { $0.modelContext != nil && !DeletedTransactionTracker.shared.isDeleted($0.id) && $0.status == .executed && $0.transactionType == .expense }
        var total: Decimal = 0
        return (0..<count).map { index in
            let date = cal.date(byAdding: .day, value: index, to: start)!
            for t in valid where cal.isDate(t.date, inSameDayAs: date) && t.date <= now {
                if let from = t.currencyRecord { total += CurrencyService.shared.convert(amount: t.amount, from: from, to: currency, context: context) }
            }
            return OrbChartPoint(label: "\(index + 1)", amount: NSDecimalNumber(decimal: total).doubleValue, date: date)
        }
    }
    var body: some View {
        let current = points(monthOffset: 0), previous = points(monthOffset: -1)
        let symbol = currency?.displaySymbol ?? "€"
        let difference = (current.last?.amount ?? 0) - (previous.last?.amount ?? 0)
        VStack(alignment: .leading, spacing: 12) {
            Text("Confronto mensile").font(.orbHeadline).lineLimit(1)
            Text((difference <= 0 ? "↓ " : "↑ ") + OrbCurrency.string(difference, symbol: symbol))
                .font(.orbTitle2).monospacedDigit().foregroundStyle(difference <= 0 ? Color.orbPositive : Color.orbNegative)
            Text("rispetto al mese scorso").font(.orbCaption).foregroundStyle(Color.orbMuted)
            Chart {
                ForEach(previous) { point in
                    LineMark(x: .value("Giorno", Int(point.label) ?? 1), y: .value("Spesa", point.amount), series: .value("Mese", "Precedente"))
                        .foregroundStyle(Color.orbMuted).lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 4])).interpolationMethod(.monotone)
                }
                ForEach(current) { point in
                    LineMark(x: .value("Giorno", Int(point.label) ?? 1), y: .value("Spesa", point.amount), series: .value("Mese", "Corrente"))
                        .foregroundStyle(Color.chartExpense).lineStyle(StrokeStyle(lineWidth: 2.5)).interpolationMethod(.monotone)
                }
                if let last = current.last {
                    PointMark(x: .value("Giorno", Int(last.label) ?? 1), y: .value("Spesa", last.amount)).foregroundStyle(Color.chartExpense).symbolSize(50)
                        .annotation(position: .top, alignment: .trailing) { Text("Questo mese " + OrbCurrency.string(last.amount, symbol: symbol)).font(.orbCaption2) }
                }
                if let last = previous.last {
                    PointMark(x: .value("Giorno", Int(last.label) ?? 1), y: .value("Spesa", last.amount)).foregroundStyle(Color.orbMuted).symbolSize(35)
                        .annotation(position: .top, alignment: .trailing) { Text("Precedente " + OrbCurrency.string(last.amount, symbol: symbol)).font(.orbCaption2).foregroundStyle(Color.orbMuted) }
                }
            }.chartYAxis(.hidden).chartXAxis { AxisMarks(values: [1, 10, 20, 30]) }
                .chartPlotStyle { $0.modifier(OrbChartReveal(kind: .line)) }.frame(height: 170)
                .accessibilityChartDescriptor(OrbChartAccessibility(title: "Spesa cumulata del mese", points: current))
            OrbChartTable(title: "Questo mese", points: current, symbol: symbol)
            OrbChartTable(title: "Mese scorso", points: previous, symbol: symbol)
        }
    }
}
