//
//  TodayView.swift
//  MoneyTracker
//
//  Created on 2026-01-01.
//

import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appSettings) var appSettings
    @Query private var transactions: [Transaction]
    @Query private var allCurrencies: [CurrencyRecord]
    @Query private var exchangeRates: [ExchangeRate]  // Per aggiornamenti reattivi

    @State private var showingAddTransaction = false
    @State private var selectedTransactionType: TransactionType?
    @State private var selectedDate = Date()  // Data attualmente visualizzata
    @State private var showingCalendar = false  // Mostra/nascondi calendario

    var todayTransactions: [Transaction] {
        transactions
            .filter { Calendar.current.isDateInToday($0.date) && $0.status != .pending }
            .sorted { $0.date > $1.date }
    }

    var scheduledForToday: [Transaction] {
        transactions
            .filter { transaction in
                guard let scheduledDate = transaction.scheduledDate else { return false }
                let isToday = Calendar.current.isDateInToday(scheduledDate)

                // Escludi i template ricorrenti (mostra solo istanze generate)
                let isRecurringTemplate = transaction.isRecurring && transaction.parentRecurringTransactionId == nil

                return transaction.isScheduled &&
                       transaction.status == .pending &&
                       isToday &&
                       !isRecurringTemplate
            }
            .sorted { ($0.scheduledDate ?? Date()) < ($1.scheduledDate ?? Date()) }
    }

    var preferredCurrencyRecord: CurrencyRecord? {
        allCurrencies.first { $0.code == appSettings.preferredCurrencyEnum.rawValue }
    }

    var todayExpenses: Decimal {
        _ = exchangeRates.count
        guard let preferredCurrency = preferredCurrencyRecord else { return 0 }

        return todayTransactions
            .filter { $0.transactionType == .expense }
            .reduce(0) { sum, transaction in
                guard let transactionCurrency = transaction.currencyRecord else { return sum }

                let convertedAmount = CurrencyService.shared.convert(
                    amount: transaction.amount,
                    from: transactionCurrency,
                    to: preferredCurrency,
                    context: modelContext
                )
                return sum + convertedAmount
            }
    }

    var todayIncome: Decimal {
        _ = exchangeRates.count
        guard let preferredCurrency = preferredCurrencyRecord else { return 0 }

        return todayTransactions
            .filter { $0.transactionType == .income }
            .reduce(0) { sum, transaction in
                guard let transactionCurrency = transaction.currencyRecord else { return sum }

                let convertedAmount = CurrencyService.shared.convert(
                    amount: transaction.amount,
                    from: transactionCurrency,
                    to: preferredCurrency,
                    context: modelContext
                )
                return sum + convertedAmount
            }
    }

    var dailyBalance: Decimal {
        todayIncome - todayExpenses
    }

    var body: some View {
        NavigationStack {
            List {
                // Summary Cards Section
                Section {
                    VStack(spacing: 12) {
                        Text(Date().formatted(date: .complete, time: .omitted))
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 16) {
                            DailySummaryCard(
                                title: "Entrate",
                                amount: todayIncome,
                                currency: appSettings.preferredCurrencyEnum,
                                color: .green
                            )

                            DailySummaryCard(
                                title: "Uscite",
                                amount: todayExpenses,
                                currency: appSettings.preferredCurrencyEnum,
                                color: .red
                            )
                        }

                        HStack {
                            Text("Bilancio Giornaliero")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Spacer()

                            Text(formatAmount(dailyBalance))
                                .font(.title3.bold())
                                .foregroundStyle(dailyBalance >= 0 ? .green : .red)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
                        )
                    }
                    .padding(.vertical, 8)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

                // Add Transaction Button Section
                Section {
                    Button {
                        showingAddTransaction = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)

                            Text("Nuova Transazione")
                                .font(.headline)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

                // Scheduled Transactions for Today Section
                if !scheduledForToday.isEmpty {
                    Section {
                        ForEach(scheduledForToday) { transaction in
                            VStack(spacing: 0) {
                                NavigationLink {
                                    EditTransactionView(transaction: transaction)
                                } label: {
                                    ScheduledTransactionRow(transaction: transaction)
                                }
                            }
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteTransaction(transaction)
                                } label: {
                                    Label("Elimina", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteTransaction(transaction)
                                } label: {
                                    Label("Elimina", systemImage: "trash")
                                }
                            }
                        }
                    } header: {
                        Text("Programmate per Oggi")
                            .font(.title2.bold())
                            .foregroundStyle(.orange)
                            .textCase(nil)
                    }
                    .headerProminence(.increased)
                }

                // Regular Transactions Section
                Section {
                    if todayTransactions.isEmpty && scheduledForToday.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "list.bullet.clipboard")
                                .font(.system(size: 50))
                                .foregroundStyle(.secondary)

                            Text("Nessuna transazione oggi")
                                .font(.headline)

                            Text("Tocca il pulsante sopra per aggiungere la tua prima transazione")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    } else if todayTransactions.isEmpty {
                        Text("Nessuna transazione eseguita oggi")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    } else {
                        ForEach(todayTransactions) { transaction in
                            NavigationLink {
                                EditTransactionView(transaction: transaction)
                            } label: {
                                TransactionRow(transaction: transaction)
                            }
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteTransaction(transaction)
                                } label: {
                                    Label("Elimina", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteTransaction(transaction)
                                } label: {
                                    Label("Elimina", systemImage: "trash")
                                }
                            }
                        }
                    }
                } header: {
                    Text("Transazioni Eseguite")
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                        .textCase(nil)
                }
                .headerProminence(.increased)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Oggi")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingAddTransaction) {
                TransactionTypeSelectionView(selectedType: $selectedTransactionType)
            }
            .sheet(item: $selectedTransactionType) { type in
                AddTransactionView(transactionType: type)
            }
        }
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2

        let amountString = formatter.string(from: amount as NSDecimalNumber) ?? "0.00"
        let prefix = amount >= 0 ? "+" : ""
        return "\(prefix)\(appSettings.preferredCurrencyEnum.symbol)\(amountString)"
    }

    private func deleteTransaction(_ transaction: Transaction) {
        // Cancel notification if transaction was scheduled
        if transaction.isScheduled {
            LocalNotificationManager.shared.cancelNotification(for: transaction)
        }

        // Delete transaction first
        modelContext.delete(transaction)

        // Then update account balance (without the deleted transaction)
        if let account = transaction.account {
            account.updateBalance(context: modelContext)
        }

        if let destinationAccount = transaction.destinationAccount {
            destinationAccount.updateBalance(context: modelContext)
        }

        // Save everything
        try? modelContext.save()
    }
}

struct DailySummaryCard: View {
    let title: String
    let amount: Decimal
    let currency: Currency
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(formatAmount(amount))
                .font(.title3.bold())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        )
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2

        let amountString = formatter.string(from: amount as NSDecimalNumber) ?? "0.00"
        return "\(currency.symbol)\(amountString)"
    }
}

extension TransactionType: Identifiable {
    var id: String { self.rawValue }
}

#Preview {
    TodayView()
        .environment(\.appSettings, AppSettings.shared)
        .modelContainer(for: [Account.self, Transaction.self, Category.self, CategoryGroup.self])
}
