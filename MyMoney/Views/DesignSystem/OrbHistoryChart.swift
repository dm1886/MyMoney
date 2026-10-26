import SwiftUI
import SwiftData

/// Read-only snapshots for the new chart, mirroring Saldo Storico's existing rules.
/// This never writes Account.currentBalance or replays transactions into the store.
enum OrbHistorySnapshot {
    static func balance(account: Account, transactions: [Transaction], at date: Date) -> Decimal {
        guard date >= account.createdAt else { return 0 }
        if let profile = account.investmentProfile { return account.investmentValue(profile: profile, at: date) }
        var balance = account.initialBalance
        for t in transactions {
            guard !DeletedTransactionTracker.shared.isDeleted(t.id), t.modelContext != nil, t.status == .executed, t.date <= date else { continue }
            if t.account?.id == account.id {
                switch t.transactionType {
                case .expense, .transfer: balance -= t.amount
                case .income, .adjustment: balance += t.amount
                case .liabilityPayment: balance -= t.amount + (t.interestAmount ?? 0)
                }
            } else if t.destinationAccount?.id == account.id && t.transactionType == .transfer {
                balance += t.destinationAmount ?? t.amount
            }
        }
        return balance
    }
}
struct OrbHistoryChart: View {
    let account: Account
    let transactions: [Transaction]
    let end: Date
    private var points: [OrbChartPoint] {
        let calendar = Calendar.current
        return (0..<6).reversed().map { offset in
            let month = calendar.date(byAdding: .month, value: -offset, to: end)!
            let date = min(end, calendar.dateInterval(of: .month, for: month)!.end.addingTimeInterval(-1))
            return OrbChartPoint(label: month.formatted(.dateTime.month(.abbreviated).locale(Locale(identifier: "it_IT"))), amount: NSDecimalNumber(decimal: OrbHistorySnapshot.balance(account: account, transactions: transactions, at: date)).doubleValue, date: date)
        }
    }
    var body: some View {
        OrbAreaChart(points: points, symbol: account.currencyRecord?.displaySymbol ?? account.currency.rawValue, title: "Saldo storico")
    }
}
