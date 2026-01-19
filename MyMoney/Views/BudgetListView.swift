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

    @State private var showingAddBudget = false
    @State private var selectedBudget: Budget?

    var activeBudgets: [Budget] {
        budgets.filter { $0.isActive }
    }

    var inactiveBudgets: [Budget] {
        budgets.filter { !$0.isActive }
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
                            .font(.title2)
                            .foregroundStyle(appSettings.accentColor)
                    }
                }
            }
            .sheet(isPresented: $showingAddBudget) {
                AddBudgetView()
            }
            .sheet(item: $selectedBudget) { budget in
                EditBudgetView(budget: budget)
            }
        }
    }

    // MARK: - Budgets List

    private var budgetsList: some View {
        List {
            if !activeBudgets.isEmpty {
                Section("Attivi") {
                    ForEach(activeBudgets) { budget in
                        budgetRow(budget)
                            .onTapGesture {
                                selectedBudget = budget
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deleteBudget(budget)
                                } label: {
                                    Label("Elimina", systemImage: "trash")
                                }

                                Button {
                                    toggleBudgetActive(budget)
                                } label: {
                                    Label("Disattiva", systemImage: "pause.circle")
                                }
                                .tint(.orange)
                            }
                    }
                }
            }

            if !inactiveBudgets.isEmpty {
                Section("Inattivi") {
                    ForEach(inactiveBudgets) { budget in
                        budgetRow(budget)
                            .opacity(0.6)
                            .onTapGesture {
                                selectedBudget = budget
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deleteBudget(budget)
                                } label: {
                                    Label("Elimina", systemImage: "trash")
                                }

                                Button {
                                    toggleBudgetActive(budget)
                                } label: {
                                    Label("Attiva", systemImage: "play.circle")
                                }
                                .tint(.green)
                            }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Budget Row

    private func budgetRow(_ budget: Budget) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
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
                                .font(.title3)
                        }

                        Text(category.name)
                            .font(.headline)
                    }
                } else {
                    Text("Senza Categoria")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Period badge
                Text(budget.period.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(appSettings.accentColor.opacity(0.15))
                    )
                    .foregroundStyle(appSettings.accentColor)
            }

            // Amount info
            let spent = budget.spent(transactions: transactions, context: modelContext)
            let remaining = budget.remaining(transactions: transactions, context: modelContext)
            let percentage = budget.percentageUsed(transactions: transactions, context: modelContext)
            let currencySymbol = budget.currencyRecord?.symbol ?? "€"

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Speso")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(currencySymbol)\(spent.formatted())")
                        .font(.subheadline.bold())
                        .foregroundStyle(progressColor(percentage: percentage))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Budget")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(currencySymbol)\(budget.amount.formatted())")
                        .font(.subheadline.bold())
                }
            }

            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(height: 8)

                        // Progress
                        RoundedRectangle(cornerRadius: 4)
                            .fill(progressColor(percentage: percentage))
                            .frame(width: min(CGFloat(percentage / 100.0) * geometry.size.width, geometry.size.width), height: 8)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("\(Int(percentage))% utilizzato")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    if remaining > 0 {
                        Text("Rimangono \(currencySymbol)\(remaining.formatted())")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Budget superato!")
                            .font(.caption.bold())
                            .foregroundStyle(.red)
                    }
                }
            }

            // Date range (if custom or has end date)
            if budget.period == .custom || budget.endDate != nil {
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(dateRangeText(budget))
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                .foregroundStyle(appSettings.accentColor.opacity(0.3))

            Text("Nessun Budget")
                .font(.title3.bold())
                .foregroundStyle(.primary)

            Text("Crea un budget per monitorare le tue spese per categoria")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                showingAddBudget = true
            } label: {
                Text("Crea Budget")
                    .font(.body.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(appSettings.accentColor)
                    )
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Helper Methods

    private func progressColor(percentage: Double) -> Color {
        if percentage >= 100 {
            return .red
        } else if percentage >= 80 {
            return .orange
        } else {
            return .green
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
