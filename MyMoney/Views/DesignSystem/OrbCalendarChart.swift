import SwiftUI
import SwiftData

struct OrbCalendarChart: View {
    let transactions: [Transaction]
    let currency: CurrencyRecord?
    let month: Date
    @Environment(\.modelContext) private var context
    @Environment(\.theme) private var theme
    @Environment(\.orbMotionAllowed) private var motion
    @State private var shown = false
    private var days: [OrbChartPoint] {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .month, for: month)!.start
        return (0..<(calendar.range(of: .day, in: .month, for: month)?.count ?? 30)).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: start)!
            var amount: Decimal = 0
            for t in transactions where t.status == .executed && t.transactionType == .expense && calendar.isDate(t.date, inSameDayAs: date) {
                guard let from = t.currencyRecord, let currency else { continue }
                amount += CurrencyService.shared.convert(amount: t.amount, from: from, to: currency, context: context)
            }
            return OrbChartPoint(label: "\(offset + 1)", amount: NSDecimalNumber(decimal: amount).doubleValue, date: date)
        }
    }
    private func level(_ amount: Double, positive: [Double]) -> Int {
        guard amount > 0, !positive.isEmpty else { return -1 }
        return min(4, positive.filter { $0 < amount }.count * 5 / positive.count)
    }
    var body: some View {
        let displayDays = days
        let positive = displayDays.map(\.amount).filter { $0 > 0 }.sorted()
        OrbCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Spesa per giorno").font(.orbHeadline).lineLimit(1)
                Text(month.formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "it_IT")))).font(.orbCaption).foregroundStyle(Color.orbMuted)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 7), spacing: 5) {
                    ForEach(Array(["L", "M", "M", "G", "V", "S", "D"].enumerated()), id: \.offset) { _, day in Text(day).font(.orbCaption2).foregroundStyle(Color.orbMuted) }
                    let offset = (Calendar.current.component(.weekday, from: displayDays.first?.date ?? month) + 5) % 7
                    ForEach(0..<offset, id: \.self) { _ in Color.clear.frame(height: 42) }
                    ForEach(Array(displayDays.enumerated()), id: \.element.id) { index, day in
                        let rank = level(day.amount, positive: positive)
                        let opacity = theme.chart.dark ? [0.22, 0.40, 0.60, 0.80, 1.0] : [0.15, 0.35, 0.55, 0.78, 1.0]
                        Button {
                            if let date = day.date { NotificationCenter.default.post(name: .orbShowDate, object: date) }
                        } label: {
                            Text(day.label).font(.orbCaption2).frame(maxWidth: .infinity, minHeight: 42, alignment: .topLeading).padding(4)
                                .foregroundStyle(rank >= 3 ? Color.white : Color.orbText)
                                .background(rank < 0 ? Color.clear : Color.chartIncome.opacity(opacity[max(rank, 0)]), in: RoundedRectangle(cornerRadius: 10))
                                .overlay { if rank < 0 { RoundedRectangle(cornerRadius: 10).stroke(Color.orbLine, style: StrokeStyle(lineWidth: 1, dash: [3, 3])) } }
                        }.buttonStyle(.plain).opacity(shown ? 1 : 0)
                            .animation(.easeOut(duration: 0.2).delay(motion ? Double(index) * 0.015 : 0), value: shown)
                            .accessibilityLabel(day.label + " · " + OrbCurrency.string(day.amount, symbol: currency?.displaySymbol ?? "€"))
                            .accessibilityHint("Apri Oggi su questa data")
                    }
                }
                HStack(spacing: 5) {
                    Text("meno")
                    ForEach(0..<5) { i in RoundedRectangle(cornerRadius: 3).fill(Color.chartIncome.opacity(Double(i + 1) / 5)).frame(width: 18, height: 12) }
                    Text("più")
                }.font(.orbCaption2).foregroundStyle(Color.orbMuted)
                OrbChartTable(title: "Spesa per giorno", points: displayDays, symbol: currency?.displaySymbol ?? "€")
            }
        }.onAppear { shown = true }
    }
}
