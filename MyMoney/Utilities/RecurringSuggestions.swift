import Foundation
import SwiftData

@MainActor enum RecurringSuggestions {
    struct Suggestion: Identifiable {
        let transaction: Transaction
        let count: Int
        var id: UUID { transaction.id }
    }
    static func find(in transactions: [Transaction], type: TransactionType) -> [Suggestion] {
        guard type == .expense || type == .income else { return [] }
        let cutoff = Calendar.current.date(byAdding: .month, value: -6, to: Date())!
        let eligible = transactions.filter {
            $0.modelContext != nil && !DeletedTransactionTracker.shared.isDeleted($0.id) &&
            $0.transactionType == type && $0.status == .executed && !$0.isRecurring &&
            $0.parentRecurringTransactionId == nil && $0.date >= cutoff && $0.date <= Date() && $0.account != nil
        }
        func key(_ t: Transaction) -> String {
            [t.transactionType.rawValue, t.account?.id.uuidString ?? "", t.category?.id.uuidString ?? "", t.currencyCode,
             NSDecimalNumber(decimal: t.amount).stringValue,
             t.notes.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()].joined(separator: "|")
        }
        let active = Set(transactions.filter { $0.modelContext != nil && !DeletedTransactionTracker.shared.isDeleted($0.id) && $0.isRecurring && $0.status != .cancelled }.map(key))
        return Dictionary(grouping: eligible, by: key).compactMap { key, values in
            let days = Set(values.map { Calendar.current.startOfDay(for: $0.date) })
            guard days.count >= 3, !active.contains(key), let last = values.max(by: { $0.date < $1.date }) else { return nil }
            return Suggestion(transaction: last, count: values.count)
        }.sorted { $0.transaction.date > $1.transaction.date }.prefix(3).map { $0 }
    }
}
