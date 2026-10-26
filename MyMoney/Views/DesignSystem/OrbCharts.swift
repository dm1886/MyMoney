import SwiftUI
import Charts
import Accessibility

struct OrbChartPoint: Identifiable {
    var id: String { label }
    let label: String
    let amount: Double
    var second: Double = 0
    var date: Date? = nil
}

struct OrbChartAccessibility: AXChartDescriptorRepresentable {
    let title: String
    let points: [OrbChartPoint]
    var paired = false
    func makeChartDescriptor() -> AXChartDescriptor {
        let maximum = max(points.map { max($0.amount, $0.second) }.max() ?? 1, 1)
        let minimum = min(points.map(\.amount).min() ?? 0, 0)
        let x = AXCategoricalDataAxisDescriptor(title: "Periodo", categoryOrder: points.map(\.label))
        let y = AXNumericDataAxisDescriptor(title: "Importo", range: minimum...maximum, gridlinePositions: []) { FormatterCache.formatCurrencyFixed(Decimal($0)) }
        var series = [AXDataSeriesDescriptor(name: paired ? "Entrate" : title, isContinuous: false, dataPoints: points.map { AXDataPoint(x: $0.label, y: $0.amount) })]
        if paired { series.append(AXDataSeriesDescriptor(name: "Uscite", isContinuous: false, dataPoints: points.map { AXDataPoint(x: $0.label, y: $0.second) })) }
        return AXChartDescriptor(title: title, summary: nil, xAxis: x, yAxis: y, additionalAxes: [], series: series)
    }
    func updateChartDescriptor(_ descriptor: AXChartDescriptor) {
        let current = makeChartDescriptor()
        descriptor.title = current.title
        descriptor.xAxis = current.xAxis
        descriptor.yAxis = current.yAxis
        descriptor.series = current.series
    }
}

struct OrbChartTable: View {
    let title: String
    let points: [OrbChartPoint]
    let symbol: String
    var paired = false
    @State private var expanded = false
    var body: some View {
        DisclosureGroup("Vedi come tabella", isExpanded: $expanded) {
            ForEach(points) { point in
                HStack {
                    Text(point.label)
                    Spacer()
                    if paired {
                        VStack(alignment: .trailing) {
                            Text("↑ " + OrbCurrency.string(point.amount, symbol: symbol))
                            Text("↓ " + OrbCurrency.string(point.second, symbol: symbol))
                        }
                    } else { Text(OrbCurrency.string(point.amount, symbol: symbol)) }
                }.font(.orbCaption).monospacedDigit().padding(.vertical, 4)
            }
        }.font(.orbCaption).tint(Color.orbHighlight).accessibilityLabel(title + ", vedi come tabella")
    }
}

struct OrbColumnsChart: View {
    let points: [OrbChartPoint]
    let symbol: String
    var paired = false
    var title = "Spese"
    @Environment(\.theme) private var theme
    @Environment(\.orbMotionAllowed) private var motion
    @State private var selected: String?
    @State private var shown = false
    @State private var barProgress: [String: Double] = [:]
    private var fingerprint: String { points.map { "\($0.id):\($0.amount):\($0.second)" }.joined(separator: "|") }
    private var maximum: Double { max(points.map { max($0.amount, paired ? $0.second : 0) }.max() ?? 1, 1) * 1.15 }
    private var mean: Double { points.isEmpty ? 0 : points.reduce(0) { $0 + $1.amount } / Double(points.count) }
    private var active: OrbChartPoint? { points.first { $0.label == selected } }
    private var labels: [String] { points.enumerated().filter { $0.offset % max(1, Int(ceil(Double(points.count) / 5))) == 0 }.map { $0.element.label } }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if paired {
                HStack {
                    Label("↑ Entrate", systemImage: "square.fill").foregroundStyle(Color.chartIncome)
                    Label("↓ Uscite", systemImage: "square.fill").foregroundStyle(Color.chartExpense)
                }.font(.orbCaption)
            }
            if let active {
                Text(tooltip(active))
                    .font(.orbCaption).monospacedDigit().foregroundStyle(Color.orbText)
            }
            if points.allSatisfy({ $0.amount == 0 && (!paired || $0.second == 0) }) {
                Text("Nessuna operazione nel periodo").font(.orbSubheadline).foregroundStyle(Color.orbMuted).frame(maxWidth: .infinity, minHeight: 150)
            } else {
                columns

            }
            OrbChartTable(title: title, points: points, symbol: symbol, paired: paired)
        }
    }
    private func barHeight(_ point: OrbChartPoint) -> Double {
        if !paired, let date = point.date, date > Date(), point.amount == 0 { return maximum * 0.01875 }
        return point.amount
    }
    private func barColor(_ point: OrbChartPoint) -> Color {
        if paired { return .chartIncome }
        if let date = point.date, date > Date(), point.amount == 0 { return .chartGrid }
        if selected == point.label || point.date.map({ Calendar.current.isDateInToday($0) }) == true { return .chartExpense }
        return theme.chart.expSoft
    }
    private func tooltip(_ point: OrbChartPoint) -> String {
        var text = point.label + " · " + OrbCurrency.string(point.amount, symbol: symbol)
        if paired { text += " · ↓ " + OrbCurrency.string(point.second, symbol: symbol) }
        return text
    }
    private var columns: some View {
                Chart {
                    ForEach(points) { point in
                        BarMark(x: .value("Periodo", point.label), y: .value(paired ? "Entrate" : "Spese", barHeight(point) * (motion ? (barProgress[point.id] ?? 0) : 1)))
                            .foregroundStyle(barColor(point))
                            .position(by: .value("Serie", paired ? "Entrate" : "Spese"))
                            .cornerRadius(4)
                            .accessibilityLabel(point.label)
                            .accessibilityValue(OrbCurrency.string(point.amount, symbol: symbol))
                            .opacity(selected == nil || selected == point.label ? 1 : 0.35)

                        if paired {
                            BarMark(x: .value("Periodo", point.label), y: .value("Uscite", point.second * (motion ? (barProgress[point.id + "-expense"] ?? 0) : 1)))
                                .foregroundStyle(Color.chartExpense).position(by: .value("Serie", "Uscite")).cornerRadius(4)
                                .opacity(selected == nil || selected == point.label ? 1 : 0.35)
                        }
                    }
                    if !paired {
                        RuleMark(y: .value("Media", mean)).foregroundStyle(Color.orbMuted)
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                            .annotation(position: .top, alignment: .trailing) { Text("media").font(.orbCaption2).foregroundStyle(Color.orbMuted) }
                    }
                }
                .chartYAxis(.hidden).chartYScale(domain: 0...maximum)
                 .chartXAxis {
                    AxisMarks(values: labels) { value in
                        let label = value.as(String.self) ?? ""
                        AxisValueLabel(anchor: label == labels.first ? .topLeading : label == labels.last ? .topTrailing : .top) {
                            Text(label).font(.orbCaption2).fixedSize().foregroundStyle(Color.orbMuted)
                        }
                    }
                }
                .chartLegend(.hidden).chartXSelection(value: $selected)
                .frame(height: 160)
                .accessibilityChartDescriptor(OrbChartAccessibility(title: title, points: points, paired: paired))
                .onChange(of: selected) { HapticManager.shared.selectionFeedback() }
                .task(id: fingerprint) {
                    guard motion else { return }
                    // Keep completed entrances when a tab reappears; animate newly loaded periods.
                    let missing = points.filter { barProgress[$0.id] == nil }
                    for point in missing {
                        if Task.isCancelled { return }
                        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) { barProgress[point.id] = 1 }
                        try? await Task.sleep(for: .milliseconds(paired ? 40 : points.count > 10 ? 40 : 20))
                        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) { barProgress[point.id + "-expense"] = 1 }
                    }
                }
                .animation(motion ? .spring(response: 0.7, dampingFraction: 0.8) : .easeOut(duration: 0.2), value: points.map(\.amount))
    }

}

struct OrbAreaChart: View {
    let points: [OrbChartPoint]
    let symbol: String
    var title = "Patrimonio nel tempo"
    @Environment(\.theme) private var theme
    @State private var selected: String?
    private var active: OrbChartPoint? { points.first { $0.label == selected } ?? points.last }
    private var lower: Double { let v = points.map(\.amount).min() ?? 0; return v - max(abs(v) * 0.05, 1) }
    private var upper: Double { max((points.map(\.amount).max() ?? 0) + 1, lower + 1) }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let active { OrbAmountLabel(amount: Decimal(active.amount)) { OrbCurrency.string($0, symbol: symbol) }.font(.orb(25, weight: .bold)).monospacedDigit() }
            if points.isEmpty { Text("Nessun dato disponibile").foregroundStyle(Color.orbMuted) }
            else {
                Chart {
                    ForEach(points) { point in
                        AreaMark(x: .value("Periodo", point.label), yStart: .value("Minimo", lower), yEnd: .value("Patrimonio", point.amount))
                            .foregroundStyle(theme.chart.areaFill).interpolationMethod(.monotone)
                        LineMark(x: .value("Periodo", point.label), y: .value("Patrimonio", point.amount))
                            .foregroundStyle(Color.chartIncome).lineStyle(StrokeStyle(lineWidth: 2.5)).interpolationMethod(.monotone)
                    }
                    if let active {
                        if selected != nil { RuleMark(x: .value("Periodo", active.label)).foregroundStyle(Color.orbMuted) }
                        PointMark(x: .value("Periodo", active.label), y: .value("Patrimonio", active.amount)).foregroundStyle(Color.chartIncome)
                    }
                }.chartYScale(domain: lower...upper).chartYAxis(.hidden)
                    .chartXAxis { AxisMarks(values: points.enumerated().filter { $0.offset % max(1, Int(ceil(Double(points.count) / 5))) == 0 }.map { $0.element.label }) { _ in AxisValueLabel().foregroundStyle(Color.orbMuted) } }
                    .chartXSelection(value: $selected).frame(height: 160)
                    .chartPlotStyle { $0.modifier(OrbChartReveal(kind: .line)) }
                    .accessibilityChartDescriptor(OrbChartAccessibility(title: title, points: points))
                    .onChange(of: selected) { HapticManager.shared.selectionFeedback() }
                Text(selected.map { $0 + " · " + OrbCurrency.string(active?.amount ?? 0, symbol: symbol) } ?? "Minimo asse: " + OrbCurrency.string(lower, symbol: symbol))
                    .font(.orbCaption2).foregroundStyle(Color.orbMuted)
                OrbChartTable(title: title, points: points, symbol: symbol)
            }
        }
    }
}

struct OrbCategorySlice: Identifiable {
    let id: String
    let name: String
    let amount: Double
    let color: Color
}
struct OrbDonutChart: View {
    let slices: [OrbCategorySlice]
    let symbol: String
    @State private var selected: String?
    @State private var angle: Double?
    private var grouped: [OrbCategorySlice] {
        guard slices.count > 5 else { return slices }
        return Array(slices.prefix(5)) + [OrbCategorySlice(id: "other", name: "Altro", amount: slices.dropFirst(5).reduce(0) { $0 + $1.amount }, color: .chartOther)]
    }
    private var total: Double { slices.reduce(0) { $0 + $1.amount } }
    var body: some View {
        VStack(spacing: 12) {
            if total <= 0 { Text("Nessuna spesa nel periodo").font(.orbSubheadline).foregroundStyle(Color.orbMuted) }
            else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) { chart.frame(width: 150); legend.frame(minWidth: 130) }
                    VStack { chart; legend }
                }
                OrbChartTable(title: "Spese per categoria", points: slices.map { OrbChartPoint(label: $0.name, amount: $0.amount) }, symbol: symbol)
            }
        }
    }
    private var chart: some View {
        Chart(grouped) { slice in
            SectorMark(angle: .value("Importo", slice.amount), innerRadius: .ratio(0.62), outerRadius: .ratio(selected == slice.id ? 1 : 0.95), angularInset: 1.5)
                .cornerRadius(3).foregroundStyle(slice.color).opacity(selected == nil || selected == slice.id ? 1 : 0.4)
        }.frame(height: 165).chartLegend(.hidden).chartAngleSelection(value: $angle)
            .chartPlotStyle { $0.modifier(OrbChartReveal(kind: .pie)) }
            .overlay {
                let active = grouped.first { $0.id == selected }
                VStack(spacing: 3) {
                    Text(active?.name ?? "Totale").font(.orbCaption2).foregroundStyle(Color.orbMuted).lineLimit(1)
                    Text(OrbCurrency.string(active?.amount ?? total, symbol: symbol)).font(.orb(14, weight: .bold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
                }.frame(width: 88).allowsHitTesting(false)
            }
            .accessibilityChartDescriptor(OrbChartAccessibility(title: "Spese per categoria", points: grouped.map { OrbChartPoint(label: $0.name, amount: $0.amount) }))
            .onChange(of: angle) { _, value in
                guard let value else { selected = nil; return }
                var sum = 0.0
                for slice in grouped {
                    sum += slice.amount
                    if value <= sum { selected = slice.id; break }
                }
                HapticManager.shared.selectionFeedback()
            }
    }
    private var legend: some View {
        VStack(spacing: 9) {
            ForEach(Array(grouped.enumerated()), id: \.element.id) { index, slice in
                Button {
                    selected = selected == slice.id ? nil : slice.id
                    HapticManager.shared.selectionFeedback()
                } label: {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2).fill(slice.color).frame(width: 9, height: 9)
                        Text(slice.name).lineLimit(1)
                        Spacer(minLength: 4)
                        Text(FormatterCache.formatPercentage(slice.amount / max(total, 1) * 100)).monospacedDigit()
                    }.font(.orbCaption).foregroundStyle(Color.orbText)
                }.buttonStyle(.plain).riseIn(index)
            }
        }
    }
}

struct OrbRankedBars: View {
    let slices: [OrbCategorySlice]
    let symbol: String
    @Environment(\.orbMotionAllowed) private var motion
    @State private var shown = false
    var body: some View {
        VStack(spacing: 14) {
            ForEach(Array(slices.prefix(5).enumerated()), id: \.element.id) { index, slice in
                VStack(spacing: 6) {
                    HStack {
                        Text("\(index + 1)").font(.orbCaption).frame(width: 24, height: 24).background(Color.orbCard2, in: Circle())
                        Text(slice.name).lineLimit(1)
                        Spacer()
                        Text(OrbCurrency.string(slice.amount, symbol: symbol)).monospacedDigit()
                    }.font(.orbCaption)
                    GeometryReader { g in
                        Capsule().fill(Color.chartGrid)
                        Capsule().fill(slice.color).frame(width: g.size.width * (shown ? slice.amount / max(slices.first?.amount ?? 1, 1) : 0))
                            .animation(motion ? .easeOut(duration: 0.9).delay(Double(index) * 0.08) : nil, value: shown)
                    }.frame(height: 10)
                }.accessibilityElement(children: .combine)
            }
        }.onAppear { shown = true }
    }
}

struct OrbCompactPeriod<T: Hashable & RawRepresentable>: View where T.RawValue == String {
    let values: [T]
    @Binding var selection: T
    @Namespace private var ns
    @Environment(\.orbMotionAllowed) private var motion
    var body: some View {
        HStack(spacing: 0) {
            ForEach(values, id: \.self) { value in
                Button {
                    HapticManager.shared.selectionFeedback()
                    withAnimation(motion ? .spring(response: 0.35, dampingFraction: 0.8) : nil) { selection = value }
                } label: {
                    Text(value.rawValue).font(.orbCaption2).lineLimit(1).padding(.horizontal, 8).frame(height: 32)
                        .foregroundStyle(selection == value ? Color.orbText : Color.orbMuted)
                        .background { if selection == value { Capsule().fill(Color.orbCard).matchedGeometryEffect(id: "period", in: ns) } }
                }.buttonStyle(.plain).accessibilityAddTraits(selection == value ? .isSelected : [])
            }
        }.padding(2).background(Color.orbCard2, in: Capsule())
    }
}
