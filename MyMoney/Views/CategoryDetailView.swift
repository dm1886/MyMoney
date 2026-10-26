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
                                .font(.orbTitle)
                                .foregroundStyle(category.color)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.name)
                            .font(.orbTitle2.bold())

                        if let group = category.categoryGroup {
                            Text(group.name)
                                .font(.orbSubheadline)
                                .foregroundStyle(Color.orbMuted)
                        }
                    }

                    Spacer()
                }
                .padding(.vertical, 8)
            }.listRowBackground(Color.orbCard)

            // Usage Statistics Section
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Utilizzi Totali")
                            .font(.orbCaption)
                            .foregroundStyle(Color.orbMuted)
                        Text("\(category.usageCount)")
                            .font(.orbTitle3.bold())
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Ultimi 30 Giorni")
                            .font(.orbCaption)
                            .foregroundStyle(Color.orbMuted)
                        Text("\(category.usageInLastDays(30))")
                            .font(.orbTitle3.bold())
                            .foregroundStyle(category.isRecurring ? Color.orbHighlight : Color.orbText)
                    }
                }

                if let lastUsed = category.lastUsedDate {
                    HStack {
                        Text("Ultimo Utilizzo")
                            .font(.orbCaption)
                            .foregroundStyle(Color.orbMuted)

                        Spacer()

                        Text(lastUsed, style: .relative)
                            .font(.orbCaption)
                            .foregroundStyle(Color.orbMuted)
                    }
                }

                if category.isRecurring {
                    HStack {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .foregroundStyle(Color.orbHighlight)
                        Text("Categoria Ricorrente")
                            .font(.orbSubheadline.bold())
                            .foregroundStyle(Color.orbHighlight)
                    }
                }
            } header: {
                Text("Statistiche Utilizzo")
            }.listRowBackground(Color.orbCard)

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
                                .foregroundStyle(Color.orbHighlight)
                            Text("Crea Budget per questa Categoria")
                                .foregroundStyle(Color.orbText)
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
            }.listRowBackground(Color.orbCard)

            // Spending Summary
            Section {
                HStack {
                    Text("Spesa Totale")
                        .font(.orbBody)

                    Spacer()

                    Text("€\(totalSpent.formatted())")
                        .font(.orbTitle3.bold())
                        .foregroundStyle(Color.orbHighlight)
                }

                HStack {
                    Text("Numero Transazioni")
                        .font(.orbBody)

                    Spacer()

                    Text("\(categoryTransactions.count)")
                        .font(.orbBody)
                        .foregroundStyle(Color.orbMuted)
                }
            } header: {
                Text("Riepilogo Spese")
            }.listRowBackground(Color.orbCard)

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
                                        .font(.orbSubheadline)

                                    if !transaction.notes.isEmpty {
                                        Text(transaction.notes)
                                            .font(.orbCaption)
                                            .foregroundStyle(Color.orbMuted)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()

                                Text(transaction.orbDisplayAmount)
                                    .font(.orbBody.bold())
                            }
                        }
                    }
                } header: {
                    Text("Transazioni Recenti")
                }.listRowBackground(Color.orbCard)
            }
        }.orbScreen()
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
                    .font(.orbCaption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.orbAccent.opacity(0.15))
                    )
                    .foregroundStyle(Color.orbHighlight)

                Spacer()

                Button {
                    selectedBudget = budget
                    showingEditBudget = true
                } label: {
                    Text("Modifica")
                        .font(.orbCaption)
                        .foregroundStyle(Color.orbHighlight)
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
                        .font(.orbCaption)
                        .foregroundStyle(Color.orbMuted)
                    Text("\(currencySymbol) \(spent.formatted())")
                        .font(.orbTitle3.bold())
                        .foregroundStyle(progressColor(percentage: percentage))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Budget")
                        .font(.orbCaption)
                        .foregroundStyle(Color.orbMuted)
                    Text("\(currencySymbol) \(budget.amount.formatted())")
                        .font(.orbTitle3.bold())
                }
            }

            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.orbCard2)
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(progressColor(percentage: percentage))
                            .frame(width: min(CGFloat(percentage / 100.0) * geometry.size.width, geometry.size.width), height: 8)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("\(Int(percentage))% utilizzato")
                        .font(.orbCaption)
                        .foregroundStyle(Color.orbMuted)

                    Spacer()

                    if remaining > 0 {
                        Text("Rimangono \(currencySymbol) \(remaining.formatted())")
                            .font(.orbCaption)
                            .foregroundStyle(Color.orbMuted)
                    } else {
                        Text("Budget superato!")
                            .font(.orbCaption.bold())
                            .foregroundStyle(Color.orbNegative)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func progressColor(percentage: Double) -> Color {
        if percentage >= 100 {
            return Color.orbNegative
        } else if percentage >= 80 {
            return Color.orbHighlight
        } else {
            return Color.orbPositive
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
