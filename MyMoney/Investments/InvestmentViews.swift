import SwiftUI
import SwiftData
import StoreKit

struct InvestmentPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var access = InvestmentAccess.shared
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("MyMoney Pro", systemImage: "chart.line.uptrend.xyaxis").font(.orbTitle)
                    Text("Il tuo portafoglio, giorno per giorno").font(.orbHeadline)
                    Text("Posizioni, acquisti e vendite, piani di accumulo e riconciliazione. Quotazioni online secondo la copertura del servizio disponibile.")
                    Text("L'attività semplice con interesse annuo resta gratuita. I dati del portafoglio già salvati restano consultabili anche senza abbonamento.")
                        .font(.orbCaption).foregroundStyle(Color.orbMuted)
                }
                Section {
                    ForEach(access.products, id: \.id) { product in
                        ProductView(product).productViewStyle(.compact)
                    }
                    if let message = access.message { Text(message).foregroundStyle(Color.orbMuted) }
                    Button("Ripristina acquisti") { Task { await access.restore() } }.disabled(access.busy)
                }
            }.orbScreen().navigationTitle("Conto azioni")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fine") { dismiss() } } }
                .task { await access.load() }
                .onChange(of: access.hasAccess) { _, enabled in if enabled { dismiss() } }
        }
    }
}

struct InvestmentConfigurationView: View {
    let account: Account
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var mode: AssetMode = .simple
    @State private var rate = "0"
    @State private var invested = "0"
    @State private var start = Date()
    @State private var error: String?
    @State private var paywall = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Modalità") {
                    Picker("Attività", selection: $mode) { ForEach(AssetMode.allCases) { Text($0.title).tag($0) } }
                    if mode == .simple {
                        InvestmentNumberField(title: "Interesse annuo lordo %", text: $rate)
                        Text("Stima a interesse semplice, giorni effettivi / 365. Nessuna capitalizzazione o accredito automatico: gli interessi stimati restano distinti dalla liquidità.").font(.orbCaption)
                    } else {
                        Label("MyMoney Pro", systemImage: "crown")
                        InvestmentNumberField(title: "Quota del saldo già investita", text: $invested)
                        InvestmentNumberField(title: "Crescita annua attesa %", text: $rate, allowsNegative: true)
                        Text("Il saldo attuale viene suddiviso in liquidità e valore investito, senza aumentare il patrimonio. Potrai poi dettagliare le posizioni iniziali.").font(.orbCaption)
                        LabeledContent("Saldo attuale", value: OrbCurrency.string(account.currentBalance, symbol: account.currencySymbol))
                    }
                    DatePicker("Inizio monitoraggio", selection: $start, in: ...Date(), displayedComponents: .date)
                }
                if let error { Section { Text(error).foregroundStyle(Color.orbNegative) } }
            }.orbScreen().navigationTitle("Configura attività")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Salva") { save() } }
                }.sheet(isPresented: $paywall) { InvestmentPaywallView() }
        }
    }
    private func save() {
        guard account.investmentData == nil else { error = "Questo conto è già configurato."; return }
        if mode == .stocks && !InvestmentAccess.shared.hasAccess { paywall = true; return }
        guard let rateValue = InvestmentInput.decimal(rate), (mode == .simple ? Decimal(0)...Decimal(100) : Decimal(-100)...Decimal(100)).contains(rateValue),
              let investedValue = InvestmentInput.decimal(invested), investedValue >= 0,
              mode != .stocks || investedValue <= account.investmentCashBeforeTrades(at: start) else {
            error = "Verifica il tasso (0–100% semplice; −100–100% investimenti) e il valore investito, che non può superare il saldo disponibile alla data iniziale."; return
        }
        var profile = InvestmentProfile(mode: mode, startDate: start, annualRate: rateValue)
        if mode == .stocks { profile.projection = InvestmentProjection(initialValue: investedValue, annualRate: rateValue); profile.annualRate = 0; profile.openingCashReclassification = investedValue }
        do { try account.saveInvestment(profile, in: context); dismiss() } catch { self.error = error.localizedDescription }
    }
}

struct InvestmentAccountView: View {
    let account: Account
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var phase
    @State private var showTrade = false
    @State private var showProjectionSetup = false
    @State private var showInstrument = false
    @State private var showPlan = false
    @State private var showPaywall = false
    @State private var reconcile: InvestmentTrade?
    @State private var error: String?
    @State private var loading = false
    @State private var showFunding = false
    @State private var showQuote = false
    @State private var showInterestCredit = false
    private var profile: InvestmentProfile? { account.investmentProfile }
    private var symbol: String { account.currencySymbol }
    var body: some View {
        List {
            if let profile, profile.projection != nil {
                NavigationLink("Apri valore stimato e riconciliazione") { InvestmentProjectionView(account: account) }
            } else if let profile {
                summary(profile)
                if profile.mode == .stocks {
                    if !InvestmentAccess.shared.hasAccess {
                        Section { Button("Sblocca modifiche con MyMoney Pro") { showPaywall = true }; Text("Portafoglio in sola lettura.").font(.orbCaption) }
                    }
                    if profile.trades.isEmpty && profile.plans.isEmpty {
                        Section { Button("Usa crescita stimata senza API") { gated { showProjectionSetup = true } } }
                    }
                    positions(profile)
                    Section("Operazioni") {
                        Button("Registra acquisto, vendita o dividendo", systemImage: "plus.circle") { gated { showTrade = true } }.disabled(profile.instruments.isEmpty)
                        Button("Aggiungi strumento", systemImage: "magnifyingglass") { gated { showInstrument = true } }
                        Button("Trasferisci liquidità", systemImage: "arrow.left.arrow.right") { gated { showFunding = true } }
                        Button("Registra una quotazione manuale", systemImage: "pencil") { gated { showQuote = true } }.disabled(profile.instruments.isEmpty)
                    }
                    plans(profile)
                    Section("Registro investimenti") {
                        if profile.trades.isEmpty { Text("Nessuna operazione registrata").foregroundStyle(Color.orbMuted) }
                        ForEach(profile.trades.sorted { $0.date > $1.date }) { trade in
                            Button { if trade.kind != .opening { gated { reconcile = trade } } } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack { Text(trade.kind.title + " · " + (profile.instruments.first { $0.id == trade.instrumentID }?.symbol ?? "")); Spacer(); if trade.isEstimated { Text("Da riconciliare").font(.orbCaption).foregroundStyle(Color.chartWarning) } }
                                    Text(trade.date.formatted(date: .abbreviated, time: .omitted) + " · " + InvestmentInput.format(trade.quantity) + " quote").font(.orbCaption).foregroundStyle(Color.orbMuted)
                                    Text("Liquidità " + OrbCurrency.string(trade.cashDelta, symbol: symbol)).font(.orbSubheadline)
                                }
                            }.buttonStyle(.plain)
                        }
                    }
                    Section {
                        Text("MyMoney registra il tuo portafoglio. I PAC automatici usano prezzi stimati: verifica quantità, prezzo, cambio e commissioni sul rendiconto del broker. Nessun ordine viene inviato al broker.")
                        Text("Le scadenze vengono recuperate all'apertura dell'app. Senza liquidità o quotazione storica adeguata il PAC resta da completare.")
                    }.font(.orbCaption).foregroundStyle(Color.orbMuted)
                }
                Section("Andamento giornaliero") {
                    OrbAreaChart(points: history(profile), symbol: symbol, title: "Valore del conto")
                    Text("Valori basati su operazioni e prezzi disponibili. Nei giorni senza quotazione viene mantenuto l'ultimo prezzo noto; senza prezzi si usa il valore registrato nell'operazione.").font(.orbCaption).foregroundStyle(Color.orbMuted)
                }
            } else { Text("Configurazione investimento non disponibile.") }
            if let error { Section { Text(error).foregroundStyle(Color.orbNegative) } }
        }.orbScreen().navigationTitle(account.name).navigationBarTitleDisplayMode(.inline)
            .toolbar { if profile?.mode == .stocks { ToolbarItem(placement: .primaryAction) { Button { Task { await refresh() } } label: { if loading { ProgressView() } else { Image(systemName: "arrow.clockwise") } }.disabled(loading).accessibilityLabel("Aggiorna quotazioni") } } }
            .sheet(isPresented: $showProjectionSetup) { ProjectionSetupView(account: account) }
            .sheet(isPresented: $showPaywall) { InvestmentPaywallView() }
            .sheet(isPresented: $showInstrument) { InvestmentInstrumentView(account: account) }
            .sheet(isPresented: $showTrade) { InvestmentTradeView(account: account) }
            .sheet(item: $reconcile) { InvestmentTradeView(account: account, existing: $0) }
            .sheet(isPresented: $showPlan) { InvestmentPlanView(account: account) }
            .sheet(isPresented: $showInterestCredit) { InvestmentInterestCreditView(account: account) }
            .sheet(isPresented: $showQuote) { InvestmentQuoteView(account: account) }
            .sheet(isPresented: $showFunding) { AddTransactionView(transactionType: .transfer, defaultAccount: account) }
            .refreshable { await refresh() }
            .task(id: phase) {
                guard phase == .active, profile?.mode == .stocks, InvestmentMarketService().configured, InvestmentAccess.shared.hasAccess else { return }
                while !Task.isCancelled {
                    await refresh()
                    do { try await Task.sleep(for: .seconds(60)) } catch { return }
                }
            }
    }
    @ViewBuilder private func summary(_ profile: InvestmentProfile) -> some View {
        Section {
            Text(profile.mode == .simple ? "Valore stimato" : "Valore del portafoglio").font(.orbHeadline)
            Text(OrbCurrency.string(account.investmentNetWorth, symbol: symbol)).font(.orbTitle).monospacedDigit()
            LabeledContent("Liquidità", value: OrbCurrency.string(account.currentBalance, symbol: symbol))
            if profile.mode == .simple {
                LabeledContent("Interesse annuo lordo", value: InvestmentInput.format(profile.annualRate) + "%")
                LabeledContent("Interessi stimati maturati", value: OrbCurrency.string(account.investmentNetWorth - account.currentBalance, symbol: symbol))
                Button("Registra accredito interessi") { showInterestCredit = true }
                Text("Interesse semplice, giorni / 365, senza tasse o capitalizzazione. La stima non è un accredito e non entra nel budget delle entrate.").font(.orbCaption).foregroundStyle(Color.orbMuted)
            } else {
                LabeledContent("Investito", value: OrbCurrency.string(profile.securitiesValue(at: Date()), symbol: symbol))
                if profile.unallocatedOpeningValue > 0 {
                    LabeledContent("Posizioni iniziali da dettagliare", value: OrbCurrency.string(profile.unallocatedOpeningValue, symbol: symbol))
                }
                let positions = profile.positions(at: Date())
                LabeledContent("Risultato non realizzato", value: OrbCurrency.string(positions.reduce(0) { $0 + $1.unrealized }, symbol: symbol))
                LabeledContent("Risultato realizzato", value: OrbCurrency.string(positions.reduce(0) { $0 + $1.realized }, symbol: symbol))
                LabeledContent("Dividendi netti registrati", value: OrbCurrency.string(positions.reduce(0) { $0 + $1.dividends }, symbol: symbol))
                Text("Costo medio ponderato; importi nella valuta del conto. Le posizioni ancora da dettagliare non hanno un rendimento calcolabile.").font(.orbCaption).foregroundStyle(Color.orbMuted)
            }
        }.listRowBackground(Color.orbCard)
    }
    @ViewBuilder private func positions(_ profile: InvestmentProfile) -> some View {
        Section("Titoli") {
            ForEach(profile.positions(at: Date()).filter { $0.quantity > 0 }) { position in
                VStack(alignment: .leading, spacing: 6) {
                    Text(position.instrument.name).font(.orbHeadline)
                    Text(position.instrument.symbol + " · " + position.instrument.exchange + " · " + position.instrument.currency).font(.orbCaption)
                    LabeledContent(InvestmentInput.format(position.quantity) + " quote", value: OrbCurrency.string(position.marketValue, symbol: symbol))
                    Text("Costo " + OrbCurrency.string(position.cost, symbol: symbol) + " · Risultato " + OrbCurrency.string(position.unrealized, symbol: symbol)).font(.orbCaption)
                    if let quote = position.quote {
                        Text(quote.source + " · " + quote.date.formatted(date: .abbreviated, time: .shortened) + (quote.isRealtime ? " · Tempo reale alla rilevazione" : " · Prezzo disponibile")).font(.orbCaption2).foregroundStyle(Color.orbMuted)
                    } else { Text("Valutazione dal prezzo registrato; quotazione di mercato assente").font(.orbCaption2).foregroundStyle(Color.chartWarning) }
                }
            }
            if profile.positions(at: Date()).isEmpty { Text("Aggiungi uno strumento, poi registra le quote già possedute o un acquisto.").foregroundStyle(Color.orbMuted) }
        }
    }
    @ViewBuilder private func plans(_ profile: InvestmentProfile) -> some View {
        Section("Piani di accumulo") {
            ForEach(profile.plans) { plan in
                VStack(alignment: .leading, spacing: 6) {
                    Text((profile.instruments.first { $0.id == plan.instrumentID }?.symbol ?? "Titolo") + " · " + OrbCurrency.string(plan.amount, symbol: symbol)).font(.orbHeadline)
                    Text((plan.repeats ? "Ogni \(plan.intervalMonths) mesi · " : "Acquisto singolo · ") + (plan.automatic ? "Registrazione stimata" : "Promemoria") + (plan.isActive ? "" : " · In pausa")).font(.orbCaption)
                    Text("Dal " + plan.startDate.formatted(date: .abbreviated, time: .shortened)).font(.orbCaption)
                    Button(plan.isActive ? "Metti in pausa" : "Riprendi") { gated { togglePlan(plan.id) } }
                    if plan.isActive {
                        ForEach(plan.occurrences(through: Date()).filter { date in !profile.trades.contains { $0.occurrenceID == plan.key(for: date) } && !plan.skippedOccurrences.contains(plan.key(for: date)) }, id: \.self) { date in
                            Button("Registra scadenza del " + date.formatted(date: .abbreviated, time: .omitted)) {
                                gated { reconcile = InvestmentTrade(instrumentID: plan.instrumentID, kind: .buy, date: date, quantity: 0, price: 0, fees: plan.fees, occurrenceID: plan.key(for: date)) }
                            }
                        }
                    }
                }
            }
            Button("Nuovo piano di accumulo", systemImage: "calendar.badge.plus") { gated { showPlan = true } }.disabled(profile.instruments.isEmpty)
        }
    }
    private func history(_ profile: InvestmentProfile) -> [OrbChartPoint] {
        let calendar = Calendar.current
        return (0..<30).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: Date()), day >= profile.startDate else { return nil }
            return OrbChartPoint(label: day.formatted(.dateTime.day().month(.abbreviated)), amount: NSDecimalNumber(decimal: account.investmentValue(profile: profile, at: day)).doubleValue, date: day)
        }
    }
    private func gated(_ action: () -> Void) { if InvestmentAccess.shared.hasAccess { action() } else { showPaywall = true } }
    private func togglePlan(_ id: UUID) {
        guard var profile, let index = profile.plans.firstIndex(where: { $0.id == id }) else { return }
        if profile.plans[index].isActive {
            profile.plans[index].isActive = false
            profile.plans[index].pausedAt = Date()
        } else {
            profile.plans[index].isActive = true
            if let paused = profile.plans[index].pausedAt {
                let skipped = profile.plans[index].occurrences(through: Date()).filter { $0 >= paused }.map { profile.plans[index].key(for: $0) }
                profile.plans[index].skippedOccurrences.append(contentsOf: skipped)
            }
            profile.plans[index].pausedAt = nil
        }
        do { try account.saveInvestment(profile, in: context); Task { await InvestmentNotifications.refresh(accounts: (try? context.fetch(FetchDescriptor<Account>())) ?? []) } }
        catch { self.error = error.localizedDescription }
    }
    private func refresh() async {
        guard let profile, profile.mode == .stocks, !loading else { return }
        guard InvestmentAccess.shared.hasAccess else { showPaywall = true; return }
        loading = true; defer { loading = false }
        do {
            var received: [InvestmentQuote] = []
            for instrument in profile.instruments {
                let quotes = try await InvestmentMarketService().quotes(for: instrument, accountCurrency: account.currencyCode, from: profile.startDate)
                received.append(contentsOf: quotes)
            }
            try Task.checkCancellation()
            guard account.modelContext != nil, var latest = account.investmentProfile, latest.mode == .stocks else { return }
            for quote in received {
                latest.quotes.removeAll { $0.instrumentID == quote.instrumentID && $0.date == quote.date && $0.source == quote.source }
                latest.quotes.append(quote)
            }
            let issues = latest.runPlans(at: Date(), cashBeforeTrades: account.investmentCashBeforeTrades)
            try account.saveInvestment(latest, in: context)
            error = issues.isEmpty ? nil : issues.joined(separator: "\n")
        } catch { self.error = error.localizedDescription }
    }
}

struct InvestmentNumberField: View {
    let title: String
    @Binding var text: String
    var allowsNegative = false
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.orbCaption).foregroundStyle(Color.orbMuted)
            HStack {
                TextField("0", text: $text).keyboardType(.decimalPad).accessibilityLabel(title)
                if allowsNegative {
                    Button("±") { text = text.hasPrefix("-") ? String(text.dropFirst()) : "-" + text }.buttonStyle(.borderless).accessibilityLabel("Cambia segno del rendimento")
                }
            }
        }
    }
}
enum InvestmentInput {
    static func decimal(_ text: String) -> Decimal? {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: " ", with: "")
        guard !clean.isEmpty else { return nil }
        let normalized = clean.contains(",") ? clean.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".") : clean
        guard normalized.range(of: #"^-?\d+(\.\d+)?$"#, options: .regularExpression) != nil else { return nil }
        return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
    }
    static func format(_ value: Decimal) -> String { NSDecimalNumber(decimal: value).stringValue.replacingOccurrences(of: ".", with: ",") }
}
