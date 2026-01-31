//
//  IncomeVsExpensesWidget.swift
//  MoneyTracker
//
//  Created on 2026-01-27.
//

import SwiftUI
import SwiftData
import Charts

struct IncomeVsExpensesWidget: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appSettings) var appSettings
    @Query private var transactions: [Transaction]
    @Query private var allCurrencies: [CurrencyRecord]
    @Query private var accounts: [Account]
    @State private var selectedAccountId: UUID?

    var preferredCurrencyRecord: CurrencyRecord? {
        allCurrencies.first { $0.code == appSettings.preferredCurrencyEnum.rawValue }
    }

    var monthlyData: [(month: String, income: Decimal, expenses: Decimal)] {
        guard let preferredCurrency = preferredCurrencyRecord else { return [] }

        let calendar = Calendar.current
        let now = Date()
        let tracker = DeletedTransactionTracker.shared

        var result: [(month: String, income: Decimal, expenses: Decimal)] = []

        for monthOffset in (0..<6).reversed() {
            guard let monthDate = calendar.date(byAdding: .month, value: -monthOffset, to: now),
                  let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate)),
                  let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: calendar.date(byAdding: .month, value: 1, to: startOfMonth)!) else { continue }

            // DEBUG: Stampa il range di date per questo mese
            let debugFormatter = DateFormatter()
            debugFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            debugFormatter.locale = Locale(identifier: "it_IT")
            #if DEBUG
            print("📊 [IncomeVsExpenses] Mese \(monthOffset): Range \(debugFormatter.string(from: startOfMonth)) - \(debugFormatter.string(from: endOfMonth))")
            #endif

            let monthTransactions = transactions.filter { transaction in
                guard !tracker.isDeleted(transaction.id) else { return false }
                guard transaction.modelContext != nil else { return false }

                // Filter by account if one is selected
                if let accountId = selectedAccountId {
                    guard transaction.account?.id == accountId else { return false }
                }

                let isInRange = transaction.date >= startOfMonth &&
                                transaction.date <= endOfMonth &&
                                transaction.status == .executed &&
                                (transaction.transactionType == .income || transaction.transactionType == .expense)

                // DEBUG: Stampa le transazioni trovate
                #if DEBUG
                if isInRange {
                    print("📊   ✅ Trans [\(transaction.transactionType == .income ? "ENTRATA" : "USCITA")]: \(transaction.amount) - \(transaction.notes) - Data: \(debugFormatter.string(from: transaction.date))")
                }
                #endif

                return isInRange
            }

            #if DEBUG
            print("📊 [IncomeVsExpenses] Totale transazioni trovate per questo mese: \(monthTransactions.count)")
            #endif

            var income: Decimal = 0
            var expenses: Decimal = 0

            for transaction in monthTransactions {
                guard let transactionCurrency = transaction.currencyRecord else { continue }

                let converted = CurrencyService.shared.convert(
                    amount: transaction.amount,
                    from: transactionCurrency,
                    to: preferredCurrency,
                    context: modelContext
                )

                if transaction.transactionType == .income {
                    income += converted
                } else {
                    expenses += converted
                }
            }

            let formatter = DateFormatter()
            formatter.dateFormat = "MMM"
            formatter.locale = Locale(identifier: "it_IT")

            let monthName = formatter.string(from: monthDate)
            result.append((month: monthName, income: income, expenses: expenses))

            #if DEBUG
            print("📊 [IncomeVsExpenses] RISULTATO \(monthName): Entrate=\(income), Uscite=\(expenses)")
            print("📊 ─────────────────────────────────────")
            #endif
        }

        #if DEBUG
        print("📊 [IncomeVsExpenses] RIEPILOGO FINALE:")
        for data in result {
            print("📊   \(data.month): Entrate=\(data.income), Uscite=\(data.expenses)")
        }
        #endif

        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.up.arrow.down.circle.fill")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .red],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Text("Entrate vs Uscite")
                    .font(.headline.bold())
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Spacer()

                Text("Ultimi 6 Mesi")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Menu {
                Button {
                    selectedAccountId = nil
                } label: {
                    Label("Tutti i Conti", systemImage: selectedAccountId == nil ? "checkmark" : "")
                }

                Divider()

                ForEach(accounts) { account in
                    Button {
                        selectedAccountId = account.id
                    } label: {
                        Label(account.name, systemImage: selectedAccountId == account.id ? "checkmark" : "")
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(selectedAccountId == nil ? "Tutti i Conti" : (accounts.first(where: { $0.id == selectedAccountId })?.name ?? "Tutti"))
                        .font(.caption)
                        .foregroundStyle(.blue)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.blue.opacity(0.1))
                )
            }

            if monthlyData.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)

                    Text("Nessun dato disponibile")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                Chart {
                    ForEach(monthlyData, id: \.month) { data in
                        BarMark(
                            x: .value("Month", data.month),
                            y: .value("Amount", Double(truncating: data.income as NSDecimalNumber))
                        )
                        .foregroundStyle(.green.gradient)
                        .position(by: .value("Type", "Entrate"))

                        BarMark(
                            x: .value("Month", data.month),
                            y: .value("Amount", Double(truncating: data.expenses as NSDecimalNumber))
                        )
                        .foregroundStyle(.red.gradient)
                        .position(by: .value("Type", "Uscite"))
                    }
                }
                .frame(height: 180)
                .chartLegend(position: .bottom, spacing: 8)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .drawingGroup() // Optimize rendering performance
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
