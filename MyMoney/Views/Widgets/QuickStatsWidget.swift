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
        OrbCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Statistiche rapide").font(.orbHeadline).lineLimit(1)
                HStack(spacing: 8) {
                    tile("Conti", count: accounts.count, icon: "creditcard.fill")
                    tile("Oggi", count: todayTransactions.count, icon: "list.bullet")
                    if overdueTransactions > 0 { tile("Attesa", count: overdueTransactions, icon: "clock") }
                }
            }
        }
    }
    private func tile(_ title: String, count: Int, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 16)).foregroundStyle(Color.orbHighlight)
                .frame(width: 36, height: 36).background(Color.orbCard2, in: Circle())
            Text("\(count)").font(.orbTitle2).monospacedDigit()
            Text(title).font(.orbCaption).foregroundStyle(Color.orbMuted)
        }.frame(maxWidth: .infinity)
    }
}

