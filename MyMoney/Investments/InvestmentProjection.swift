import Foundation

/// Portfolio-level tracking. Allocations move cash inside the account, never income.
struct InvestmentProjection: Codable {
    struct Entry: Codable, Identifiable {
        var id = UUID()
        var date: Date
        var amount: Decimal
    }
    var initialValue: Decimal
    var annualRate: Decimal
    var allocations: [Entry] = []
    var confirmations: [Entry] = []
    var reminderEnabled = false

    func value(at date: Date, start: Date) -> Decimal {
        guard date >= start else { return 0 }
        let last = confirmations.filter { $0.date <= date }.max { $0.date < $1.date }
        let anchor = last?.date ?? start
        let base = last?.amount ?? initialValue
        func growth(_ amount: Decimal, from: Date) -> Decimal {
            let calendar = Calendar.current
            let days = Decimal(max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: from), to: calendar.startOfDay(for: date)).day ?? 0))
            return amount * (1 + annualRate / 100 * days / 365)
        }
        let changes = allocations.filter { $0.date <= date && (last == nil ? $0.date >= anchor : $0.date > anchor) }
        return max(0, growth(base, from: anchor) + changes.reduce(0) { $0 + growth($1.amount, from: $1.date) })
    }
    func allocated(at date: Date) -> Decimal { allocations.filter { $0.date <= date }.reduce(0) { $0 + $1.amount } }
    func result(at confirmation: Entry) -> Decimal { confirmation.amount - initialValue - allocated(at: confirmation.date) }
    func validate(start: Date) throws {
        guard initialValue >= 0, annualRate >= -100, annualRate <= 100,
              confirmations.allSatisfy({ $0.amount >= 0 && $0.date >= start }),
              allocations.allSatisfy({ $0.date >= start }),
              Set(confirmations.map(\.date)).count == confirmations.count else { throw InvestmentError.corruptData }
    }
}
