//
//  QuickStatsWidget.swift
//  MoneyTracker
//
//  Created on 2026-01-27.
//

import SwiftUI
import SwiftData

struct QuickStatsWidget: View {
    @Environment(\.modelContext) private var modelContext

    // PERFORMANCE: Accept data as parameters instead of @Query
    let accounts: [Account]
    let transactions: [Transaction]

    var todayTransactions: [Transaction] {
        let tracker = DeletedTransactionTracker.shared
        return transactions.filter { transaction in
            guard !tracker.isDeleted(transaction.id) else { return false }
            guard transaction.modelContext != nil else { return false }
            return Calendar.current.isDateInToday(transaction.date) && transaction.status != .pending
        }
    }

    var overdueTransactions: Int {
        let now = Date()
        return transactions.filter { transaction in
            return transaction.isScheduled &&
                   transaction.status == .pending &&
                   !transaction.isAutomatic &&
                   transaction.date < now
        }.count
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.title3)
                    .foregroundStyle(.blue)

                Text("Statistiche")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            HStack(spacing: 12) {
                // Conti Attivi
                VStack(spacing: 8) {
                    Image(systemName: "creditcard.fill")
                        .font(.title)
                        .foregroundStyle(.blue)

                    Text("\(accounts.count)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text("Conti")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.1))
                )

                // Transazioni Oggi
                VStack(spacing: 8) {
                    Image(systemName: "list.bullet")
                        .font(.title)
                        .foregroundStyle(.green)

                    Text("\(todayTransactions.count)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text("Oggi")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.green.opacity(0.1))
                )

                // In Attesa (se presenti)
                if overdueTransactions > 0 {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title)
                            .foregroundStyle(.orange)

                        Text("\(overdueTransactions)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)

                        Text("Attesa")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.orange.opacity(0.1))
                    )
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: .rect(cornerRadius: 16))
    }
}

