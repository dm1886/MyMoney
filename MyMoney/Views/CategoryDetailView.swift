//
//  CategoryDetailView.swift
//  MoneyTracker
//
//  Created on 2026-01-09.
//

import SwiftUI
import SwiftData

struct CategoryDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appSettings) var appSettings
    @Query private var transactions: [Transaction]

    let category: Category

    @State private var showingAddBudget = false
    @State private var showingEditBudget = false
    @State private var selectedBudget: Budget?

    var categoryTransactions: [Transaction] {
        transactions.filter {
            $0.category?.id == category.id && $0.status == .executed
        }.sorted { $0.date > $1.date }
    }

    var recentTransactions: [Transaction] {
        Array(categoryTransactions.prefix(10))
    }

    var totalSpent: Decimal {
        categoryTransactions.reduce(0) { $0 + $1.amount }
    }

    var activeBudget: Budget? {
        category.activeBudget
    }

    var body: some View {
        List {
            // Category Info Section
            Section {
                HStack {
                    // Category icon (custom image or SF Symbol)
                    if let imageData = category.imageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                    } else {
                        ZStack {
                            Circle()
                                .fill(category.color.opacity(0.15))
                                .frame(width: 60, height: 60)

                            Image(systemName: category.icon)
                                .font(.title)
                                .foregroundStyle(category.color)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.name)
                            .font(.title2.bold())

                        if let group = category.categoryGroup {
                            Text(group.name)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
                }
                .padding(.vertical, 8)
            }

            // Usage Statistics Section
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Utilizzi Totali")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(category.usageCount)")
                            .font(.title3.bold())
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Ultimi 30 Giorni")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(category.usageInLastDays(30))")
                            .font(.title3.bold())
                            .foregroundStyle(category.isRecurring ? .orange : .primary)
                    }
                }

                if let lastUsed = category.lastUsedDate {
                    HStack {
                        Text("Ultimo Utilizzo")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text(lastUsed, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if category.isRecurring {
                    HStack {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .foregroundStyle(.orange)
                        Text("Categoria Ricorrente")
                            .font(.subheadline.bold())
                            .foregroundStyle(.orange)
                    }
                }
            } header: {
                Text("Statistiche Utilizzo")
            }

            // Budget Section
            Section {
                if let budget = activeBudget {
                    budgetCard(budget)
                        .onTapGesture {
                            selectedBudget = budget
                            showingEditBudget = true
                        }
                } else {
                    Button {
                        showingAddBudget = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(appSettings.accentColor)
                            Text("Crea Budget per questa Categoria")
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                    }
                }
            } header: {
                Text("Budget")
            } footer: {
                if activeBudget == nil {
                    Text("Imposta un budget per monitorare le spese in questa categoria")
                }
            }

            // Spending Summary
            Section {
                HStack {
                    Text("Spesa Totale")
                        .font(.body)

                    Spacer()

                    Text("€\(totalSpent.formatted())")
                        .font(.title3.bold())
                        .foregroundStyle(appSettings.accentColor)
                }

                HStack {
                    Text("Numero Transazioni")
                        .font(.body)

                    Spacer()

                    Text("\(categoryTransactions.count)")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Riepilogo Spese")
            }

            // Recent Transactions
            if !recentTransactions.isEmpty {
                Section {
                    ForEach(recentTransactions) { transaction in
                        NavigationLink {
                            EditTransactionView(transaction: transaction)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.subheadline)

                                    if !transaction.notes.isEmpty {
                                        Text(transaction.notes)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()

                                Text(transaction.displayAmount)
                                    .font(.body.bold())
                            }
                        }
                    }
                } header: {
                    Text("Transazioni Recenti")
                }
            }
        }
        .navigationTitle("Dettagli Categoria")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddBudget) {
            AddBudgetViewForCategory(category: category)
        }
        .sheet(isPresented: $showingEditBudget) {
            if let budget = selectedBudget {
                EditBudgetView(budget: budget)
            }
        }
    }

    // MARK: - Budget Card

    @ViewBuilder
    private func budgetCard(_ budget: Budget) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(budget.period.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(appSettings.accentColor.opacity(0.15))
                    )
                    .foregroundStyle(appSettings.accentColor)

                Spacer()

                Button {
                    selectedBudget = budget
                    showingEditBudget = true
                } label: {
                    Text("Modifica")
                        .font(.caption)
                        .foregroundStyle(appSettings.accentColor)
                }
            }

            // Amount info
            let spent = budget.spent(transactions: categoryTransactions, context: modelContext)
            let remaining = budget.remaining(transactions: categoryTransactions, context: modelContext)
            let percentage = budget.percentageUsed(transactions: categoryTransactions, context: modelContext)
            let currencySymbol = budget.currencyRecord?.symbol ?? "€"

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Speso")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(currencySymbol)\(spent.formatted())")
                        .font(.title3.bold())
                        .foregroundStyle(progressColor(percentage: percentage))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Budget")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(currencySymbol)\(budget.amount.formatted())")
                        .font(.title3.bold())
                }
            }

            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(height: 8)

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
        }
        .padding(.vertical, 8)
    }

    private func progressColor(percentage: Double) -> Color {
        if percentage >= 100 {
            return .red
        } else if percentage >= 80 {
            return .orange
        } else {
            return .green
        }
    }
}

#Preview {
    NavigationStack {
        CategoryDetailView(category: Category(name: "Caffè", icon: "cup.and.saucer.fill", colorHex: "#A2845E"))
            .environment(\.appSettings, AppSettings.shared)
            .modelContainer(for: [Category.self, Transaction.self, Budget.self])
    }
}
