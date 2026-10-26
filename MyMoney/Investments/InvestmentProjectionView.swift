import SwiftUI
import SwiftData
import Charts
import UserNotifications

struct InvestmentProjectionView: View {
    let account: Account
    @Environment(\.modelContext) private var context
    @State private var amount = ""
    @State private var date = Date()
    @State private var operation = 0
    @State private var error: String?
    @State private var paywall = false
    private var symbol: String { account.currencySymbol }
    var body: some View {
        List {
            if let profile = account.investmentProfile, let projection = profile.projection {
                Section("Valore stimato del conto") {
                    AmountText(amount: account.investmentNetWorth, symbol: symbol + " ").font(.orbTitle)
                    LabeledContent("Liquidità", value: money(account.currentBalance))
                    LabeledContent("Investimenti stimati", value: money(projection.value(at: Date(), start: profile.startDate)))
                    LabeledContent("Crescita annua attesa", value: InvestmentInput.format(projection.annualRate) + "%")
                    Text("Proiezione a interesse semplice, giorni/365, solo sulla parte investita. Non è una quotazione di mercato o un rendimento garantito.").font(.orbCaption)
                }
                Section("Ultimo valore confermato degli investimenti") {
                    let last = projection.confirmations.max { $0.date < $1.date }
                    LabeledContent((last?.date ?? profile.startDate).formatted(date: .abbreviated, time: .omitted), value: money(last?.amount ?? projection.initialValue))
                    if let last {
                        LabeledContent("Risultato rilevato dall'inizio", value: money(projection.result(at: last)))
                        Text("Valore confermato meno capitale iniziale e versamenti netti investiti. La liquidità non è inclusa.").font(.orbCaption)
                    }
                }
                Section("Andamento investimenti · stima e rilevazioni") {
                    Chart {
                        ForEach(points(profile: profile, projection: projection)) { point in
                            LineMark(x: .value("Data", point.date!), y: .value("Stima", point.amount))
                                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 4])).foregroundStyle(Color.orbAccent)
                        }
                        PointMark(x: .value("Data", profile.startDate), y: .value("Confermato", NSDecimalNumber(decimal: projection.initialValue).doubleValue)).foregroundStyle(Color.orbPositive)
                        ForEach(projection.confirmations) { entry in
                            PointMark(x: .value("Data", entry.date), y: .value("Confermato", NSDecimalNumber(decimal: entry.amount).doubleValue)).foregroundStyle(Color.orbPositive)
                        }
                    }.frame(height: 200)
                    Text("Linea tratteggiata: proiezione. Punti verdi: valori dichiarati. Tra le rilevazioni non conosciamo l'andamento reale.").font(.orbCaption)
                }
                Section("Aggiorna il portafoglio") {
                    Picker("Operazione", selection: $operation) {
                        Text("Conferma valore dal broker").tag(0)
                        Text("Investi liquidità").tag(1)
                        Text("Disinvesti verso liquidità").tag(2)
                    }
                    InvestmentNumberField(title: operation == 0 ? "Valore totale investimenti (esclusa liquidità)" : "Importo", text: $amount)
                    DatePicker("Data effettiva", selection: $date, in: profile.startDate...max(Date(), profile.startDate), displayedComponents: [.date, .hourAndMinute])
                    Text(operation == 0 ? "Inserisci il valore complessivo delle posizioni, non il totale con la liquidità. La rilevazione non crea entrate o uscite." : "Spostamento interno tra liquidità e investimenti: non modifica il budget. Per aggiungere fondi al conto usa un trasferimento.").font(.orbCaption)
                    Button("Salva aggiornamento") { save() }
                    Button(projection.reminderEnabled ? "Disattiva promemoria fine anno" : "Attiva promemoria fine anno") { Task { await toggleReminder() } }
                    if !InvestmentAccess.shared.hasAccess { Text("Consultazione disponibile; le modifiche richiedono MyMoney Pro.").font(.orbCaption) }
                }
                Section("Rilevazioni confermate") {
                    ForEach(projection.confirmations.sorted { $0.date > $1.date }) { entry in
                        LabeledContent(entry.date.formatted(date: .abbreviated, time: .shortened), value: money(entry.amount))
                    }
                }
                Section("Capitale investito / disinvestito") {
                    ForEach(projection.allocations.sorted { $0.date > $1.date }) { entry in
                        LabeledContent(entry.date.formatted(date: .abbreviated, time: .shortened), value: money(entry.amount))
                    }
                }
            }
            if let error { Text(error).foregroundStyle(Color.orbNegative) }
        }.orbScreen().navigationTitle(account.name).navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $paywall) { InvestmentPaywallView() }
    }
    private func money(_ value: Decimal) -> String { OrbCurrency.string(value, symbol: symbol) }
    private func points(profile: InvestmentProfile, projection: InvestmentProjection) -> [OrbChartPoint] {
        let end = Date(), duration = max(0, end.timeIntervalSince(profile.startDate))
        return (0...60).map { index in
            let date = profile.startDate.addingTimeInterval(duration * Double(index) / 60)
            return OrbChartPoint(label: String(index), amount: NSDecimalNumber(decimal: projection.value(at: date, start: profile.startDate)).doubleValue, date: date)
        }
    }
    private func save() {
        guard InvestmentAccess.shared.hasAccess else { paywall = true; return }
        guard var profile = account.investmentProfile, var projection = profile.projection,
              let value = InvestmentInput.decimal(amount), value >= 0, date >= profile.startDate, date <= Date() else { error = "Verifica importo e data."; return }
        if operation == 0 {
            projection.confirmations.removeAll { $0.date == date }
            projection.confirmations.append(.init(date: date, amount: value))
        } else {
            guard value > 0 else { error = "Inserisci un importo maggiore di zero."; return }
            // Allocations must follow previous entries: prevents silently invalidating reconciliations.
            let last = (projection.allocations.map(\.date) + projection.confirmations.map(\.date)).max() ?? profile.startDate
            guard date > last else { error = "Registra il movimento dopo l'ultima rilevazione o movimento del portafoglio."; return }
            if operation == 1 {
                let available = account.investmentCashBeforeTrades(at: date) + profile.cashAdjustment(at: date)
                guard value <= available, value <= account.currentBalance else { error = "Liquidità insufficiente."; return }
            } else if value > projection.value(at: date, start: profile.startDate) { error = "Importo superiore al valore investito stimato. Conferma prima il valore aggiornato."; return }
            projection.allocations.append(.init(date: date, amount: operation == 1 ? value : -value))
        }
        profile.projection = projection
        do { try account.saveInvestment(profile, in: context); amount = ""; error = nil } catch { self.error = error.localizedDescription }
    }
    private func toggleReminder() async {
        guard InvestmentAccess.shared.hasAccess else { paywall = true; return }
        guard var profile = account.investmentProfile, var projection = profile.projection else { return }
        do {
            if !projection.reminderEnabled {
                guard try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) else { error = "Abilita le notifiche di MyMoney nelle Impostazioni."; return }
            }
            projection.reminderEnabled.toggle(); profile.projection = projection
            try account.saveInvestment(profile, in: context)
            await ProjectionReminder.refresh(account)
        } catch { self.error = error.localizedDescription }
    }
}

@MainActor enum ProjectionReminder {
    static func refresh(_ account: Account) async {
        let center = UNUserNotificationCenter.current(), id = "investment-reconcile:" + account.id.uuidString
        center.removePendingNotificationRequests(withIdentifiers: [id])
        guard account.investmentProfile?.projection?.reminderEnabled == true, InvestmentAccess.shared.hasAccess else { return }
        let content = UNMutableNotificationContent()
        content.title = "Riconcilia il portafoglio"
        content.body = "Conferma in MyMoney il valore degli investimenti riportato dal broker."
        content.sound = .default
        content.userInfo = ["investmentAccountID": account.id.uuidString]
        let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(month: 12, day: 31, hour: 18), repeats: true)
        do { try await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger)) }
        catch { LogManager.shared.warning("Portfolio reminder could not be scheduled", category: "Investments") }
    }
}

struct ProjectionSetupView: View {
    let account: Account
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var rate = "0"
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                InvestmentNumberField(title: "Crescita annua attesa % (da −100 a 100)", text: $rate, allowsNegative: true)
                Text("Il valore investito iniziale resta invariato. Le rilevazioni manuali sostituiranno la stima alla data scelta. Non verranno richieste quotazioni online.")
                if let error { Text(error).foregroundStyle(Color.orbNegative) }
                Button("Attiva monitoraggio stimato") {
                    guard var profile = account.investmentProfile, profile.projection == nil, profile.trades.isEmpty, profile.plans.isEmpty,
                          let value = InvestmentInput.decimal(rate), value >= -100, value <= 100 else { error = "Verifica il tasso. Il passaggio richiede un conto senza operazioni o PAC già registrati."; return }
                    profile.projection = InvestmentProjection(initialValue: profile.unallocatedOpeningValue, annualRate: value)
                    do { try account.saveInvestment(profile, in: context); dismiss() } catch { self.error = error.localizedDescription }
                }
            }.orbScreen().navigationTitle("Crescita stimata")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } } }
        }
    }
}
