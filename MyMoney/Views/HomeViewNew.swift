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
    @State private var showingNewTransaction = false
    @State private var newTransactionType: TransactionType?
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
                VStack(alignment: .leading, spacing: 8) {
                    Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "it_IT"))))
                        .font(.orbCaption).foregroundStyle(Color.orbMuted)
                    HStack {
                        Text("Ciao Damiano").font(.orbTitle)
                        Spacer()
                        Button { showingAddWidget = true } label: {
                            Image(systemName: "slider.horizontal.3").font(.body.weight(.semibold))
                                .frame(width: 44, height: 44)
                                .background(Color.orbCard2, in: Circle())
                        }.accessibilityLabel("Personalizza Home")
                    }
                }
                .padding(.horizontal, 22).padding(.vertical, 12)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                // Widgets Section
                if widgetManager.widgets.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "square.grid.3x3.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(Color.orbMuted)

                        Text("Personalizza la tua Home")
                            .font(.orbTitle2.bold())
                            .foregroundStyle(Color.orbText)

                        Text("Aggiungi widget per vedere statistiche, grafici e informazioni importanti")
                            .font(.orbBody)
                            .foregroundStyle(Color.orbMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)

                        Button {
                            showingAddWidget = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Aggiungi Widget")
                            }
                            .font(.orbHeadline)
                            .foregroundStyle(Color.orbOnAccent)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.orbAccent)
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
                                        .font(.orbTitle2)
                                        .foregroundStyle(Color.orbNegative)
                                }
                                .padding(.trailing, 8)
                                .transition(.scale.combined(with: .opacity))
                            }

                            // Wrap each widget with AsyncWidgetWrapper
                            // Stagger loading with 50ms delay per widget
                            AsyncWidgetWrapper(delayMilliseconds: UInt64(widgetIndex * 50)) {
                                widgetView(for: widget)
                            }
                            .riseIn(widgetIndex)
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
            }.orbScreen()
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.orbBackground)
            .environment(\.editMode, $editMode)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
            .background(OrbTabReselect(tab: 0))
            .sheet(isPresented: $showingAddWidget) {
                AddWidgetSheet()
            }
        }
    }

    @ViewBuilder
    private func widgetView(for widget: WidgetModel) -> some View {
        switch widget.type {
        case .totalBalance:
            TotalBalanceWidget(accounts: accounts, allCurrencies: allCurrencies, transactions: transactions)
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
