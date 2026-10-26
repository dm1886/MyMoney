//
//  BudgetProgressWidget.swift
//  MoneyTracker
//
//  Created on 2026-01-27.
//

import SwiftUI
import SwiftData

struct BudgetProgressWidget: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appSettings) var appSettings

    // PERFORMANCE: Accept data as parameters instead of @Query
    let budgets: [Budget]
    let transactions: [Transaction]
    let allCurrencies: [CurrencyRecord]

    @State private var adding = false

    // Ordina i budget dal più vicino al massimo (percentuale più alta)
    private var sortedBudgets: [Budget] {
        budgets.filter(\.isActive).sorted { budget1, budget2 in
            let spent1 = budget1.spent(transactions: transactions, context: modelContext)
            let spent2 = budget2.spent(transactions: transactions, context: modelContext)

            let progress1 = budget1.amount > 0 ? Double(truncating: spent1 as NSDecimalNumber) / Double(truncating: budget1.amount as NSDecimalNumber) : 0
            let progress2 = budget2.amount > 0 ? Double(truncating: spent2 as NSDecimalNumber) / Double(truncating: budget2.amount as NSDecimalNumber) : 0

            return progress1 > progress2  // Più alto per primo
        }
    }

    var body: some View {
        OrbCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Budget").font(.orbHeadline).lineLimit(1)
                    Spacer()
                    NavigationLink("Tutti", destination: BudgetListView()).font(.orbCaption)
                }
                ForEach(sortedBudgets.prefix(3)) { budget in
                    NavigationLink(destination: BudgetDetailView(budget: budget)) {
                        BudgetProgressCard(budget: budget, transactions: transactions, allCurrencies: allCurrencies)
                    }.buttonStyle(.plain)
                }
                if sortedBudgets.count < 2 {
                    Button { adding = true } label: {
                        Label("Nuovo budget", systemImage: "plus").font(.orbSubheadline)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orbLine, style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
                    }.buttonStyle(.plain)
                }
            }
        }.sheet(isPresented: $adding) { AddBudgetView() }
    }
}

struct BudgetProgressCard: View {
    let budget: Budget
    let transactions: [Transaction]
    let allCurrencies: [CurrencyRecord]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appSettings) var appSettings

    var spentAmount: Decimal {
        budget.spent(transactions: transactions, context: modelContext)
    }

    var progress: Double {
        guard budget.amount > 0 else { return 0 }
        return min(Double(truncating: spentAmount as NSDecimalNumber) / Double(truncating: budget.amount as NSDecimalNumber), 1.0)
    }

    var progressColor: Color {
        if progress >= 1.0 { return Color.orbNegative }
        if progress >= 0.8 { return Color.orbHighlight }
        return Color.orbPositive
    }

    var body: some View {
        let spent = budget.spent(transactions: transactions, context: modelContext)
        HStack(spacing: 12) {
            ProgressRing(progress: progress, color: budget.category?.color ?? .chartIncome).frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 5) {
                Text(budget.category?.name ?? "Budget").font(.orbHeadline)
                Text(OrbCurrency.string(spent, symbol: budget.currencyRecord?.displaySymbol ?? "€") + " / " + FormatterCache.formatCurrencyFixed(budget.amount)).font(.orbCaption).monospacedDigit()
                Text("Rimangono " + OrbCurrency.string(budget.amount - spent, symbol: budget.currencyRecord?.displaySymbol ?? "€")).font(.orbCaption).foregroundStyle(Color.orbMuted)
            }
            Spacer(minLength: 0)
        }.padding(8).modifier(OrbBudgetWarning(id: budget.id, progress: progress))
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let currencyRecord = allCurrencies.first { $0.code == appSettings.preferredCurrencyEnum.rawValue }
        let symbol = currencyRecord?.displaySymbol ?? "$"

        return "\(symbol) \(FormatterCache.formatCurrencyFixed(amount))"
    }
}
