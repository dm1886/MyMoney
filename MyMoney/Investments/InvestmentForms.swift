import SwiftUI
import SwiftData

struct InvestmentInstrumentView: View {
    let account: Account
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [InvestmentInstrument] = []
    @State private var name = ""
    @State private var symbol = ""
    @State private var isin = ""
    @State private var exchange = ""
    @State private var currency = ""
    @State private var error: String?
    @State private var searching = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Cerca titolo") {
                    TextField("Nome, ticker o ISIN", text: $query).autocorrectionDisabled()
                    Button("Cerca online") { Task { await search() } }.disabled(query.trimmingCharacters(in: .whitespaces).isEmpty || searching)
                    if searching { ProgressView() }
                    ForEach(results) { result in
                        Button { save(result) } label: {
                            VStack(alignment: .leading) {
                                Text(result.name)
                                Text(result.symbol + " · " + result.exchange + " · " + result.currency).font(.orbCaption)
                                if let isin = result.isin { Text(isin).font(.orbCaption2) }
                            }
                        }
                    }
                    if !InvestmentMarketService().configured { Text("Ricerca online in preparazione. È già possibile aggiungere lo strumento manualmente.").font(.orbCaption).foregroundStyle(Color.orbMuted) }
                }
                Section("Inserimento manuale") {
                    TextField("Nome", text: $name)
                    TextField("Ticker", text: $symbol).textInputAutocapitalization(.characters).autocorrectionDisabled()
                    TextField("ISIN (facoltativo)", text: $isin).textInputAutocapitalization(.characters).autocorrectionDisabled()
                    TextField("Borsa / mercato", text: $exchange).autocorrectionDisabled()
                    TextField("Valuta del prezzo (EUR, USD…)", text: $currency).textInputAutocapitalization(.characters).autocorrectionDisabled()
                    Button("Aggiungi strumento") {
                        let ticker = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                        let market = exchange.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                        let code = currency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                        guard !ticker.isEmpty, !market.isEmpty, !name.trimmingCharacters(in: .whitespaces).isEmpty,
                              code.range(of: #"^[A-Z]{3}$"#, options: .regularExpression) != nil else { error = "Inserisci nome, ticker, mercato e valuta di tre lettere."; return }
                        let identifier = isin.trimmingCharacters(in: .whitespaces).uppercased()
                        guard identifier.isEmpty || identifier.range(of: #"^[A-Z]{2}[A-Z0-9]{9}[0-9]$"#, options: .regularExpression) != nil else { error = "Verifica il formato dell'ISIN (12 caratteri)."; return }
                        save(InvestmentInstrument(id: "manual:" + market + ":" + ticker, symbol: ticker, name: name, isin: identifier.isEmpty ? nil : identifier, exchange: market, currency: code))
                    }
                }
                if let error { Text(error).foregroundStyle(Color.orbNegative) }
            }.orbScreen().navigationTitle("Aggiungi titolo")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } } }
                .onAppear { currency = account.currencyCode }
        }
    }
    private func search() async {
        searching = true; defer { searching = false }
        do { results = try await InvestmentMarketService().search(query); error = results.isEmpty ? "Nessun titolo trovato." : nil }
        catch { self.error = error.localizedDescription }
    }
    private func save(_ instrument: InvestmentInstrument) {
        guard var profile = account.investmentProfile else { return }
        guard !profile.instruments.contains(where: { $0.id == instrument.id || ($0.symbol == instrument.symbol && $0.exchange == instrument.exchange) }) else { error = "Questo strumento è già presente."; return }
        profile.instruments.append(instrument)
        do { try account.saveInvestment(profile, in: context); dismiss() } catch { self.error = error.localizedDescription }
    }
}

struct InvestmentTradeView: View {
    let account: Account
    var existing: InvestmentTrade? = nil
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var instrumentID = ""
    @State private var kind: InvestmentTradeKind = .buy
    @State private var date = Date()
    @State private var quantity = ""
    @State private var price = ""
    @State private var openingValue = ""
    @State private var fees = "0"
    @State private var fx = "1"
    @State private var note = ""
    @State private var error: String?
    private var profile: InvestmentProfile? { account.investmentProfile }
    private var instrument: InvestmentInstrument? { profile?.instruments.first { $0.id == instrumentID } }
    var body: some View {
        NavigationStack {
            Form {
                Section("Operazione") {
                    Picker("Tipo", selection: $kind) { ForEach(InvestmentTradeKind.allCases.filter { existing == nil || $0 != .opening }) { Text($0.title).tag($0) } }.disabled(existing?.occurrenceID != nil)
                    Picker("Titolo", selection: $instrumentID) { ForEach(profile?.instruments ?? []) { Text($0.symbol + " · " + $0.exchange).tag($0.id) } }.disabled(existing != nil)
                    if kind == .opening {
                        Text("Posizione presente all'inizio del monitoraggio. Il valore iniziale viene sottratto dal saldo investito da dettagliare. Il costo di acquisto serve separatamente a calcolare il risultato.").font(.orbCaption)
                        Text("Data iniziale: " + (profile?.startDate ?? Date()).formatted(date: .abbreviated, time: .omitted)).font(.orbCaption)
                    } else { DatePicker("Data effettiva", selection: $date, in: (profile?.startDate ?? .distantPast)...Date(), displayedComponents: [.date, .hourAndMinute]) }
                    InvestmentNumberField(title: kind == .dividend ? "Quote che ricevono il dividendo" : "Quantità", text: $quantity)
                    if kind == .opening { InvestmentNumberField(title: "Valore iniziale posizione " + account.currencyCode, text: $openingValue) }
                    InvestmentNumberField(title: (kind == .dividend ? "Dividendo per quota " : kind == .opening ? "Costo medio di acquisto per quota " : "Prezzo per quota ") + (instrument?.currency ?? ""), text: $price)
                    InvestmentNumberField(title: "Commissioni e imposte in " + account.currencyCode, text: $fees)
                    if instrument?.currency != account.currencyCode { InvestmentNumberField(title: "Cambio: 1 " + (instrument?.currency ?? "") + " in " + account.currencyCode, text: $fx) }
                    TextField("Note", text: $note, axis: .vertical)
                }
                Section {
                    Text(existing?.isEstimated == true ? "Conferma i dati effettivi del broker. La stima verrà sostituita e la liquidità ricalcolata, senza aggiungere un secondo acquisto." : "Registra un'operazione già avvenuta. Per gli acquisti futuri crea un piano di accumulo.").font(.orbCaption).foregroundStyle(Color.orbMuted)
                }
                if let error { Text(error).foregroundStyle(Color.orbNegative) }
            }.orbScreen().navigationTitle(existing?.isEstimated == true ? "Riconcilia acquisto" : "Operazione titoli")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Salva") { save() } }
                }.onAppear { load() }
        }
    }
    private func load() {
        instrumentID = existing?.instrumentID ?? profile?.instruments.first?.id ?? ""
        if let existing {
            kind = existing.kind; date = existing.date; quantity = InvestmentInput.format(existing.quantity)
            price = InvestmentInput.format(existing.price); fees = InvestmentInput.format(existing.fees)
            fx = InvestmentInput.format(existing.fxToAccount); note = existing.note
        }
    }
    private func save() {
        guard var profile, let quantity = InvestmentInput.decimal(quantity), let price = InvestmentInput.decimal(price),
              let fees = InvestmentInput.decimal(fees), let fxValue = InvestmentInput.decimal(fx) else { error = "Inserisci importi numerici validi."; return }
        let allocated = kind == .opening ? InvestmentInput.decimal(openingValue) : nil
        if kind == .opening && allocated == nil { error = "Inserisci il valore iniziale della posizione, distinto dal costo di acquisto."; return }
        let trade = InvestmentTrade(id: existing?.id ?? UUID(), instrumentID: instrumentID, kind: kind,
                                    date: kind == .opening ? profile.startDate : date, quantity: quantity, price: price,
                                    fxToAccount: instrument?.currency == account.currencyCode ? 1 : fxValue,
                                    fees: fees, openingAllocatedValue: allocated, isEstimated: false, occurrenceID: existing?.occurrenceID, note: note)
        do {
            let replaceID = existing.flatMap { old in profile.trades.contains { $0.id == old.id } ? old.id : nil }
            try profile.record(trade, replacing: replaceID, cashBeforeTrades: account.investmentCashBeforeTrades)
            try account.saveInvestment(profile, in: context)
            NotificationCenter.default.post(name: .orbSaveFeedback, object: nil)
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

struct InvestmentPlanView: View {
    let account: Account
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var instrumentID = ""
    @State private var amount = ""
    @State private var fees = "0"
    @State private var start = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
    @State private var months = 1
    @State private var repeats = true
    @State private var automatic = true
    @State private var notifications = true
    @State private var hasEnd = false
    @State private var end = Calendar.current.date(byAdding: .year, value: 1, to: Date())!
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("Piano di accumulo") {
                    Picker("Titolo", selection: $instrumentID) { ForEach(account.investmentProfile?.instruments ?? []) { Text($0.symbol + " · " + $0.exchange).tag($0.id) } }
                    InvestmentNumberField(title: "Importo totale " + account.currencyCode, text: $amount)
                    InvestmentNumberField(title: "Commissioni incluse " + account.currencyCode, text: $fees)
                    DatePicker("Prima scadenza", selection: $start, in: Date()...)
                    Toggle("Ripeti acquisto", isOn: $repeats)
                    if repeats { Stepper("Ogni \(months) mesi", value: $months, in: 1...12) }
                    Toggle("Data finale", isOn: $hasEnd)
                    if hasEnd { DatePicker("Ultima data", selection: $end, in: start..., displayedComponents: .date) }
                    Toggle("Registra acquisti stimati", isOn: $automatic)
                    Toggle("Notifica alla scadenza", isOn: $notifications)
                }
                Section {
                    Text("La liquidità viene prelevata da questo conto. I versamenti da altri conti possono essere programmati come normali trasferimenti.")
                    Text("Il piano registra quote frazionarie al prezzo disponibile alla scadenza. Le operazioni restano da riconciliare con il broker. Se non ci sono fondi o prezzi adeguati, la registrazione resta sospesa.")
                    Text("iOS può rinviare l'esecuzione: le scadenze vengono recuperate quando apri MyMoney. Le notifiche dipendono dai permessi del dispositivo.")
                }.font(.orbCaption).foregroundStyle(Color.orbMuted)
                if let error { Text(error).foregroundStyle(Color.orbNegative) }
            }.orbScreen().navigationTitle("Nuovo PAC")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Salva") { Task { await save() } } }
                }.onAppear { instrumentID = account.investmentProfile?.instruments.first?.id ?? "" }
        }
    }
    private func save() async {
        guard var profile = account.investmentProfile, !instrumentID.isEmpty,
              let amount = InvestmentInput.decimal(amount), let fees = InvestmentInput.decimal(fees),
              amount > 0, fees >= 0, amount > fees, start > Date(), !hasEnd || end >= start else { error = "Verifica importo, commissioni e date del piano."; return }
        if notifications { _ = await LocalNotificationManager.shared.requestPermission() }
        profile.plans.append(InvestmentPlan(instrumentID: instrumentID, amount: amount, fees: fees, startDate: start,
                                            intervalMonths: months, repeats: repeats, endDate: hasEnd ? end : nil, automatic: automatic, notifications: notifications))
        do {
            try account.saveInvestment(profile, in: context)
            await InvestmentNotifications.refresh(accounts: (try? context.fetch(FetchDescriptor<Account>())) ?? [])
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

struct InvestmentQuoteView: View {
    let account: Account
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var instrumentID = ""
    @State private var price = ""
    @State private var fx = "1"
    @State private var date = Date()
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Picker("Titolo", selection: $instrumentID) { ForEach(account.investmentProfile?.instruments ?? []) { Text($0.symbol + " · " + $0.currency).tag($0.id) } }
                InvestmentNumberField(title: "Prezzo nella valuta del titolo", text: $price)
                if account.investmentProfile?.instruments.first(where: { $0.id == instrumentID })?.currency != account.currencyCode {
                    InvestmentNumberField(title: "Cambio nella valuta del conto", text: $fx)
                }
                DatePicker("Data della quotazione", selection: $date, in: ...Date())
                Text("Il prezzo viene conservato nello storico come quotazione manuale. Non modifica il costo di acquisto o la liquidità.").font(.orbCaption)
                if let error { Text(error).foregroundStyle(Color.orbNegative) }
            }.orbScreen().navigationTitle("Quotazione manuale")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Salva") { save() } }
                }.onAppear { instrumentID = account.investmentProfile?.instruments.first?.id ?? "" }
        }
    }
    private func save() {
        guard var profile = account.investmentProfile, let instrument = profile.instruments.first(where: { $0.id == instrumentID }),
              let price = InvestmentInput.decimal(price), price > 0, let fx = InvestmentInput.decimal(fx), fx > 0 else { error = "Controlla prezzo e cambio."; return }
        profile.quotes.removeAll { $0.instrumentID == instrumentID && $0.date == date && $0.source == "Manuale" }
        profile.quotes.append(InvestmentQuote(instrumentID: instrumentID, price: price, fxToAccount: instrument.currency == account.currencyCode ? 1 : fx, date: date, source: "Manuale"))
        do { try account.saveInvestment(profile, in: context); dismiss() } catch { self.error = error.localizedDescription }
    }
}

struct InvestmentInterestCreditView: View {
    let account: Account
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var amount = ""
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                InvestmentNumberField(title: "Importo netto accreditato " + account.currencyCode, text: $amount)
                Text("Registra l'accredito effettivo di oggi. Il valore entra nella liquidità e nelle entrate; la stima degli interessi riparte da oggi, evitando un doppio conteggio. Inserisci l'importo netto comunicato dall'istituto.").font(.orbCaption)
                if let error { Text(error).foregroundStyle(Color.orbNegative) }
            }.orbScreen().navigationTitle("Accredito interessi")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Registra") { save() } }
                }
        }
    }
    private func save() {
        guard var profile = account.investmentProfile, profile.mode == .simple,
              let value = InvestmentInput.decimal(amount), value >= 0 else { error = "Inserisci un importo valido."; return }
        let previous = account.investmentData, oldBalance = account.currentBalance
        let date = Date()
        let transaction = Transaction(transactionType: .income, amount: value, currency: account.currency, date: date, notes: "Accredito interessi attività", account: account)
        transaction.currencyRecord = account.currencyRecord
        profile.interestCreditIDs = (profile.interestCreditIDs ?? []) + [transaction.id]
        do {
            let data = try JSONEncoder().encode(profile)
            context.insert(transaction)
            account.investmentData = data
            account.updateBalance(context: context)
            try context.save()
            dismiss()
        } catch {
            context.delete(transaction); account.investmentData = previous; account.currentBalance = oldBalance
            self.error = error.localizedDescription
        }
    }
}
