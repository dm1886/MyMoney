//
//  HomeViewNew.swift
//  MoneyTracker
//
//  Created on 2026-01-27.
//

import SwiftUI
import SwiftData

struct HomeViewNew: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appSettings) var appSettings
    @Bindable var widgetManager = WidgetManager.shared
    @State private var showingAddWidget = false
    @State private var editMode: EditMode = .inactive

    // Centralized queries to avoid duplicate queries in each widget
    @Query private var transactions: [Transaction]
    @Query private var accounts: [Account]
    @Query private var categories: [Category]
    @Query private var allCurrencies: [CurrencyRecord]
    @Query private var exchangeRates: [ExchangeRate]
    @Query private var budgets: [Budget]

    var body: some View {
        NavigationStack {
            List {
                // Header Section
                VStack(spacing: 8) {
                    Text("Benvenuto in")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    Text("MoneyTracker")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                // Widgets Section
                if widgetManager.widgets.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "square.grid.3x3.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)

                        Text("Personalizza la tua Home")
                            .font(.title2.bold())
                            .foregroundStyle(.primary)

                        Text("Aggiungi widget per vedere statistiche, grafici e informazioni importanti")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)

                        Button {
                            showingAddWidget = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Aggiungi Widget")
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(appSettings.accentColor)
                            )
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    ForEach($widgetManager.widgets) { $widget in
                        let widgetIndex = widgetManager.widgets.firstIndex(where: { $0.id == widget.id }) ?? 0

                        HStack(spacing: 0) {
                            if editMode == .active {
                                Button {
                                    withAnimation {
                                        widgetManager.removeWidget(widget)
                                    }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(.red)
                                }
                                .padding(.trailing, 8)
                                .transition(.scale.combined(with: .opacity))
                            }

                            // Wrap each widget with AsyncWidgetWrapper
                            // Stagger loading with 50ms delay per widget
                            AsyncWidgetWrapper(delayMilliseconds: UInt64(widgetIndex * 50)) {
                                widgetView(for: widget)
                            }
                            .opacity(editMode == .active ? 0.8 : 1.0)
                            .id(widget.id)
                            .onLongPressGesture(minimumDuration: 0.5) {
                                withAnimation(.spring(response: 0.3)) {
                                    editMode = .active
                                }
                                HapticManager.shared.medium()
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .contextMenu {
                            Button(role: .destructive) {
                                withAnimation {
                                    widgetManager.removeWidget(widget)
                                }
                            } label: {
                                Label("Rimuovi", systemImage: "trash")
                            }
                        }
                    }
                    .onMove { source, destination in
                        withAnimation {
                            widgetManager.moveWidget(from: source, to: destination)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            widgetManager.removeWidget(widgetManager.widgets[index])
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .environment(\.editMode, $editMode)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if editMode == .active {
                        Button("Fine") {
                            withAnimation {
                                editMode = .inactive
                            }
                            HapticManager.shared.success()
                        }
                        .foregroundStyle(appSettings.accentColor)
                        .fontWeight(.semibold)
                    } else {
                        Button {
                            showingAddWidget = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(appSettings.accentColor)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddWidget) {
                AddWidgetSheet()
            }
        }
    }

    @ViewBuilder
    private func widgetView(for widget: WidgetModel) -> some View {
        switch widget.type {
        case .totalBalance:
            TotalBalanceWidget(accounts: accounts, allCurrencies: allCurrencies)
        case .todaySummary:
            TodaySummaryWidget(transactions: transactions, allCurrencies: allCurrencies)
        case .budgetProgress:
            BudgetProgressWidget(budgets: budgets, transactions: transactions, allCurrencies: allCurrencies)
        case .spendingByCategory:
            SpendingByCategoryWidget(transactions: transactions, categories: categories, allCurrencies: allCurrencies)
        case .quickStats:
            QuickStatsWidget(accounts: accounts, transactions: transactions)
        case .incomeVsExpenses:
            IncomeVsExpensesWidget(transactions: transactions, allCurrencies: allCurrencies, accounts: accounts)
        case .netWorthTrend:
            NetWorthTrendWidget(accounts: accounts, allCurrencies: allCurrencies)
        case .topCategories:
            TopCategoriesWidget(transactions: transactions, categories: categories, allCurrencies: allCurrencies)
        case .savingsRate:
            SavingsRateWidget(transactions: transactions, allCurrencies: allCurrencies)
        case .dailyAverage:
            DailyAverageWidget(transactions: transactions, allCurrencies: allCurrencies)
        case .monthlyComparison:
            MonthlyComparisonWidget(transactions: transactions, allCurrencies: allCurrencies)
        case .accountBalances:
            AccountBalancesWidget(accounts: accounts, allCurrencies: allCurrencies)
        case .recentTransactions:
            RecentTransactionsWidget(transactions: transactions, allCurrencies: allCurrencies)
        case .upcomingBills:
            UpcomingBillsWidget(transactions: transactions, allCurrencies: allCurrencies)
        case .dailyTrend:
            DailyTrendWidget(transactions: transactions, allCurrencies: allCurrencies)
        }
    }
}

#Preview {
    HomeViewNew()
        .environment(\.appSettings, AppSettings.shared)
        .modelContainer(for: [Account.self, Transaction.self, Category.self, CategoryGroup.self])
}
