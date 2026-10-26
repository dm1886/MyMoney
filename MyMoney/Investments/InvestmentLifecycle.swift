import SwiftUI
import SwiftData
import UserNotifications

@MainActor
enum InvestmentNotifications {
    static let prefix = "investment-plan:"
    static func refresh(accounts: [Account]) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.filter { $0.identifier.hasPrefix(prefix) }.map(\.identifier))
        guard InvestmentAccess.shared.hasAccess else { return }
        let available = max(0, min(24, 60 - pending.filter { !$0.identifier.hasPrefix(prefix) }.count))
        let horizon = Calendar.current.date(byAdding: .year, value: 2, to: Date())!
        var candidates: [(Date, Account, InvestmentPlan)] = []
        for account in accounts {
            guard let profile = account.investmentProfile, profile.mode == .stocks else { continue }
            for plan in profile.plans where plan.notifications && plan.isActive {
                for date in plan.occurrences(through: horizon) where date > Date() {
                    candidates.append((date, account, plan))
                }
            }
        }
        for (date, account, plan) in candidates.sorted(by: { $0.0 < $1.0 }).prefix(available) {
            let content = UNMutableNotificationContent()
            content.title = "Scadenza piano di accumulo"
            content.body = plan.automatic ? "Apri MyMoney per aggiornare e verificare la registrazione stimata del tuo PAC." : "È il momento di verificare l'acquisto previsto dal tuo PAC."
            content.sound = .default
            content.userInfo = ["investmentAccountID": account.id.uuidString]
            let trigger = UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date), repeats: false)
            let request = UNNotificationRequest(identifier: prefix + plan.key(for: date), content: content, trigger: trigger)
            do { try await center.add(request) }
            catch { LogManager.shared.warning("Investment notification could not be scheduled", category: "Investments") }
        }
    }
}

/// Does not promise exact-time background execution. Missed occurrences have a
/// stable key, are reconciled on activation, and retain their original due date.
struct InvestmentLifecycle: ViewModifier {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var phase
    @Query private var accounts: [Account]
    func body(content: Content) -> some View {
        content.task(id: phase) {
            guard phase == .active else { return }
            await InvestmentAccess.shared.refresh()
            if InvestmentAccess.shared.hasAccess {
                for account in accounts {
                    guard var profile = account.investmentProfile, profile.mode == .stocks else { continue }
                    let originalCount = profile.trades.count
                    _ = profile.runPlans(at: Date(), cashBeforeTrades: account.investmentCashBeforeTrades)
                    if profile.trades.count != originalCount {
                        do { try account.saveInvestment(profile, in: context) }
                        catch { LogManager.shared.warning("Investment plan requires review after a save error", category: "Investments") }
                    }
                }
            }
            for account in accounts { await ProjectionReminder.refresh(account) }
            await InvestmentNotifications.refresh(accounts: accounts)
        }
    }
}
