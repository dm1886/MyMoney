//
//  BudgetListView.swift
//  MoneyTracker
//
//  Created on 2026-01-08.
//

import SwiftUI
import SwiftData

struct BudgetListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appSettings) var appSettings
    @Query(sort: \Budget.createdAt, order: .reverse) private var budgets: [Budget]
    @Query private var transactions: [Transaction]
    @Query private var categories: [Category]

    @State private var selectedPeriod: BudgetPeriod? = nil
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var showingAddBudget = false
    @State private var budgetToEdit: Budget?

    var activeBudgets: [Budget] {
        budgets.filter { $0.isActive && (selectedPeriod == nil || $0.period == selectedPeriod) }
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "0.00"
    }

    var inactiveBudgets: [Budget] {
        budgets.filter { !$0.isActive && (selectedPeriod == nil || $0.period == selectedPeriod) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if budgets.isEmpty {
                    emptyStateView
                } else {
                    budgetsList
                }
            }
            .navigationTitle("Budget")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddBudget = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.orbTitle2)
                            .foregroundStyle(Color.orbHighlight)
                    }
                }
            }
            .sheet(isPresented: $showingAddBudget) {
                AddBudgetView()
            }
            .sheet(item: $budgetToEdit) { budget in
                EditBudgetView(budget: budget)
            }
        }
    }

    // MARK: - Budgets List

    private var budgetsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                OrbCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Progresso budget").font(.orbHeadline)
                        OrbBudgetRings(budgets: activeBudgets, transactions: transactions)
                    }
                }
                if !activeBudgets.isEmpty {
                    OrbCard {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Sei in linea?").font(.orbHeadline)
                            ForEach(activeBudgets) { budget in
                                OrbBudgetPace(budget: budget, spent: budget.spent(transactions: transactions, context: modelContext))
                            }
                        }
                    }
                }
                OrbSegmented(values: [nil] + BudgetPeriod.allCases.map(Optional.some), selection: $selectedPeriod) {
                    $0?.rawValue ?? "Tutti"
                }
                if activeBudgets.isEmpty && inactiveBudgets.isEmpty {
                    Text("Nessun budget per questo periodo").font(.orbSubheadline).foregroundStyle(Color.orbMuted)
                }
                if !activeBudgets.isEmpty {
                    OrbSectionHeader(title: "Attivi")
                    budgetGrid(activeBudgets)
                }
                if !inactiveBudgets.isEmpty {
                    OrbSectionHeader(title: "In pausa")
                    budgetGrid(inactiveBudgets)
                }
            }.padding(16)
        }.orbScreen()
    }

    private func budgetGrid(_ items: [Budget]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: textSize.isAccessibilitySize ? 1 : 2), spacing: 12) {
            ForEach(items) { budget in
                NavigationLink(destination: BudgetDetailView(budget: budget)) {
                    OrbCard {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                ProgressRing(progress: budget.percentageUsed(transactions: transactions, context: modelContext) / 100)
                                Spacer(minLength: 0)
                                Color.clear.frame(width: 44, height: 44)
                            }
                            budgetRow(budget)
                            if !budget.isActive { Text("In pausa").font(.orbCaption).foregroundStyle(Color.orbMuted) }
                        }
                    }
                    .overlay {
                        if budget.percentageUsed(transactions: transactions, context: modelContext) >= 90 {
                            RoundedRectangle(cornerRadius: 20).stroke(Color.orbNegative, lineWidth: 1)
                        }
                    }
                    .modifier(OrbBudgetWarning(id: budget.id, progress: budget.isActive ? budget.percentageUsed(transactions: transactions, context: modelContext) / 100 : 0))
                    .opacity(budget.isActive ? 1 : 0.55)
                }.buttonStyle(.plain)
                    .overlay(alignment: .topTrailing) {
                        Menu { budgetActions(budget) } label: {
                            Image(systemName: "ellipsis").frame(width: 44, height: 44)
                        }.accessibilityLabel("Azioni budget").padding(14)
                    }
                    .contextMenu { budgetActions(budget) }
            }
        }
    }

    @ViewBuilder private func budgetActions(_ budget: Budget) -> some View {
        Button("Modifica", systemImage: "pencil") { budgetToEdit = budget }
        Button("Elimina", systemImage: "trash", role: .destructive) { deleteBudget(budget) }
        Button(budget.isActive ? "Disattiva" : "Attiva", systemImage: budget.isActive ? "pause.circle" : "play.circle") {
            toggleBudgetActive(budget)
        }
    }

    // MARK: - Budget Row

    private func budgetRow(_ budget: Budget) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                // Category icon and name (custom image or SF Symbol)
                if let category = budget.category {
                    HStack(spacing: 8) {
                        if let imageData = category.imageData,
                           let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 28, height: 28)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: category.icon)
                                .foregroundStyle(category.color)
                                .font(.orbTitle3)
                        }

                        Text(category.name)
                            .font(.orbHeadline)
                    }
                } else {
                    Text("Senza Categoria")
                        .font(.orbHeadline)
                        .foregroundStyle(Color.orbMuted)
                }


                // Period badge
                Text(budget.period.rawValue)
                    .font(.orbCaption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.orbAccent.opacity(0.15))
                    )
                    .foregroundStyle(Color.orbHighlight)
            }

            // Amount info
            let spent = budget.spent(transactions: transactions, context: modelContext)
            let remaining = budget.remaining(transactions: transactions, context: modelContext)
            let percentage = budget.percentageUsed(transactions: transactions, context: modelContext)
            let currencySymbol = budget.currencyRecord?.symbol ?? "€"

            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Speso")
                        .font(.orbCaption)
                        .foregroundStyle(Color.orbMuted)
                    Text("\(currencySymbol) \(formatAmount(spent))")
                        .font(.orbSubheadline.bold())
                        .foregroundStyle(progressColor(percentage: percentage))
                }


                VStack(alignment: .leading, spacing: 4) {
                    Text("Budget")
                        .font(.orbCaption)
                        .foregroundStyle(Color.orbMuted)
                    Text("\(currencySymbol) \(formatAmount(budget.amount))")
                        .font(.orbSubheadline.bold())
                }
            }

            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                ProgressBarView(progress: percentage / 100)

                VStack(alignment: .leading, spacing: 6) {
                    Text("\(Int(percentage))% utilizzato")
                        .font(.orbCaption)
                        .foregroundStyle(Color.orbMuted)


                    if remaining > 0 {
                        Text("Rimangono \(currencySymbol) \(formatAmount(remaining))")
                            .font(.orbCaption)
                            .foregroundStyle(Color.orbMuted)
                    } else {
                        Text("Budget superato!")
                            .font(.orbCaption.bold())
                            .foregroundStyle(Color.orbNegative)
                    }
                }
            }

            // Date range (if custom or has end date)
            if budget.period == .custom || budget.endDate != nil {
                HStack {
                    Image(systemName: "calendar")
                        .font(.orbCaption)
                        .foregroundStyle(Color.orbMuted)

                    Text(dateRangeText(budget))
                        .font(.orbCaption)
                        .foregroundStyle(Color.orbMuted)
                }
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.pie")
                .font(.system(size: 60))
                .foregroundStyle(Color.orbAccent.opacity(0.3))

            Text("Nessun Budget")
                .font(.orbTitle3.bold())
                .foregroundStyle(Color.orbText)

            Text("Crea un budget per monitorare le tue spese per categoria")
                .font(.orbSubheadline)
                .foregroundStyle(Color.orbMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                showingAddBudget = true
            } label: {
                Text("Crea Budget")
                    .font(.orbBody.bold())
                    .foregroundStyle(Color.orbOnAccent)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.orbAccent)
                    )
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Helper Methods

    private func progressColor(percentage: Double) -> Color {
        if percentage >= 100 {
            return Color.orbNegative
        } else if percentage >= 80 {
            return Color.orbHighlight
        } else {
            return Color.orbPositive
        }
    }

    private func dateRangeText(_ budget: Budget) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short

        let start = formatter.string(from: budget.startDate)

        if let end = budget.endDate {
            let endStr = formatter.string(from: end)
            return "\(start) - \(endStr)"
        } else {
            return "Dal \(start)"
        }
    }

    private func deleteBudget(_ budget: Budget) {
        modelContext.delete(budget)
        try? modelContext.save()
    }

    private func toggleBudgetActive(_ budget: Budget) {
        budget.isActive.toggle()
        try? modelContext.save()
    }
}

#Preview {
    BudgetListView()
        .environment(\.appSettings, AppSettings.shared)
        .modelContainer(for: [Budget.self, Category.self, Transaction.self])
}
