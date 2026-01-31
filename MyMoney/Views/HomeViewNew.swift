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
    @State private var widgetManager = WidgetManager.shared
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
                    ForEach(widgetManager.widgets) { widget in
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

                            widgetView(for: widget)
                                .opacity(editMode == .active ? 0.8 : 1.0)
                                .id(widget.id)
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
                ToolbarItem(placement: .navigationBarLeading) {
                    if !widgetManager.widgets.isEmpty {
                        EditButton()
                            .foregroundStyle(appSettings.accentColor)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddWidget = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(appSettings.accentColor)
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
            TotalBalanceWidget()
        case .todaySummary:
            TodaySummaryWidget()
        case .budgetProgress:
            BudgetProgressWidget()
        case .spendingByCategory:
            SpendingByCategoryWidget()
        case .quickStats:
            QuickStatsWidget()
        case .incomeVsExpenses:
            IncomeVsExpensesWidget()
        case .netWorthTrend:
            NetWorthTrendWidget()
        case .topCategories:
            TopCategoriesWidget()
        case .savingsRate:
            SavingsRateWidget()
        case .dailyAverage:
            DailyAverageWidget()
        case .monthlyComparison:
            MonthlyComparisonWidget()
        case .accountBalances:
            AccountBalancesWidget()
        case .recentTransactions:
            RecentTransactionsWidget()
        case .upcomingBills:
            UpcomingBillsWidget()
        case .dailyTrend:
            DailyTrendWidget()
        }
    }
}

#Preview {
    HomeViewNew()
        .environment(\.appSettings, AppSettings.shared)
        .modelContainer(for: [Account.self, Transaction.self, Category.self, CategoryGroup.self])
}
