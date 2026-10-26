import XCTest
import SwiftData
import UIKit
@testable import MyMoney

@MainActor final class OrbRegressionTests: XCTestCase {
    private func container() throws -> ModelContainer {
        let schema = Schema([Account.self, Transaction.self, Category.self, CategoryGroup.self, CurrencyRecord.self, ExchangeRate.self, Budget.self])
        return try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    }

    func testChartRolePaletteMatchesGuideInBothAppearances() throws {
        let expected = [
            ("#6B4DFF", "#8B74FF", "#EB6834"),
            ("#079A88", "#1FA392", "#EB6834"),
            ("#2A78D6", "#4C8DFF", "#C2410C"),
            ("#2563EB", "#4C8DFF", "#EB6834"),
            ("#3B6EF5", "#5B8CFF", "#EB6834")
        ]
        for (theme, roles) in zip(ThemePresets.all, expected) {
            XCTAssertEqual(theme.light.chart.inc, roles.0)
            XCTAssertEqual(theme.dark.chart.inc, roles.1)
            XCTAssertEqual(theme.light.chart.exp, roles.2)
            XCTAssertEqual(theme.dark.chart.exp, "#E86A35")
            // chart is derived: backups written before the new roles still decode.
            let decoded = try JSONDecoder().decode(AppTheme.self, from: JSONEncoder().encode(theme))
            XCTAssertEqual(decoded.dark.chart.inc, theme.dark.chart.inc)
        }
        XCTAssertEqual(OrbCurrency.string(Decimal(string: "1234.56")!, symbol: "€"), "€ 1.234,56")
        XCTAssertEqual(OrbCurrency.string(Decimal(0), symbol: "HK$"), "HK$ 0,00")
    }

    func testHistoryChartSnapshotsDoNotMutateBalancesOrIncludePending() throws {
        let c = try container()
        let source = Account(name: "Origine", accountType: .payment, currency: .EUR, initialBalance: 1000)
        let destination = Account(name: "Destinazione", accountType: .cash, currency: .EUR)
        source.createdAt = .distantPast; destination.createdAt = .distantPast
        c.mainContext.insert(source); c.mainContext.insert(destination)
        let transfer = Transaction(transactionType: .transfer, amount: 100, currency: .EUR, account: source, destinationAccount: destination)
        transfer.destinationAmount = 120
        let pending = Transaction(transactionType: .expense, amount: 500, currency: .EUR, account: source)
        pending.status = .pending
        c.mainContext.insert(transfer); c.mainContext.insert(pending)
        try c.mainContext.save()
        let before = source.currentBalance
        XCTAssertEqual(OrbHistorySnapshot.balance(account: source, transactions: [transfer, pending], at: Date()), 900)
        XCTAssertEqual(OrbHistorySnapshot.balance(account: destination, transactions: [transfer, pending], at: Date()), 120)
        XCTAssertEqual(OrbHistorySnapshot.balance(account: source, transactions: [transfer, pending], at: transfer.date.addingTimeInterval(-1)), 1000)
        XCTAssertEqual(source.currentBalance, before)
    }

    func testAllPresetsRoundTripAndReadableText() throws {
        XCTAssertEqual(Set(ThemePresets.all.map(\.id)).count, 5)
        for theme in ThemePresets.all {
            XCTAssertEqual(try JSONDecoder().decode(AppTheme.self, from: JSONEncoder().encode(theme)), theme)
            for p in [theme.light, theme.dark] {
                XCTAssertGreaterThanOrEqual(ThemeFactory.contrast(p.tx, p.bg), 4.5, theme.name)
                XCTAssertGreaterThanOrEqual(ThemeFactory.contrast(p.mu, p.card), 4.5, theme.name)
                XCTAssertGreaterThanOrEqual(ThemeFactory.contrast(p.on, p.a1), 4.5, theme.name)
            }
        }
    }

    func testCustomThemeContrastCorrectionBothAppearances() {
        for hex in ["#FFFFFF", "#000000", "#FFFF00", "#07161A", "#F4F1FF"] {
            for tone in ThemeTone.allCases {
                let theme = ThemeFactory.corrected(ThemeFactory.make(name: "Test", primary: hex, secondary: "#FF6A8A", tone: tone))
                for p in [theme.dark, theme.light] {
                    XCTAssertGreaterThanOrEqual(ThemeFactory.contrast(p.a1, p.bg), 3)
                    XCTAssertGreaterThanOrEqual(ThemeFactory.contrast(p.on, p.a1), 4.5)
                    XCTAssertGreaterThanOrEqual(ThemeFactory.contrast(p.tx, p.bg), 4.5)
                }
            }
        }
    }

    func testLegacySettingsBackupDecodesWithoutThemeFields() throws {
        let data = Data(#"{"preferredCurrency":"EUR","themeMode":"dark"}"#.utf8)
        let old = try JSONDecoder().decode(SettingsBackup.self, from: data)
        XCTAssertEqual(old.preferredCurrency, "EUR")
        XCTAssertNil(old.customThemes)
        XCTAssertNil(old.selectedThemeId)
        XCTAssertNil(old.reduceDecorativeMotion)
    }

    func testThemeSettingsPersistAndBackupRestoresWithoutChangingFinancialData() throws {
        let settings = AppSettings.shared
        let originalID = settings.selectedThemeId, originalThemes = settings.customThemesData
        let originalMotion = settings.reduceDecorativeMotion
        defer {
            settings.customThemesData = originalThemes
            settings.selectedThemeId = originalID
            settings.reduceDecorativeMotion = originalMotion
        }
        let theme = ThemeFactory.make(name: "Test personale", primary: "#123456", secondary: "#ABCDEF", tone: .warm)
        settings.customThemes = [theme]; settings.selectedThemeId = theme.id; settings.reduceDecorativeMotion = true
        XCTAssertEqual(UserDefaults.standard.string(forKey: "selectedThemeId"), theme.id)
        XCTAssertEqual(try JSONDecoder().decode([AppTheme].self, from: XCTUnwrap(UserDefaults.standard.data(forKey: "customThemesData"))), [theme])

        let source = try container()
        let account = Account(name: "Conto di prova", accountType: .payment, currency: .EUR, initialBalance: Decimal(string: "1000.25")!)
        source.mainContext.insert(account)
        let expense = Transaction(transactionType: .expense, amount: Decimal(string: "12.35")!, currency: .EUR, account: account)
        source.mainContext.insert(expense)
        try source.mainContext.save()
        account.updateBalance()
        let expected = account.currentBalance
        XCTAssertEqual(expected, Decimal(string: "987.90")!)
        let backup = try BackupManager.shared.createBackup(accounts: [account], transactions: [expense], categories: [], categoryGroups: [], currencyRecords: [], exchangeRates: [])
        let destination = try container()
        settings.customThemes = []; settings.selectedThemeId = "notte"; settings.reduceDecorativeMotion = false
        let result = try BackupManager.shared.restoreBackup(from: backup, modelContext: destination.mainContext)
        XCTAssertEqual(result.accounts, 1); XCTAssertEqual(result.transactions, 1)
        let restored = try XCTUnwrap(destination.mainContext.fetch(FetchDescriptor<Account>()).first)
        XCTAssertEqual(restored.currentBalance, expected)
        XCTAssertEqual(settings.selectedThemeId, theme.id)
        XCTAssertEqual(settings.customThemes, [theme])
        XCTAssertTrue(settings.reduceDecorativeMotion)
    }

    func testAllTransactionKindsAndPendingStatusKeepBalanceSemantics() throws {
        let c = try container()
        let source = Account(name: "Origine", accountType: .payment, currency: .EUR, initialBalance: 1000)
        let destination = Account(name: "Destinazione", accountType: .cash, currency: .EUR)
        c.mainContext.insert(source); c.mainContext.insert(destination)
        let cases: [(TransactionType, Decimal)] = [(.expense, 10), (.income, 50), (.transfer, 100), (.liabilityPayment, 20), (.adjustment, -5)]
        for (type, amount) in cases {
            let t = Transaction(transactionType: type, amount: amount, currency: .EUR, account: source,
                                destinationAccount: type == .transfer || type == .liabilityPayment ? destination : nil)
            if type == .liabilityPayment { t.interestAmount = 2 }
            c.mainContext.insert(t)
        }
        let pending = Transaction(transactionType: .expense, amount: 500, currency: .EUR, account: source)
        pending.isScheduled = true; pending.status = .pending
        c.mainContext.insert(pending); try c.mainContext.save()
        source.updateBalance(); destination.updateBalance()
        XCTAssertEqual(source.currentBalance, 913)
        XCTAssertEqual(destination.currentBalance, 120)
        pending.status = .executed
        source.updateBalance()
        XCTAssertEqual(source.currentBalance, 413)
    }

    func testTransferUsesSavedDestinationAmountAndBudgetExcludesPending() throws {
        let c = try container()
        let eur = CurrencyRecord(code: "EUR", name: "Euro", symbol: "€", countryCode: "EU", flagEmoji: "🇪🇺")
        let usd = CurrencyRecord(code: "USD", name: "Dollar", symbol: "$", countryCode: "US", flagEmoji: "🇺🇸")
        c.mainContext.insert(eur); c.mainContext.insert(usd)
        let source = Account(name: "Euro", accountType: .payment, currency: .EUR, initialBalance: 1000)
        let destination = Account(name: "Dollars", accountType: .payment, currency: .USD)
        source.currencyRecord = eur; destination.currencyRecord = usd
        c.mainContext.insert(source); c.mainContext.insert(destination)
        let transfer = Transaction(transactionType: .transfer, amount: 100, currency: .EUR, account: source, destinationAccount: destination)
        transfer.currencyRecord = eur; transfer.destinationAmount = 120; transfer.exchangeRateSnapshot = Decimal(string: "1.2")!
        c.mainContext.insert(transfer)
        let category = Category(name: "Test budget")
        c.mainContext.insert(category)
        let expense = Transaction(transactionType: .expense, amount: 25, currency: .EUR, account: source, category: category)
        expense.currencyRecord = eur
        let pending = Transaction(transactionType: .expense, amount: 60, currency: .EUR, account: source, category: category)
        pending.currencyRecord = eur; pending.status = .pending; pending.isScheduled = true
        c.mainContext.insert(expense); c.mainContext.insert(pending)
        let budget = Budget(amount: 100, period: .monthly, currencyRecord: eur, category: category)
        c.mainContext.insert(budget)
        try c.mainContext.save()
        source.updateBalance(context: c.mainContext); destination.updateBalance(context: c.mainContext)
        XCTAssertEqual(source.currentBalance, 875)
        XCTAssertEqual(destination.currentBalance, 120)
        XCTAssertEqual(budget.spent(transactions: [expense, pending, transfer], context: c.mainContext), 25)
        XCTAssertEqual(budget.remaining(transactions: [expense, pending, transfer], context: c.mainContext), 75)
        XCTAssertEqual(budget.percentageUsed(transactions: [expense, pending, transfer], context: c.mainContext), 25)
    }

    func testRecurringFieldsSurviveLegacyBackupImport() throws {
        let settings = AppSettings.shared
        let originalID = settings.selectedThemeId, originalThemes = settings.customThemesData
        defer { settings.customThemesData = originalThemes; settings.selectedThemeId = originalID }
        let source = try container()
        let account = Account(name: "Ricorrenze", accountType: .cash, currency: .EUR, initialBalance: 100)
        source.mainContext.insert(account)
        let t = Transaction(transactionType: .expense, amount: Decimal(string: "7.25")!, currency: .EUR, account: account)
        t.isScheduled = true; t.isRecurring = true; t.isAutomatic = false; t.status = .pending
        t.recurrenceRule = RecurrenceRule(interval: 15, unit: .day)
        t.recurrenceEndDate = Date(timeIntervalSince1970: 1900000000)
        t.adjustToWorkingDay = true
        source.mainContext.insert(t); try source.mainContext.save()
        let backup = try BackupManager.shared.createBackup(accounts: [account], transactions: [t], categories: [], categoryGroups: [], currencyRecords: [], exchangeRates: [])
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: backup) as? [String: Any])
        json["settings"] = ["preferredCurrency": "EUR", "themeMode": settings.themeMode.rawValue]
        let legacy = try JSONSerialization.data(withJSONObject: json)
        let destination = try container()
        _ = try BackupManager.shared.restoreBackup(from: legacy, modelContext: destination.mainContext)
        let restored = try XCTUnwrap(destination.mainContext.fetch(FetchDescriptor<Transaction>()).first)
        XCTAssertEqual(restored.amount, Decimal(string: "7.25")!)
        XCTAssertEqual(restored.status, .pending)
        XCTAssertTrue(restored.isScheduled); XCTAssertTrue(restored.isRecurring); XCTAssertFalse(restored.isAutomatic)
        XCTAssertEqual(restored.recurrenceRule, t.recurrenceRule)
        XCTAssertEqual(restored.recurrenceEndDate, t.recurrenceEndDate)
        XCTAssertTrue(restored.adjustToWorkingDay)
        XCTAssertEqual(settings.selectedThemeId, originalID)
    }

    func testBundledSoraFontIsRegistered() {
        XCTAssertNotNil(UIFont(name: "Sora-Regular", size: 14))
    }
}
