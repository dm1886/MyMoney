import XCTest
import SwiftData
@testable import MyMoney

@MainActor final class InvestmentTests: XCTestCase {
    private let stock = InvestmentInstrument(id: "XNAS:TEST", symbol: "TEST", name: "Test stock", exchange: "XNAS", currency: "EUR")
    private let start = Date(timeIntervalSince1970: 1_704_067_200) // 2024-01-01 UTC
    private func profile() -> InvestmentProfile {
        var p = InvestmentProfile(mode: .stocks, startDate: start)
        p.instruments = [stock]
        return p
    }
    private func day(_ n: Int) -> Date { start.addingTimeInterval(Double(n) * 86400) }
    func testProjectionWeightsAllocationsAndReconcilesWithoutIncome() throws {
        var projection = InvestmentProjection(initialValue: 10000, annualRate: 10)
        XCTAssertEqual(projection.value(at: start.addingTimeInterval(60), start: start), 10000)
        projection.allocations = [.init(date: day(182), amount: 2000)]
        let expected = Decimal(11000) + Decimal(2000) * (1 + Decimal(10) / 100 * Decimal(183) / 365)
        XCTAssertEqual(projection.value(at: day(365), start: start), expected)
        let confirmation = InvestmentProjection.Entry(date: day(365), amount: 12500)
        projection.confirmations = [confirmation]
        XCTAssertEqual(projection.result(at: confirmation), 500)
        XCTAssertEqual(projection.value(at: day(365), start: start), 12500)
        XCTAssertEqual(projection.value(at: day(730), start: start), 13750)
        var p = profile(); p.projection = projection
        XCTAssertEqual(p.cashAdjustment(at: day(365)), -2000)
        XCTAssertEqual(p.securitiesValue(at: day(365)), 12500)
        try p.validateStructure()
        let restored = try JSONDecoder().decode(InvestmentProfile.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(restored.projection?.confirmations.count, 1)
        XCTAssertEqual(restored.securitiesValue(at: day(365)), 12500)
    }
    func testNegativeProjectionZeroAndFutureReconciliation() throws {
        var p = InvestmentProjection(initialValue: 1000, annualRate: -20)
        XCTAssertEqual(p.value(at: day(365), start: start), 800)
        p.confirmations = [.init(date: day(500), amount: 600)]
        XCTAssertEqual(p.value(at: day(365), start: start), 800)
        p.confirmations = [.init(date: day(200), amount: 0)]
        XCTAssertEqual(p.value(at: day(365), start: start), 0)
        p.annualRate = -101
        XCTAssertThrowsError(try p.validate(start: start))
    }
    func testCreditAvailabilityExcludesBorrowingLimitFromWealth() {
        XCTAssertEqual(CreditCardMath.netBalance(available: 90000, limit: 60000), 30000)
        XCTAssertEqual(CreditCardMath.netBalance(available: 40000, limit: 60000), -20000)
        XCTAssertEqual(CreditCardMath.netBalance(available: 60000, limit: 60000), 0)
    }
    func testRecurringSuggestionsRequireDistinctDaysAndIgnoreGeneratedEntries() throws {
        let c = try container(), context = c.mainContext
        let account = Account(name: "Test", accountType: .payment, currency: .EUR)
        context.insert(account)
        var items: [Transaction] = []
        for offset in [1, 8, 15] {
            let t = Transaction(transactionType: .expense, amount: 20, currency: .EUR, date: Date().addingTimeInterval(-Double(offset) * 86400), notes: "Caffè", account: account)
            context.insert(t); items.append(t)
        }
        try context.save()
        XCTAssertEqual(RecurringSuggestions.find(in: items, type: .expense).count, 1)
        XCTAssertTrue(RecurringSuggestions.find(in: items, type: .income).isEmpty)
        items[0].parentRecurringTransactionId = UUID()
        XCTAssertTrue(RecurringSuggestions.find(in: items, type: .expense).isEmpty)
    }
    private func container() throws -> ModelContainer {
        let schema = Schema([Account.self, Transaction.self, Category.self, CategoryGroup.self, CurrencyRecord.self, ExchangeRate.self, Budget.self])
        return try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
    }
    func testBuySellDividendAndMarketValueNeverBecomeOrdinaryExpenses() throws {
        var p = profile()
        try p.record(InvestmentTrade(instrumentID: stock.id, kind: .buy, date: day(1), quantity: 10, price: 100, fees: 2), cashBeforeTrades: { _ in 2000 })
        p.quotes.append(InvestmentQuote(instrumentID: stock.id, price: 110, fxToAccount: 1, date: day(2), source: "Test"))
        XCTAssertEqual(p.cashAdjustment(at: day(2)), -1002)
        XCTAssertEqual(p.securitiesValue(at: day(2)), 1100)
        XCTAssertEqual(p.positions(at: day(2)).first?.unrealized, 98)
        try p.record(InvestmentTrade(instrumentID: stock.id, kind: .sell, date: day(3), quantity: 4, price: 120, fees: 1), cashBeforeTrades: { _ in 2000 })
        XCTAssertEqual(p.positions(at: day(3)).first?.quantity, 6)
        XCTAssertEqual(p.positions(at: day(3)).first?.cost, Decimal(string: "601.2"))
        XCTAssertEqual(p.positions(at: day(3)).first?.realized, Decimal(string: "78.2"))
        try p.record(InvestmentTrade(instrumentID: stock.id, kind: .dividend, date: day(4), quantity: 6, price: 2, fees: 1), cashBeforeTrades: { _ in 2000 })
        XCTAssertEqual(p.cashAdjustment(at: day(4)), -512)
        XCTAssertEqual(p.positions(at: day(4)).first?.dividends, 11)
    }
    func testCashAndSharesValidationIsAtomicIncludingBackdatedCorrections() throws {
        var p = profile()
        let buy = InvestmentTrade(instrumentID: stock.id, kind: .buy, date: day(1), quantity: 10, price: 100)
        try p.record(buy, cashBeforeTrades: { _ in 1000 })
        XCTAssertThrowsError(try p.record(InvestmentTrade(instrumentID: stock.id, kind: .buy, date: day(2), quantity: 1, price: 1), cashBeforeTrades: { _ in 1000 }))
        XCTAssertEqual(p.trades.count, 1)
        try p.record(InvestmentTrade(instrumentID: stock.id, kind: .sell, date: day(3), quantity: 10, price: 105), cashBeforeTrades: { _ in 1000 })
        var corrected = buy; corrected.quantity = 5
        XCTAssertThrowsError(try p.record(corrected, replacing: buy.id, cashBeforeTrades: { _ in 1000 }))
        XCTAssertEqual(p.trades.first?.quantity, 10)
    }
    func testOpeningSplitPreservesWealthAndDoesNotSpendCashTwice() throws {
        var p = profile(); p.openingCashReclassification = 800; p.unallocatedOpeningValue = 800
        XCTAssertEqual(1000 + p.cashAdjustment(at: start) + p.securitiesValue(at: start), 1000)
        try p.record(InvestmentTrade(instrumentID: stock.id, kind: .opening, date: start, quantity: 8, price: 100), cashBeforeTrades: { _ in 1000 })
        XCTAssertEqual(p.unallocatedOpeningValue, 0)
        XCTAssertEqual(1000 + p.cashAdjustment(at: day(1)), 200)
        XCTAssertEqual(1000 + p.cashAdjustment(at: day(1)) + p.securitiesValue(at: day(1)), 1000)
        XCTAssertThrowsError(try p.record(InvestmentTrade(instrumentID: stock.id, kind: .opening, date: start, quantity: 1, price: 100), cashBeforeTrades: { _ in 1000 }))
    }
    func testHistoricalValuationDoesNotUseFutureQuotes() throws {
        var p = profile()
        try p.record(InvestmentTrade(instrumentID: stock.id, kind: .buy, date: day(1), quantity: 2, price: 100), cashBeforeTrades: { _ in 1000 })
        p.quotes = [InvestmentQuote(instrumentID: stock.id, price: 200, fxToAccount: 1, date: day(5), source: "Test")]
        XCTAssertEqual(p.securitiesValue(at: day(2)), 200)
        XCTAssertEqual(p.securitiesValue(at: day(6)), 400)
    }
    func testForeignCurrencyPricesAndFeesUseAccountCurrency() throws {
        var p = profile()
        try p.record(InvestmentTrade(instrumentID: stock.id, kind: .buy, date: day(1), quantity: 10, price: 100, fxToAccount: Decimal(string: "0.9")!, fees: 2), cashBeforeTrades: { _ in 1000 })
        XCTAssertEqual(p.cashAdjustment(at: day(2)), -902)
        p.quotes.append(InvestmentQuote(instrumentID: stock.id, price: 110, fxToAccount: Decimal(string: "0.8")!, date: day(2), source: "Test"))
        XCTAssertEqual(p.securitiesValue(at: day(2)), 880)
        XCTAssertEqual(p.positions(at: day(2)).first?.unrealized, -22)
    }
    func testPACIsIdempotentAndReconciliationReplacesEstimate() throws {
        var p = profile()
        let plan = InvestmentPlan(instrumentID: stock.id, amount: 100, startDate: day(2))
        p.plans = [plan]
        p.quotes = [InvestmentQuote(instrumentID: stock.id, price: 10, fxToAccount: 1, date: day(1), source: "Test")]
        XCTAssertTrue(p.runPlans(at: day(2), cashBeforeTrades: { _ in 1000 }).isEmpty)
        _ = p.runPlans(at: day(2), cashBeforeTrades: { _ in 1000 })
        XCTAssertEqual(p.trades.count, 1); XCTAssertTrue(p.trades[0].isEstimated)
        var corrected = p.trades[0]; corrected.quantity = 9; corrected.price = 11; corrected.fees = 1; corrected.isEstimated = false
        try p.record(corrected, replacing: corrected.id, cashBeforeTrades: { _ in 1000 })
        _ = p.runPlans(at: day(2), cashBeforeTrades: { _ in 1000 })
        XCTAssertEqual(p.trades.count, 1); XCTAssertFalse(p.trades[0].isEstimated)
        XCTAssertEqual(p.trades[0].quantity, 9); XCTAssertEqual(p.cashAdjustment(at: day(2)), -100)
    }
    func testPACDoesNotInventMissingHistoricalQuoteOrOverdrawCash() {
        var p = profile()
        p.plans = [InvestmentPlan(instrumentID: stock.id, amount: 100, startDate: day(2))]
        p.quotes = [InvestmentQuote(instrumentID: stock.id, price: 10, fxToAccount: 1, date: day(3), source: "Test")]
        XCTAssertFalse(p.runPlans(at: day(3), cashBeforeTrades: { _ in 1000 }).isEmpty)
        XCTAssertTrue(p.trades.isEmpty)
        p.quotes[0].date = day(1)
        XCTAssertFalse(p.runPlans(at: day(3), cashBeforeTrades: { _ in 50 }).isEmpty)
        XCTAssertTrue(p.trades.isEmpty)
    }
    func testMonthlyAnchorDoesNotDriftAfterFebruary() throws {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let jan31 = cal.date(from: DateComponents(year: 2024, month: 1, day: 31, hour: 9))!
        let plan = InvestmentPlan(instrumentID: stock.id, amount: 100, startDate: jan31)
        let dates = plan.occurrences(through: cal.date(from: DateComponents(year: 2024, month: 4, day: 1))!, calendar: cal)
        XCTAssertEqual(dates.map { cal.component(.day, from: $0) }, [31, 29, 31])
    }
    func testSimpleInterestWeightsDepositsAndDoesNotCapitalize() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let accrued = InvestmentInterest.accrued(initialCash: 1000, flows: [InvestmentCashFlow(date: day(100), amount: 1000)], start: start, end: day(365), annualRate: 10, calendar: cal)
        let expected = Decimal(1000) * 100 * 10 / 36500 + Decimal(2000) * 265 * 10 / 36500
        XCTAssertEqual(accrued, expected)
        XCTAssertEqual(InvestmentInterest.accrued(initialCash: 1000, flows: [], start: start, end: day(730), annualRate: 10, calendar: cal), 200)
    }
    func testLedgerPersistenceBackupAndLegacyAccountIsolation() throws {
        let c = try container()
        let asset = Account(name: "Test portfolio", accountType: .asset, currency: .EUR, initialBalance: 1000)
        let legacy = Account(name: "Legacy", accountType: .asset, currency: .EUR, initialBalance: 500)
        c.mainContext.insert(asset); c.mainContext.insert(legacy); try c.mainContext.save()
        var p = profile()
        try p.record(InvestmentTrade(instrumentID: stock.id, kind: .buy, date: day(1), quantity: 2, price: 100), cashBeforeTrades: { _ in 1000 })
        try asset.saveInvestment(p, in: c.mainContext, requirePro: false)
        XCTAssertEqual(asset.currentBalance, 800); XCTAssertEqual(asset.investmentNetWorth, 1000)
        XCTAssertEqual(legacy.currentBalance, 500); XCTAssertNil(legacy.investmentData)
        XCTAssertTrue(try c.mainContext.fetch(FetchDescriptor<Transaction>()).isEmpty)
        asset.updateBalance(context: c.mainContext); XCTAssertEqual(asset.currentBalance, 800)
        let data = try BackupManager.shared.createBackup(accounts: [asset, legacy], transactions: [], categories: [], categoryGroups: [], currencyRecords: [], exchangeRates: [])
        let restored = try container()
        _ = try BackupManager.shared.restoreBackup(from: data, modelContext: restored.mainContext)
        let accounts = try restored.mainContext.fetch(FetchDescriptor<Account>())
        let result = try XCTUnwrap(accounts.first { $0.name == asset.name })
        XCTAssertEqual(result.investmentProfile?.trades.count, 1)
        XCTAssertEqual(result.investmentNetWorth, 1000)
        XCTAssertEqual(result.currentBalance, 800)
    }
    func testCorruptInvestmentBackupIsRejectedBeforeDeletingExistingAccounts() throws {
        let c = try container()
        let account = Account(name: "Keep", accountType: .asset, currency: .EUR, initialBalance: 100)
        account.investmentData = Data("invalid".utf8)
        c.mainContext.insert(account); try c.mainContext.save()
        let data = try BackupManager.shared.createBackup(accounts: [account], transactions: [], categories: [], categoryGroups: [], currencyRecords: [], exchangeRates: [])
        XCTAssertThrowsError(try BackupManager.shared.restoreBackup(from: data, modelContext: c.mainContext))
        XCTAssertEqual(try c.mainContext.fetch(FetchDescriptor<Account>()).count, 1)
        XCTAssertEqual(account.currentBalance, 100)
    }
    func testOpeningMarketValueIsIndependentOfHistoricalCost() throws {
        var p = profile(); p.unallocatedOpeningValue = 2000
        let opening = InvestmentTrade(instrumentID: stock.id, kind: .opening, date: start, quantity: 10, price: 150, openingAllocatedValue: 2000)
        try p.record(opening, cashBeforeTrades: { _ in 500 })
        XCTAssertEqual(p.unallocatedOpeningValue, 0)
        XCTAssertEqual(p.securitiesValue(at: day(1)), 2000)
        XCTAssertEqual(p.positions(at: day(1)).first?.cost, 1500)
        XCTAssertEqual(p.positions(at: day(1)).first?.unrealized, 500)
        XCTAssertEqual(p.cashAdjustment(at: day(1)), 0)
    }
    func testInterestCreditStopsDoubleCountingAndDeletionRestoresAccrual() throws {
        let c = try container()
        let account = Account(name: "Interest", accountType: .asset, currency: .EUR, initialBalance: 1000)
        account.createdAt = start
        c.mainContext.insert(account)
        let credit = Transaction(transactionType: .income, amount: 100, currency: .EUR, date: day(365), account: account)
        c.mainContext.insert(credit); try c.mainContext.save()
        var p = InvestmentProfile(mode: .simple, startDate: start, annualRate: 10)
        p.interestCreditIDs = [credit.id]
        try account.saveInvestment(p, in: c.mainContext)
        XCTAssertEqual(account.investmentValue(profile: p, at: day(365)), 1100)
        credit.status = .cancelled
        XCTAssertEqual(account.investmentValue(profile: p, at: day(365)), 1100) // 1000 principal + 100 accrued, no cash credit.
        credit.status = .executed
        let backup = try BackupManager.shared.createBackup(accounts: [account], transactions: [credit], categories: [], categoryGroups: [], currencyRecords: [], exchangeRates: [])
        let destination = try container()
        _ = try BackupManager.shared.restoreBackup(from: backup, modelContext: destination.mainContext)
        let restored = try XCTUnwrap(destination.mainContext.fetch(FetchDescriptor<Account>()).first)
        let rp = try XCTUnwrap(restored.investmentProfile)
        XCTAssertEqual(restored.investmentValue(profile: rp, at: day(365)), 1100)
        XCTAssertEqual(rp.interestCreditIDs?.first, restored.transactions?.first?.id)
    }
    func testOneTimePlanAndInvalidProfile() throws {
        let plan = InvestmentPlan(instrumentID: stock.id, amount: 100, startDate: day(2), repeats: false)
        XCTAssertEqual(plan.occurrences(through: day(365)).count, 1)
        var invalid = profile(); invalid.unallocatedOpeningValue = -1
        XCTAssertThrowsError(try invalid.validateStructure())
    }
    func testAccountsOnlyBackupPreservesInvestmentFundingAndFutureBalanceUpdates() throws {
        let source = try container()
        let account = Account(name: "Snapshot", accountType: .asset, currency: .EUR, initialBalance: 1000)
        source.mainContext.insert(account)
        let deposit = Transaction(transactionType: .income, amount: 500, currency: .EUR, date: day(1), account: account)
        source.mainContext.insert(deposit); try source.mainContext.save()
        var p = profile()
        try p.record(InvestmentTrade(instrumentID: stock.id, kind: .buy, date: day(2), quantity: 10, price: 100), cashBeforeTrades: account.investmentCashBeforeTrades)
        try account.saveInvestment(p, in: source.mainContext, requirePro: false)
        let data = try BackupManager.shared.createBackup(accounts: [account], transactions: [deposit], categories: [], categoryGroups: [], currencyRecords: [], exchangeRates: [], option: .accountsOnly)
        let destination = try container()
        _ = try BackupManager.shared.restoreBackup(from: data, modelContext: destination.mainContext)
        let restored = try XCTUnwrap(destination.mainContext.fetch(FetchDescriptor<Account>()).first)
        XCTAssertTrue(try destination.mainContext.fetch(FetchDescriptor<Transaction>()).isEmpty)
        restored.updateBalance(context: destination.mainContext)
        XCTAssertEqual(restored.currentBalance, 500); XCTAssertEqual(restored.investmentNetWorth, 1500)
        let expense = Transaction(transactionType: .expense, amount: 10, currency: .EUR, account: restored)
        destination.mainContext.insert(expense); try destination.mainContext.save()
        restored.updateBalance(context: destination.mainContext)
        XCTAssertEqual(restored.currentBalance, 490); XCTAssertEqual(restored.investmentNetWorth, 1490)
    }
    func testStocksRequireEntitlementButSimpleActivityIsFree() throws {
        let c = try container()
        let account = Account(name: "Free", accountType: .asset, currency: .EUR, initialBalance: 1000)
        c.mainContext.insert(account)
        try account.saveInvestment(InvestmentProfile(mode: .simple, startDate: Date(), annualRate: 3), in: c.mainContext)
        if !InvestmentAccess.shared.hasAccess {
            XCTAssertThrowsError(try account.saveInvestment(profile(), in: c.mainContext))
            XCTAssertEqual(account.investmentProfile?.mode, .simple)
        }
    }
    func testNumericalInputRejectsAmbiguousAndInvalidValues() {
        XCTAssertEqual(InvestmentInput.decimal("1.234,56"), Decimal(string: "1234.56"))
        XCTAssertEqual(InvestmentInput.decimal("0.125"), Decimal(string: "0.125"))
        XCTAssertNil(InvestmentInput.decimal("abc")); XCTAssertNil(InvestmentInput.decimal("12,3,4"))
    }
}
