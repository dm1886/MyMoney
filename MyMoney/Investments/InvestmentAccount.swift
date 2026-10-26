import Foundation
import SwiftData

@MainActor
extension Account {
    var investmentProfile: InvestmentProfile? {
        guard accountType == .asset, let investmentData else { return nil }
        return try? JSONDecoder().decode(InvestmentProfile.self, from: investmentData)
    }
    var hasInvalidInvestmentData: Bool { investmentData != nil && investmentProfile == nil }
    var investmentNetWorth: Decimal {
        guard let profile = investmentProfile else { return currentBalance }
        return investmentValue(profile: profile, at: Date())
    }
    var investmentCashFlows: [InvestmentCashFlow] {
        let tracker = DeletedTransactionTracker.shared
        let all = (transactions ?? []) + (incomingTransfers ?? [])
        let live: [InvestmentCashFlow] = Dictionary(grouping: all, by: \.id).values.compactMap { list in
            guard let t = list.first, !tracker.isDeleted(t.id), t.modelContext != nil, t.status == .executed else { return nil }
            if t.account?.id == id {
                var value = t.amount
                if t.transactionType != .transfer {
                    if let destination = t.destinationAmount { value = destination }
                    else if let rate = t.exchangeRateSnapshot { value *= rate }
                    else if let from = t.currencyRecord, let to = currencyRecord, let context = modelContext, from.code != to.code {
                        value = CurrencyService.shared.convert(amount: value, from: from, to: to, context: context)
                    }
                }
                switch t.transactionType {
                case .expense, .transfer: value = -value
                case .liabilityPayment: value = -(value + (t.interestAmount ?? 0))
                case .income, .adjustment: break
                }
                return InvestmentCashFlow(date: t.date, amount: value)
            }
            if t.destinationAccount?.id == id && (t.transactionType == .transfer || t.transactionType == .liabilityPayment) {
                let value: Decimal
                if let amount = t.destinationAmount { value = amount }
                else if let rate = t.exchangeRateSnapshot { value = t.amount * rate }
                else if let from = t.currencyRecord, let to = currencyRecord, let context = modelContext, from.code != to.code {
                    value = CurrencyService.shared.convert(amount: t.amount, from: from, to: to, context: context)
                } else { value = t.amount }
                return InvestmentCashFlow(date: t.date, amount: value)
            }
            return nil
        }
        return (investmentProfile?.archivedExternalFlows ?? []) + live
    }
    func investmentCashBeforeTrades(at date: Date) -> Decimal {
        initialBalance + investmentCashFlows.filter { $0.date <= date }.reduce(0) { $0 + $1.amount }
    }
    func investmentValue(profile: InvestmentProfile, at date: Date) -> Decimal {
        let cash = investmentCashBeforeTrades(at: date)
        if profile.mode == .stocks { return cash + profile.cashAdjustment(at: date) + profile.securitiesValue(at: date) }
        let restart: Date
        if let ids = profile.interestCreditIDs {
            restart = (transactions ?? []).filter {
                !DeletedTransactionTracker.shared.isDeleted($0.id) && $0.modelContext != nil && ids.contains($0.id) && $0.status == .executed && $0.date <= date
            }.map(\.date).max() ?? profile.startDate
        } else { restart = profile.interestAccrualRestarts.filter { $0 <= date }.max() ?? profile.startDate }
        return cash + InvestmentInterest.accrued(initialCash: initialBalance, flows: investmentCashFlows,
                                                 start: restart, end: date, annualRate: profile.annualRate)
    }
    func saveInvestment(_ profile: InvestmentProfile, in context: ModelContext, requirePro: Bool = true) throws {
        guard !hasInvalidInvestmentData, profile.version == 1, accountType == .asset else { throw InvestmentError.corruptData }
        if profile.mode == .stocks && requirePro && !InvestmentAccess.shared.hasAccess { throw InvestmentError.proRequired }
        try profile.validateStructure()
        let previous = investmentData, previousBalance = currentBalance
        investmentData = try JSONEncoder().encode(profile)
        currentBalance = investmentCashBeforeTrades(at: Date()) + profile.cashAdjustment(at: Date())
        do { try context.save() }
        catch { investmentData = previous; currentBalance = previousBalance; throw error }
    }
}
