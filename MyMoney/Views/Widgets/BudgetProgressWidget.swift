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

    // Ordina i budget dal più vicino al massimo (percentuale più alta)
    private var sortedBudgets: [Budget] {
        budgets.sorted { budget1, budget2 in
            let spent1 = budget1.spent(transactions: transactions, context: modelContext)
            let spent2 = budget2.spent(transactions: transactions, context: modelContext)

            let progress1 = budget1.amount > 0 ? Double(truncating: spent1 as NSDecimalNumber) / Double(truncating: budget1.amount as NSDecimalNumber) : 0
            let progress2 = budget2.amount > 0 ? Double(truncating: spent2 as NSDecimalNumber) / Double(truncating: budget2.amount as NSDecimalNumber) : 0

            return progress1 > progress2  // Più alto per primo
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Budget")
                    .font(.headline.bold())
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Spacer()

                NavigationLink(destination: BudgetListView()) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.cyan, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }

            if budgets.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)

                    Text("Nessun budget impostato")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    NavigationLink(destination: BudgetListView()) {
                        Text("Crea Budget")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue)
                            )
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                // ScrollView orizzontale con budget ordinati per percentuale
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(sortedBudgets) { budget in
                            BudgetProgressCard(budget: budget, transactions: transactions, allCurrencies: allCurrencies)
                                .frame(width: 100)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: .rect(cornerRadius: 16))
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
        if progress >= 1.0 { return .red }
        if progress >= 0.8 { return .orange }
        return .green
    }

    var body: some View {
        // Circular Progress - Compatto
        ZStack {
            // Background Circle
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                .frame(width: 90, height: 90)

            // Progress Circle
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    progressColor,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: 90, height: 90)
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.8, dampingFraction: 0.7), value: progress)

            // Center Content - Solo icona, percentuale e nome
            VStack(spacing: 1) {
                if let icon = budget.category?.icon {
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundStyle(budget.category?.color ?? .blue)
                }

                Text("\(Int(progress * 100))%")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(progressColor)

                Text(budget.category?.name ?? "Budget")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 70)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let currencyRecord = allCurrencies.first { $0.code == appSettings.preferredCurrencyEnum.rawValue }
        let symbol = currencyRecord?.displaySymbol ?? "$"
        let flag = currencyRecord?.flagEmoji ?? ""
        return "\(symbol)\(FormatterCache.formatCurrency(amount)) \(flag)"
    }
}
