import Foundation

// Decimal is retained throughout the ledger; Double is only used by charts.
enum AssetMode: String, Codable, CaseIterable, Identifiable {
    case simple, stocks
    var id: String { rawValue }
    var title: String { self == .simple ? "Attività semplice" : "Conto investimenti" }
}

struct InvestmentInstrument: Codable, Hashable, Identifiable {
    var id: String // Provider identifier includes the listing/exchange, not just the ticker.
    var symbol: String
    var name: String
    var isin: String?
    var exchange: String
    var currency: String
}

struct InvestmentQuote: Codable, Identifiable {
    var id: UUID = UUID()
    var instrumentID: String
    var price: Decimal
    var fxToAccount: Decimal
    var date: Date
    var source: String
    var isRealtime: Bool = false
    var valueInAccount: Decimal { price * fxToAccount }
}

enum InvestmentTradeKind: String, Codable, CaseIterable, Identifiable {
    case opening, buy, sell, dividend
    var id: String { rawValue }
    var title: String {
        switch self { case .opening: "Posizione iniziale"; case .buy: "Acquisto"; case .sell: "Vendita"; case .dividend: "Dividendo" }
    }
}

struct InvestmentTrade: Codable, Identifiable {
    var id: UUID = UUID()
    var instrumentID: String
    var kind: InvestmentTradeKind
    var date: Date
    var quantity: Decimal
    var price: Decimal
    var fxToAccount: Decimal = 1
    var fees: Decimal = 0 // Always in the account currency.
    var openingAllocatedValue: Decimal? // Market value at onboarding, independent of historical cost.
    var isEstimated: Bool = false
    var occurrenceID: String? // Stable plan/date key survives reconciliation and backup.
    var note: String = ""
    var cashDelta: Decimal {
        let gross = quantity * price * fxToAccount
        switch kind {
        case .opening: return 0
        case .buy: return -(gross + fees)
        case .sell, .dividend: return gross - fees
        }
    }
}

struct InvestmentPlan: Codable, Identifiable {
    var id: UUID = UUID()
    var instrumentID: String
    var amount: Decimal // Total cash budget including fees, in the account currency.
    var fees: Decimal = 0
    var startDate: Date
    var intervalMonths: Int = 1
    var repeats: Bool = true
    var endDate: Date?
    var automatic: Bool = true
    var notifications: Bool = true
    var isActive: Bool = true
    var pausedAt: Date?
    var skippedOccurrences: [String] = []

    func key(for date: Date) -> String { id.uuidString + ":" + String(Int(date.timeIntervalSince1970)) }
    // Each occurrence is derived from the original anchor: Jan 31 -> Feb 28 -> Mar 31.
    func occurrences(through end: Date, limit: Int = 1200, calendar: Calendar = .current) -> [Date] {
        guard isActive, intervalMonths > 0, end >= startDate else { return [] }
        if !repeats { return endDate.map({ startDate <= $0 }) ?? true ? [startDate] : [] }
        var result: [Date] = []
        for index in 0..<limit {
            guard let date = calendar.date(byAdding: .month, value: index * intervalMonths, to: startDate),
                  date <= end, endDate.map({ date <= $0 }) ?? true else { break }
            result.append(date)
        }
        return result
    }
}

struct InvestmentProfile: Codable {
    var projection: InvestmentProjection?
    var version: Int = 1
    var mode: AssetMode
    var startDate: Date
    var annualRate: Decimal = 0
    var interestAccrualRestarts: [Date] = []
    var interestCreditIDs: [UUID]?
    var archivedExternalFlows: [InvestmentCashFlow]?
    // Opening value not yet assigned to individual instruments. Never added to cash.
    var openingCashReclassification: Decimal = 0
    var unallocatedOpeningValue: Decimal = 0
    var instruments: [InvestmentInstrument] = []
    var trades: [InvestmentTrade] = []
    var quotes: [InvestmentQuote] = []
    var plans: [InvestmentPlan] = []

    func validateStructure() throws {
        if let projection {
            try projection.validate(start: startDate)
            guard mode == .stocks, trades.isEmpty, plans.isEmpty else { throw InvestmentError.corruptData }
        }
        guard version == 1, annualRate >= 0, annualRate <= 100, unallocatedOpeningValue >= 0, openingCashReclassification >= 0,
              Set(instruments.map(\.id)).count == instruments.count,
              Set(trades.map(\.id)).count == trades.count,
              Set(trades.compactMap(\.occurrenceID)).count == trades.compactMap(\.occurrenceID).count,
              Set(plans.map(\.id)).count == plans.count,
              trades.allSatisfy({ trade in trade.quantity > 0 && trade.price > 0 && trade.fxToAccount > 0 && trade.fees >= 0 && trade.date >= startDate && instruments.contains(where: { $0.id == trade.instrumentID }) }) else {
            throw InvestmentError.corruptData
        }
        for plan in plans {
            guard plan.amount > plan.fees, plan.fees >= 0, plan.intervalMonths > 0,
                  plan.startDate >= startDate, instruments.contains(where: { $0.id == plan.instrumentID }) else { throw InvestmentError.corruptData }
        }
    }
    func latestQuote(for id: String, at date: Date) -> InvestmentQuote? {
        quotes.filter { $0.instrumentID == id && $0.date <= date && $0.price > 0 && $0.fxToAccount > 0 }
            .max { $0.date < $1.date }
    }
    func cashAdjustment(at date: Date) -> Decimal {
        if let projection { return (date >= startDate ? -openingCashReclassification : 0) - projection.allocated(at: date) }
        return (date >= startDate ? -openingCashReclassification : 0) + trades.filter { $0.date <= date }.reduce(0) { $0 + $1.cashDelta }
    }
    func positions(at date: Date) -> [InvestmentPosition] {
        instruments.compactMap { instrument in
            let history = trades.filter { $0.instrumentID == instrument.id && $0.date <= date }.sorted { $0.date < $1.date }
            var quantity: Decimal = 0, cost: Decimal = 0, realized: Decimal = 0, dividends: Decimal = 0
            for trade in history {
                let gross = trade.quantity * trade.price * trade.fxToAccount
                switch trade.kind {
                case .opening, .buy: quantity += trade.quantity; cost += gross + trade.fees
                case .sell:
                    let removedCost = quantity > 0 ? cost * trade.quantity / quantity : 0
                    quantity -= trade.quantity; cost -= removedCost
                    realized += gross - trade.fees - removedCost
                case .dividend: dividends += gross - trade.fees
                }
            }
            let quote = latestQuote(for: instrument.id, at: date)
            let lastTrade = history.last { $0.kind != .dividend }
            let price = quote?.valueInAccount ?? lastTrade.map { trade in
                if trade.kind == .opening, let value = trade.openingAllocatedValue, trade.quantity > 0 { return value / trade.quantity }
                return trade.price * trade.fxToAccount
            } ?? 0
            guard !history.isEmpty else { return nil }
            return InvestmentPosition(instrument: instrument, quantity: quantity, cost: cost, marketValue: quantity * price,
                                      realized: realized, dividends: dividends, quote: quote, fallbackPrice: quote == nil)
        }
    }
    func securitiesValue(at date: Date) -> Decimal {
        if let projection { return projection.value(at: date, start: startDate) }
        guard date >= startDate else { return 0 }
        return unallocatedOpeningValue + positions(at: date).reduce(0) { $0 + $1.marketValue }
    }

    mutating func record(_ trade: InvestmentTrade, replacing id: UUID? = nil, cashBeforeTrades: (Date) -> Decimal) throws {
        guard mode == .stocks, instruments.contains(where: { $0.id == trade.instrumentID }),
              trade.quantity > 0, trade.price > 0, trade.fxToAccount > 0, trade.fees >= 0,
              trade.date >= startDate, trade.date <= Date() else { throw InvestmentError.invalidTrade }
        if let key = trade.occurrenceID, trades.contains(where: { $0.occurrenceID == key && $0.id != id }) {
            throw InvestmentError.duplicate
        }
        var candidate = self
        if let id {
            guard let old = candidate.trades.first(where: { $0.id == id }), old.kind != .opening else { throw InvestmentError.invalidTrade }
            candidate.trades.removeAll { $0.id == id }
        }
        if trade.kind == .opening {
            guard trade.date == startDate else { throw InvestmentError.invalidTrade }
            let allocated = trade.openingAllocatedValue ?? (trade.quantity * trade.price * trade.fxToAccount + trade.fees)
            guard allocated >= 0, allocated <= candidate.unallocatedOpeningValue else { throw InvestmentError.openingValue }
            candidate.unallocatedOpeningValue -= allocated
        }
        if let id, let index = trades.firstIndex(where: { $0.id == id }) {
            candidate.trades.insert(trade, at: min(index, candidate.trades.count))
        } else { candidate.trades.append(trade) }
        candidate.trades.sort { $0.date < $1.date }
        var cashDelta: Decimal = -candidate.openingCashReclassification
        var quantities: [String: Decimal] = [:]
        for item in candidate.trades {
            switch item.kind {
            case .opening, .buy: quantities[item.instrumentID, default: 0] += item.quantity
            case .sell: quantities[item.instrumentID, default: 0] -= item.quantity
            case .dividend: break
            }
            guard quantities[item.instrumentID, default: 0] >= 0 else { throw InvestmentError.insufficientShares }
            cashDelta += item.cashDelta
            guard cashBeforeTrades(item.date) + cashDelta >= -Decimal(string: "0.00000001")! else { throw InvestmentError.insufficientCash }
        }
        guard cashBeforeTrades(Date()) + candidate.cashAdjustment(at: Date()) >= -Decimal(string: "0.00000001")! else { throw InvestmentError.insufficientCash }
        self = candidate
    }

    mutating func runPlans(at now: Date, cashBeforeTrades: (Date) -> Decimal) -> [String] {
        var issues: [String] = []
        let due = plans.filter { $0.isActive && $0.automatic }.flatMap { plan in
            plan.occurrences(through: now).map { (plan, $0) }
        }.sorted { $0.1 < $1.1 }
        var blocked = Set<UUID>()
        for (plan, date) in due {
            if blocked.contains(plan.id) { continue }
            let key = plan.key(for: date)
            if plan.skippedOccurrences.contains(key) || trades.contains(where: { $0.occurrenceID == key }) { continue }
            guard let quote = latestQuote(for: plan.instrumentID, at: date), date.timeIntervalSince(quote.date) <= 4 * 86_400,
                  plan.amount > plan.fees else {
                issues.append("Quotazione storica mancante per il PAC del " + date.formatted(date: .abbreviated, time: .omitted))
                blocked.insert(plan.id); continue
            }
            var quantity = (plan.amount - plan.fees) / quote.valueInAccount
            var rounded = Decimal(); NSDecimalRound(&rounded, &quantity, 8, .down)
            let trade = InvestmentTrade(instrumentID: plan.instrumentID, kind: .buy, date: date, quantity: rounded,
                                        price: quote.price, fxToAccount: quote.fxToAccount, fees: plan.fees,
                                        isEstimated: true, occurrenceID: key, note: "PAC: prezzo stimato da " + quote.source)
            do { try record(trade, cashBeforeTrades: cashBeforeTrades) }
            catch { issues.append(error.localizedDescription); blocked.insert(plan.id) }
        }
        return issues
    }
}

struct InvestmentPosition: Identifiable {
    var id: String { instrument.id }
    var instrument: InvestmentInstrument
    var quantity: Decimal
    var cost: Decimal
    var marketValue: Decimal
    var realized: Decimal
    var dividends: Decimal
    var quote: InvestmentQuote?
    var fallbackPrice: Bool
    var unrealized: Decimal { marketValue - cost }
}

enum InvestmentError: LocalizedError {
    case invalidTrade, insufficientCash, insufficientShares, duplicate, openingValue, corruptData, proRequired, unavailable
    var errorDescription: String? {
        switch self {
        case .invalidTrade: "Controlla data, quantità, prezzo, cambio e commissioni. Le operazioni future vanno pianificate con un PAC."
        case .insufficientCash: "Liquidità insufficiente alla data dell'operazione. Registra prima il versamento effettivo."
        case .insufficientShares: "La vendita supera le quote disponibili, anche considerando le operazioni successive."
        case .duplicate: "Questa scadenza del piano è già stata registrata."
        case .openingValue: "La posizione supera il saldo investito ancora da dettagliare."
        case .corruptData: "I dati investimento non sono leggibili. Non verranno sovrascritti. Ripristina un backup valido."
        case .proRequired: "Il conto azioni richiede MyMoney Pro. I dati già salvati restano consultabili."
        case .unavailable: "Il servizio quotazioni non è ancora disponibile. Puoi registrare strumenti e prezzi manualmente."
        }
    }
}

struct InvestmentCashFlow: Codable {
    var date: Date
    var amount: Decimal
}

enum InvestmentInterest {
    // Gross simple interest, actual calendar days / 365, no capitalization or invented cash credit.
    static func accrued(initialCash: Decimal, flows: [InvestmentCashFlow], start: Date, end: Date, annualRate: Decimal, calendar: Calendar = .current) -> Decimal {
        let first = calendar.startOfDay(for: start), last = calendar.startOfDay(for: end)
        guard last > first, annualRate >= 0 else { return 0 }
        var principal = initialCash + flows.filter { $0.date < first }.reduce(0) { $0 + $1.amount }
        var cursor = first, sum: Decimal = 0
        for flow in flows.filter({ $0.date >= first && $0.date < last }).sorted(by: { $0.date < $1.date }) {
            let day = calendar.startOfDay(for: flow.date)
            sum += max(0, principal) * Decimal(calendar.dateComponents([.day], from: cursor, to: day).day ?? 0) * annualRate / 36500
            principal += flow.amount; cursor = day
        }
        sum += max(0, principal) * Decimal(calendar.dateComponents([.day], from: cursor, to: last).day ?? 0) * annualRate / 36500
        return sum
    }
}
