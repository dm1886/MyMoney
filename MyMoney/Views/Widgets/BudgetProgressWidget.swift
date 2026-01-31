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
    @Query private var budgets: [Budget]
    @Query private var transactions: [Transaction]

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
                let columns = [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ]

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(budgets.prefix(4)) { budget in
                        BudgetProgressCard(budget: budget)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        )
    }
}

struct BudgetProgressCard: View {
    let budget: Budget
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appSettings) var appSettings
    @Query private var transactions: [Transaction]

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
        VStack(spacing: 12) {
            // Circular Progress
            ZStack {
                // Background Circle
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                    .frame(width: 110, height: 110)

                // Progress Circle
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        progressColor,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 110, height: 110)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.8, dampingFraction: 0.7), value: progress)

                // Center Content
                VStack(spacing: 2) {
                    if let icon = budget.category?.icon {
                        Image(systemName: icon)
                            .font(.system(size: 24))
                            .foregroundStyle(budget.category?.color ?? .blue)
                    }

                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(progressColor)
                }
            }

            // Budget Info
            VStack(spacing: 4) {
                Text(budget.category?.name ?? "Categoria")
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(formatAmount(spentAmount))
                    .font(.caption)
                    .foregroundStyle(progressColor)

                Text("di \(formatAmount(budget.amount))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        let amountString = formatter.string(from: amount as NSDecimalNumber) ?? "0"
        return "\(appSettings.preferredCurrencyEnum.symbol)\(amountString)"
    }
}
