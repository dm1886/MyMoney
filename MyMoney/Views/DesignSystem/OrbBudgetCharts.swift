import SwiftUI
import SwiftData

struct OrbBudgetRings: View {
    let budgets: [Budget]
    let transactions: [Transaction]
    @Environment(\.modelContext) private var context
    @Environment(\.orbMotionAllowed) private var motion
    @State private var shown = false
    private var active: [Budget] {
        Array(budgets.filter(\.isActive).sorted { progress($0) > progress($1) }.prefix(3))
    }
    private func progress(_ budget: Budget) -> Double {
        guard budget.amount > 0 else { return 0 }
        return NSDecimalNumber(decimal: budget.spent(transactions: transactions, context: context) / budget.amount).doubleValue
    }
    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                ForEach(Array(active.enumerated()), id: \.element.id) { index, budget in
                    Circle().stroke(Color.chartGrid, lineWidth: 16).padding(CGFloat(index) * 21)
                    Circle().trim(from: 0, to: shown ? min(max(progress(budget), 0), 1) : 0)
                        .stroke(budget.category?.color ?? .chartIncome, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                        .rotationEffect(.degrees(-90)).padding(CGFloat(index) * 21)
                        .animation(motion ? .easeOut(duration: 1.3).delay(Double(index) * 0.15) : nil, value: shown)
                    if progress(budget) > 1 {
                        Circle().trim(from: 0, to: min(progress(budget) - 1, 1)).stroke(Color.orbNegative, lineWidth: 3)
                            .rotationEffect(.degrees(-90)).padding(CGFloat(index) * 21 + 6)
                    }
                }
            }.frame(width: 140, height: 140).padding(8).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(active) { budget in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(budget.category?.name ?? "Budget").font(.orbHeadline).lineLimit(1)
                        Text("\(Int(progress(budget) * 100))% usato").font(.orbCaption).foregroundStyle(Color.orbMuted)
                        if progress(budget) > 1 { Label("Superato", systemImage: "xmark.circle").font(.orbCaption).foregroundStyle(Color.orbNegative) }
                    }
                }
            }
        }.onAppear { shown = true }
    }
}

struct OrbBudgetPace: View {
    let budget: Budget
    let spent: Decimal
    @Environment(\.orbMotionAllowed) private var motion
    @State private var shown = false
    private var used: Double { budget.amount > 0 ? NSDecimalNumber(decimal: spent / budget.amount).doubleValue : 0 }
    private var elapsed: Double { min(max(Date().timeIntervalSince(budget.currentPeriodStart) / max(budget.currentPeriodEnd.timeIntervalSince(budget.currentPeriodStart), 1), 0), 1) }
    private var status: (String, String, Color) {
        if used > 1 { return ("Superato", "xmark.circle", .chartExceeded) }
        if used > elapsed + 0.05 { return ("Sopra il ritmo", "exclamationmark.triangle", .chartWarning) }
        return ("In linea", "checkmark.circle", .chartOnTrack)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(budget.category?.name ?? "Budget").font(.orbCaption)
                Spacer()
                Label(status.0, systemImage: status.1).font(.orbCaption2).foregroundStyle(status.2)
            }
            GeometryReader { g in
                Capsule().fill(Color.chartGrid).frame(height: 12)
                Capsule().fill(budget.category?.color ?? .chartIncome).frame(width: g.size.width * (shown ? min(max(used, 0), 1) : 0), height: 12)
                Rectangle().fill(Color.orbText).frame(width: 3, height: 20).offset(x: min(g.size.width - 3, g.size.width * elapsed), y: -4)
            }.frame(height: 20)
            Text("\(Int(used * 100))% usato · \(Int(elapsed * 100))% del periodo").font(.orbCaption2).foregroundStyle(Color.orbMuted)
        }.accessibilityElement(children: .combine)
            .onAppear { withAnimation(motion ? .easeOut(duration: 0.9) : nil) { shown = true } }
    }
}
