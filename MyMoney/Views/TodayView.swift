//
//  TodayView.swift
//  MoneyTracker
//
//  Created on 2026-01-01.
//

import SwiftUI
import SwiftData
import Charts

// Notification for when transactions change (add, edit, delete)
extension Notification.Name {
    static let transactionsDidChange = Notification.Name("transactionsDidChange")
}

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appSettings) var appSettings
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.orbMotionAllowed) private var orbMotion
    @Environment(\.scenePhase) private var scenePhase
    // CRITICAL: Use @State instead of @Query to control when transactions update
    // This prevents SwiftUI from accessing deleted transactions during its update cycle
    @State private var transactions: [Transaction] = []
    @Query private var allCurrencies: [CurrencyRecord]
    @Query private var exchangeRates: [ExchangeRate]

    @State private var showingAddTransaction = false
    @State private var selectedTransactionType: TransactionType?
    @State private var selectedDate = Date()
    @State private var showingCalendar = false
    @State private var transactionToDelete: Transaction?
    @State private var showingDeleteRecurringAlert = false
    @State private var detectedPatterns: [DetectedRecurringPattern] = []
    @State private var patternToConfirm: DetectedRecurringPattern?
    @State private var showingConfirmPatternAlert = false
    @State private var patternsUpdateTrigger: Int = 0  // CRITICAL: Trigger per forzare refresh UI

    // CRITICAL: Track deleted transaction IDs to filter them out BEFORE SwiftUI accesses them
    @State private var deletedTransactionIds: Set<UUID> = []

    // Flag to trigger transaction refresh
    @State private var needsTransactionRefresh = false

    var preferredCurrencyRecord: CurrencyRecord? {
        allCurrencies.first { $0.code == appSettings.preferredCurrencyEnum.rawValue }
    }

    // Pre-filter: esclude transazioni eliminate o con context nil
    // CRITICAL: Filter by deletedTransactionIds FIRST (before accessing any property)
    var validTransactions: [Transaction] {
        // First pass: filter by ID only (safe, doesn't access other properties)
        // Check both local deletedTransactionIds AND global tracker
        let tracker = DeletedTransactionTracker.shared
        let notDeleted = transactions.filter {
            !deletedTransactionIds.contains($0.id) && !tracker.isDeleted($0.id)
        }
        // Second pass: also check modelContext
        let valid = notDeleted.filter { $0.modelContext != nil }
        return valid
    }

    // Transazioni del giorno selezionato (eseguite)
    var dayTransactions: [Transaction] {
        validTransactions
            .filter { transaction in
                Calendar.current.isDate(transaction.date, inSameDayAs: selectedDate) &&
                transaction.status == .executed
            }
            .sorted { $0.date > $1.date }
    }

    // Transazioni PREVISTE (automatiche ricorrenti)
    var previsteTransactions: [Transaction] {
        validTransactions
            .filter { transaction in
                let isSameDay = Calendar.current.isDate(transaction.date, inSameDayAs: selectedDate)

                return transaction.isScheduled &&
                       transaction.status == .pending &&
                       transaction.isAutomatic &&
                       isSameDay
            }
            .sorted { $0.date < $1.date }
    }

    // Transazioni DA CONFERMARE (solo manuali, MAI automatiche)
    var daConfermare: [Transaction] {
        return validTransactions
            .filter { transaction in
                let isSameDay = Calendar.current.isDate(transaction.date, inSameDayAs: selectedDate)

                // Solo transazioni MANUALI (mai automatiche)
                let isManual = !transaction.isAutomatic

                return transaction.isScheduled &&
                       transaction.status == .pending &&
                       isManual &&
                       isSameDay
            }
            .sorted { $0.date < $1.date }
    }

    var allTransactions: [Transaction] {
        (previsteTransactions + daConfermare + dayTransactions).sorted { t1, t2 in
            if t1.isScheduled && !t2.isScheduled {
                return true
            } else if !t1.isScheduled && t2.isScheduled {
                return false
            }
            return t1.date > t2.date
        }
    }

    var dateComponents: DateComponents {
        Calendar.current.dateComponents([.day, .weekday, .month, .year], from: selectedDate)
    }

    var dayNumber: String {
        "\(dateComponents.day ?? 1)"
    }

    var weekdayName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: selectedDate).capitalized
    }

    var monthYear: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedDate).capitalized
    }

    // Calcola il totale delle transazioni previste
    var previsteTotal: Decimal {
        guard let preferredCurrency = preferredCurrencyRecord else { return 0 }
        let tracker = DeletedTransactionTracker.shared
        return previsteTransactions.reduce(Decimal(0)) { sum, transaction in
            // CRITICAL: Check tracker FIRST
            guard !tracker.isDeleted(transaction.id), transaction.modelContext != nil else { return sum }
            guard let transactionCurrency = transaction.currencyRecord else { return sum }
            let convertedAmount = CurrencyService.shared.convert(
                amount: transaction.amount,
                from: transactionCurrency,
                to: preferredCurrency,
                context: modelContext
            )
            return sum + convertedAmount
        }
    }

    // Calcola il totale delle transazioni da confermare
    var daConfermareTota: Decimal {
        guard let preferredCurrency = preferredCurrencyRecord else { return 0 }
        let tracker = DeletedTransactionTracker.shared
        return daConfermare.reduce(Decimal(0)) { sum, transaction in
            // CRITICAL: Check tracker FIRST
            guard !tracker.isDeleted(transaction.id), transaction.modelContext != nil else { return sum }
            guard let transactionCurrency = transaction.currencyRecord else { return sum }
            let convertedAmount = CurrencyService.shared.convert(
                amount: transaction.amount,
                from: transactionCurrency,
                to: preferredCurrency,
                context: modelContext
            )
            return sum + convertedAmount
        }
    }

    // Calcola il totale delle transazioni eseguite (esclude trasferimenti e aggiustamenti)
    var dayTransactionsTotal: Decimal {
        guard let preferredCurrency = preferredCurrencyRecord else { return 0 }
        let tracker = DeletedTransactionTracker.shared
        return dayTransactions.reduce(Decimal(0)) { sum, transaction in
            // CRITICAL: Check tracker FIRST
            guard !tracker.isDeleted(transaction.id), transaction.modelContext != nil else { return sum }

            // Escludi trasferimenti e aggiustamenti dal totale
            if transaction.transactionType == .transfer || transaction.transactionType == .adjustment {
                return sum
            }

            guard let transactionCurrency = transaction.currencyRecord else { return sum }
            let convertedAmount = CurrencyService.shared.convert(
                amount: transaction.amount,
                from: transactionCurrency,
                to: preferredCurrency,
                context: modelContext
            )

            // Applica il segno corretto in base al tipo di transazione
            let signedAmount: Decimal
            switch transaction.transactionType {
            case .expense:
                signedAmount = -convertedAmount
            case .income:
                signedAmount = convertedAmount
            case .liabilityPayment:
                signedAmount = -convertedAmount
            case .transfer, .adjustment:
                signedAmount = 0  // Mai raggiunto (già escluso sopra)
            }

            return sum + signedAmount
        }
    }

    // Totale uscite del giorno (per pie chart)
    var dayExpenses: Decimal {
        guard let preferredCurrency = preferredCurrencyRecord else { return 0 }
        let tracker = DeletedTransactionTracker.shared
        return dayTransactions
            .filter { !tracker.isDeleted($0.id) && $0.modelContext != nil && $0.transactionType == .expense }
            .reduce(Decimal(0)) { sum, transaction in
                guard let transactionCurrency = transaction.currencyRecord else { return sum }
                let convertedAmount = CurrencyService.shared.convert(
                    amount: transaction.amount,
                    from: transactionCurrency,
                    to: preferredCurrency,
                    context: modelContext
                )
                return sum + convertedAmount
            }
    }

    // Totale entrate del giorno (per pie chart)
    var dayIncome: Decimal {
        guard let preferredCurrency = preferredCurrencyRecord else { return 0 }
        let tracker = DeletedTransactionTracker.shared
        return dayTransactions
            .filter { !tracker.isDeleted($0.id) && $0.modelContext != nil && $0.transactionType == .income }
            .reduce(Decimal(0)) { sum, transaction in
                guard let transactionCurrency = transaction.currencyRecord else { return sum }
                let convertedAmount = CurrencyService.shared.convert(
                    amount: transaction.amount,
                    from: transactionCurrency,
                    to: preferredCurrency,
                    context: modelContext
                )
                return sum + convertedAmount
            }
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let amountString = formatter.string(from: amount as NSDecimalNumber) ?? "0.00"
        return OrbCurrency.string(amount, symbol: appSettings.preferredCurrencyEnum.symbol)
    }

    // Colore del totale basato sul segno
    private var totalColor: Color {
        if dayTransactionsTotal > 0 {
            return Color.orbPositive
        } else if dayTransactionsTotal < 0 {
            return Color.orbNegative
        } else {
            return Color.orbMuted
        }
    }

    private func updateDetectedPatterns() {
        LogManager.shared.debug("🔄 TodayView: updateDetectedPatterns chiamato", category: "TodayView")
        LogManager.shared.debug("   📊 Totale transazioni disponibili: \(transactions.count)", category: "TodayView")
        LogManager.shared.debug("   📊 Transazioni valide (dopo filtri): \(validTransactions.count)", category: "TodayView")
        LogManager.shared.debug("   ⚙️ Recurring detection enabled: \(appSettings.recurringDetectionEnabled)", category: "TodayView")
        LogManager.shared.debug("   ⚙️ Recurring detection days: \(appSettings.recurringDetectionDays)", category: "TodayView")

        if appSettings.recurringDetectionEnabled {
            // CRITICAL: Use validTransactions (filtered by tracker) to avoid crash on deleted transactions
            detectedPatterns = RecurringPatternDetector.shared.detectRecurringPatterns(
                from: validTransactions,
                daysThreshold: appSettings.recurringDetectionDays
            )
            LogManager.shared.debug("   ✅ Pattern rilevati: \(detectedPatterns.count)", category: "TodayView")

            // CRITICAL FIX: Forza il refresh della UI incrementando il trigger
            patternsUpdateTrigger += 1
            LogManager.shared.debug("   🔄 UI Trigger aggiornato a: \(patternsUpdateTrigger)", category: "TodayView")
        } else {
            detectedPatterns = []
            LogManager.shared.debug("   ⚠️ Recurring detection DISABILITATO", category: "TodayView")
        }
    }

    /// CRITICAL: Safely fetch transactions from context, filtering out any that are marked for deletion
    /// This replaces @Query to give us full control over when the transaction list updates
    private func refreshTransactionsSafely() {
        LogManager.shared.debug("🔄 TodayView: refreshTransactionsSafely chiamato", category: "TodayView")
        let tracker = DeletedTransactionTracker.shared

        do {
            let descriptor = FetchDescriptor<Transaction>()
            let allTransactions = try modelContext.fetch(descriptor)

            LogManager.shared.debug("   📊 Totale transazioni fetched da DB: \(allTransactions.count)", category: "TodayView")

            // Filter out deleted transactions BEFORE updating @State
            // This ensures SwiftUI NEVER sees deleted transactions
            let safeTransactions = allTransactions.filter { transaction in
                let isTrackerDeleted = tracker.isDeleted(transaction.id)
                let isLocalDeleted = deletedTransactionIds.contains(transaction.id)
                let hasContext = transaction.modelContext != nil

                return !isTrackerDeleted && !isLocalDeleted && hasContext
            }

            LogManager.shared.debug("   ✅ Transazioni sicure (dopo filtri): \(safeTransactions.count)", category: "TodayView")

            // Log alcune transazioni per debug
            let executedTransactions = safeTransactions.filter { $0.status == .executed && !$0.isScheduled }
            LogManager.shared.debug("   📝 Transazioni eseguite (non programmate): \(executedTransactions.count)", category: "TodayView")
            for (index, transaction) in executedTransactions.prefix(10).enumerated() {
                LogManager.shared.debug("      \(index+1). \(transaction.category?.name ?? "N/A") - \(transaction.amount) \(transaction.account?.currency.rawValue ?? "N/A") - \(transaction.date)", category: "TodayView")
            }

            transactions = safeTransactions
            updateDetectedPatterns()
        } catch {
            LogManager.shared.error("Error fetching transactions: \(error)", category: "TodayView")
        }
    }

    private func confirmRecurringPattern(_ pattern: DetectedRecurringPattern) {
        _ = RecurringPatternDetector.shared.createTransactionFromPattern(
            pattern,
            modelContext: modelContext
        )

        try? modelContext.save()

        // Haptic feedback for confirming recurring transaction
        HapticManager.shared.recurringTransactionConfirmed()

        // Remove the pattern from the detected list immediately
        detectedPatterns.removeAll { $0.id == pattern.id }

        // Refresh the transactions list immediately to show the new transaction
        refreshTransactionsSafely()

        // Then update the full list
        updateDetectedPatterns()
    }

    var body: some View {
        let _ = LogManager.shared.debug("🎨🎨 TodayView BODY RENDERING - patternsUpdateTrigger=\(patternsUpdateTrigger) detectedPatterns.count=\(detectedPatterns.count)", category: "TodayView")

        NavigationStack {
            VStack(spacing: 0) {
                // DEBUG: Forza visualizzazione pattern count in UI nascosta per triggerare refresh
                Text("\(patternsUpdateTrigger)")
                    .frame(width: 0, height: 0)
                    .opacity(0)

                // BOX CONTENENTE DATA E CALENDARIO
                VStack(spacing: 0) {
                    // HEADER CON DATA
                    dateHeader
                        .padding()

                    // CALENDARIO ESPANDIBILE
                    if showingCalendar {
                        calendarView
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .padding(.horizontal)
                            .padding(.bottom, 12)
                    }
                }
                .orbSurface()
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 16)

                dayStrip
                    .padding(.bottom, 16)

                // LISTA TRANSAZIONI
                // CRITICAL FIX: Mostra sempre transactionsList anche se allTransactions è vuoto
                // perché potrebbero esserci suggerimenti ricorrenti da mostrare
                if allTransactions.isEmpty && detectedPatterns.isEmpty {
                    emptyStateView
                } else {
                    transactionsList
                }
            }
            .background(Color.orbBackground)
            .navigationTitle("Oggi")
            .navigationBarTitleDisplayMode(.inline)

            
            // Swipe gesture to change day
            .gesture(
                DragGesture(minimumDistance: 50, coordinateSpace: .local)
                    .onEnded { value in
                        if value.translation.width < -50 {
                            // Swipe left - go to next day
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                            }
                        } else if value.translation.width > 50 {
                            // Swipe right - go to previous day
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                            }
                        }
                    }
            )
            .onAppear {
                // Always set to today when app opens
                selectedDate = Date()
                refreshTransactionsSafely()

                // CRITICAL FIX: Forza un aggiornamento dei pattern dopo un piccolo delay
                // per assicurarsi che tutte le transazioni siano state caricate da SwiftData
                Task {
                    try? await Task.sleep(for: .milliseconds(200))
                    await MainActor.run {
                        updateDetectedPatterns()
                    }
                }
            }
            .onChange(of: needsTransactionRefresh) { _, needsRefresh in
                if needsRefresh {
                    refreshTransactionsSafely()
                    needsTransactionRefresh = false
                }
            }
            .onChange(of: transactions) { _, _ in
                // Aggiorna i pattern quando le transazioni cambiano
                updateDetectedPatterns()
            }
            .onChange(of: selectedDate) { _, _ in
                // Aggiorna i pattern quando cambia la data selezionata
                updateDetectedPatterns()
            }
            .onChange(of: appSettings.recurringDetectionEnabled) { _, _ in
                updateDetectedPatterns()
            }
            .onChange(of: appSettings.recurringDetectionDays) { _, _ in
                updateDetectedPatterns()
            }
            // Refresh when sheets close (transaction added/edited)
            .onChange(of: showingAddTransaction) { _, isShowing in
                if !isShowing {
                    refreshTransactionsSafely()
                }
            }
            .onChange(of: selectedTransactionType) { _, type in
                if type == nil {
                    // Sheet closed, refresh
                    refreshTransactionsSafely()
                }
            }
            // Refresh when scene becomes active (e.g., after navigating back)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    // Verifica se siamo in un nuovo giorno e aggiorna selectedDate
                    if !Calendar.current.isDate(selectedDate, inSameDayAs: Date()) {
                        selectedDate = Date()
                    }

                    refreshTransactionsSafely()

                    // CRITICAL FIX: Forza un aggiornamento dei pattern anche quando l'app diventa attiva
                    // per assicurarsi che le transazioni ricorrenti suggerite siano sempre aggiornate
                    Task {
                        try? await Task.sleep(for: .milliseconds(100))
                        await MainActor.run {
                            updateDetectedPatterns()
                        }
                    }
                }
            }
            // Listen for transaction changes notification (from EditTransactionView, AddTransactionView, etc.)
            .onReceive(NotificationCenter.default.publisher(for: .transactionsDidChange)) { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    refreshTransactionsSafely()
                }
            }
            .background(OrbTabReselect(tab: 2))
            .onReceive(NotificationCenter.default.publisher(for: .orbAddTransaction)) { _ in showingAddTransaction = true }
            .onReceive(NotificationCenter.default.publisher(for: .orbShowDate)) { note in
                if let date = note.object as? Date { selectedDate = date }
            }
            .sheet(isPresented: $showingAddTransaction) {
                AddTransactionView(transactionType: .expense, initialDate: selectedDate)
            }
            .sheet(item: $selectedTransactionType, onDismiss: {
                // Refresh transactions when AddTransactionView closes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    refreshTransactionsSafely()
                }
            }) { type in
                AddTransactionView(transactionType: type, initialDate: selectedDate)
            }
            .alert("Elimina Transazione Ricorrente", isPresented: $showingDeleteRecurringAlert) {
                Button("Annulla", role: .cancel) {
                    transactionToDelete = nil
                }
                Button("Solo questa", role: .destructive) {
                    if let transaction = transactionToDelete {
                        deleteTransaction(transaction, deleteAll: false)
                    }
                    transactionToDelete = nil
                }
                Button("Elimina tutte per sempre", role: .destructive) {
                    if let transaction = transactionToDelete {
                        deleteTransaction(transaction, deleteAll: true)
                    }
                    transactionToDelete = nil
                }
            } message: {
                Text("Vuoi eliminare solo questa occorrenza o tutte le transazioni ricorrenti?")
            }
            .alert("Conferma Transazione Ricorrente", isPresented: $showingConfirmPatternAlert) {
                Button("Annulla", role: .cancel) {
                    patternToConfirm = nil
                }
                Button("Conferma") {
                    if let pattern = patternToConfirm {
                        confirmRecurringPattern(pattern)
                    }
                    patternToConfirm = nil
                }
            } message: {
                if let pattern = patternToConfirm {
                    Text("Vuoi creare una transazione \(pattern.transactionType == .expense ? "di spesa" : pattern.transactionType == .income ? "di entrata" : "di trasferimento") per \(pattern.category.name) di \(formatAmount(pattern.averageAmount))?")
                } else {
                    Text("Vuoi confermare questa transazione ricorrente?")
                }
            }
        }
    }

    private var dayStrip: some View {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        let start = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { offset in
                    if let date = calendar.date(byAdding: .day, value: offset, to: start) {
                        let selected = calendar.isDate(date, inSameDayAs: selectedDate)
                        let hasTransactions = validTransactions.contains { calendar.isDate($0.date, inSameDayAs: date) }
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) { selectedDate = date }
                            HapticManager.shared.selectionFeedback()
                        } label: {
                            VStack(spacing: 5) {
                                Text(date.formatted(.dateTime.weekday(.abbreviated).locale(Locale(identifier: "it_IT")))).font(.orbCaption2)
                                Text(date.formatted(.dateTime.day())).font(.orbHeadline)
                                Circle().fill(hasTransactions ? (selected ? Color.orbOnAccent : Color.orbHighlight) : .clear)
                                    .frame(width: 4, height: 4)
                            }.frame(minWidth: 40, minHeight: 64).padding(.horizontal, 3)
                                .foregroundStyle(selected ? Color.orbOnAccent : Color.orbMuted)
                                .background(selected ? Color.orbAccent : Color.orbCard, in: Capsule())
                        }.buttonStyle(.plain)
                            .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
                            .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
            }.padding(.horizontal, 16)
        }
    }

    // MARK: - Date Header

    private var dateHeader: some View {
        HStack(spacing: 16) {
            // Grande numero del giorno
            Button {
                withAnimation(.spring(response: 0.3)) {
                    showingCalendar.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Text(dayNumber)
                        .font(.orb(56, weight: .bold, relativeTo: .title))
                        .foregroundStyle(Color.orbText)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(weekdayName)
                            .font(.orbHeadline)
                            .foregroundStyle(Color.orbText)
                        Text(monthYear)
                            .font(.orbSubheadline)
                            .foregroundStyle(Color.orbMuted)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()

            // Pie chart piccolo per uscite/entrate
            if dayExpenses > 0 || dayIncome > 0 {
                Chart {
                    if dayExpenses > 0 {
                        SectorMark(
                            angle: .value("Importo", Double(truncating: dayExpenses as NSDecimalNumber)),
                            innerRadius: .ratio(0.5),
                            angularInset: 2
                        )
                        .foregroundStyle(Color.chartExpense.gradient)
                    }
                    if dayIncome > 0 {
                        SectorMark(
                            angle: .value("Importo", Double(truncating: dayIncome as NSDecimalNumber)),
                            innerRadius: .ratio(0.5),
                            angularInset: 2
                        )
                        .foregroundStyle(Color.chartIncome.gradient)
                    }
                }.chartPlotStyle { $0.modifier(OrbChartReveal(kind: .pie)) }
                .frame(width: 56, height: 56)
                .chartLegend(.hidden)
            }
        }
    }

    // MARK: - Calendar View

    private var calendarView: some View {
        VStack(spacing: 12) {
            // Navigation mese
            HStack {
                Button {
                    withAnimation {
                        selectedDate = Calendar.current.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.orbTitle3)
                        .foregroundStyle(Color.orbHighlight)
                }

                Spacer()

                Text(monthYear)
                    .font(.orbHeadline)

                Spacer()

                Button {
                    withAnimation {
                        selectedDate = Calendar.current.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.orbTitle3)
                        .foregroundStyle(Color.orbHighlight)
                }
            }
            .padding(.horizontal)

            // Grid calendario
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                // Header giorni settimana
                ForEach(["lun", "mar", "mer", "gio", "ven", "sab", "dom"], id: \.self) { day in
                    Text(day)
                        .font(.orbCaption)
                        .foregroundStyle(Color.orbMuted)
                        .frame(maxWidth: .infinity)
                }

                // Giorni del mese
                ForEach(daysInMonth(), id: \.self) { date in
                    if let date = date {
                        calendarDayCell(date: date)
                    } else {
                        Text("")
                            .frame(maxWidth: .infinity)
                    }
                }
            }

            // Quick actions
            HStack {
                Button("Oggi") {
                    withAnimation {
                        selectedDate = Date()
                    }
                }
                .font(.orbCaption)
                .foregroundStyle(Color.orbHighlight)

                Spacer()

                Button("Chiudi") {
                    withAnimation(.spring(response: 0.3)) {
                        showingCalendar = false
                    }
                }
                .font(.orbCaption)
                .foregroundStyle(Color.orbMuted)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .orbSurface()
    }

    private func calendarDayCell(date: Date) -> some View {
        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
        let isToday = Calendar.current.isDateInToday(date)
        let hasTransactions = validTransactions.contains { Calendar.current.isDate($0.date, inSameDayAs: date) && $0.status == .executed }

        // Controlla se ci sono transazioni programmate per questo giorno
        let hasScheduledTransactions = validTransactions.contains { transaction in
            guard transaction.status == .pending else {
                return false
            }
            return transaction.isScheduled && Calendar.current.isDate(transaction.date, inSameDayAs: date)
        }

        return Button {
            withAnimation {
                selectedDate = date
            }
        } label: {
            VStack(spacing: 2) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.orbBody)
                    .foregroundStyle(isSelected ? Color.orbOnAccent : (isToday ? Color.orbAccent : Color.orbText))

                // Mostra puntini in base al tipo di transazioni
                HStack(spacing: 2) {
                    if hasTransactions {
                        Circle()
                            .fill(isSelected ? Color.orbOnAccent : Color.orbAccent)
                            .frame(width: 4, height: 4)
                    }

                    if hasScheduledTransactions {
                        Circle()
                            .fill(isSelected ? Color.orbOnAccent : Color.orbHighlight)
                            .frame(width: 4, height: 4)
                    }

                    // Spacer invisibile per mantenere l'altezza consistente
                    if !hasTransactions && !hasScheduledTransactions {
                        Circle()
                            .fill(.clear)
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(height: 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.orbAccent : (isToday ? Color.orbAccent.opacity(0.1) : Color.clear))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func daysInMonth() -> [Date?] {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: selectedDate)
        let year = calendar.component(.year, from: selectedDate)

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1

        guard let firstDayOfMonth = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: firstDayOfMonth) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        let numberOfEmptyDays = (firstWeekday == 1 ? 6 : firstWeekday - 2)

        var days: [Date?] = Array(repeating: nil, count: numberOfEmptyDays)

        for day in range {
            var dayComponents = components
            dayComponents.day = day
            if let date = calendar.date(from: dayComponents) {
                days.append(date)
            }
        }

        return days
    }

    // MARK: - Transactions List

    private var transactionsList: some View {
        List {
            // CRITICAL: Logging della condizione UI
            let _ = LogManager.shared.debug("🎨 TodayView: Rendering transactionsList - patternsUpdateTrigger=\(patternsUpdateTrigger)", category: "TodayView")

            // Sezione RICORRENTI RILEVATE
            // DEBUG: Log della condizione
            let isToday = Calendar.current.isDateInToday(selectedDate)
            let isTodayOrFuture = selectedDate >= Calendar.current.startOfDay(for: Date())
            let hasPatterns = !detectedPatterns.isEmpty
            let isEnabled = appSettings.recurringDetectionEnabled
            let _ = LogManager.shared.debug("🔍 UI CONDITION CHECK: hasPatterns=\(hasPatterns) isEnabled=\(isEnabled) isToday=\(isToday) isTodayOrFuture=\(isTodayOrFuture)", category: "TodayView")
            let _ = LogManager.shared.debug("   selectedDate=\(selectedDate) now=\(Date())", category: "TodayView")
            let _ = LogManager.shared.debug("   startOfDay(selectedDate)=\(Calendar.current.startOfDay(for: selectedDate))", category: "TodayView")
            let _ = LogManager.shared.debug("   startOfDay(now)=\(Calendar.current.startOfDay(for: Date()))", category: "TodayView")

            // CRITICAL FIX: Usa isTodayOrFuture invece di isToday per evitare problemi di timezone
            // I pattern dovrebbero essere mostrati solo per oggi o date future, mai per date passate
            if hasPatterns && isEnabled && isTodayOrFuture {
                Section {
                    // DEBUG: Questo viene mostrato solo se ci sono pattern rilevati
                    let _ = LogManager.shared.debug("✅ UI: Mostrando sezione Ricorrenti Suggerite con \(detectedPatterns.count) pattern", category: "TodayView")
                    ForEach(detectedPatterns) { pattern in
                        HStack(spacing: 12) {
                            // Category icon (custom image or SF Symbol)
                            if let imageData = pattern.category.imageData,
                               let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 44, height: 44)
                                    .clipShape(Circle())
                            } else {
                                ZStack {
                                    Circle()
                                        .fill(pattern.category.color.opacity(0.2))
                                        .frame(width: 44, height: 44)

                                    Image(systemName: pattern.category.icon)
                                        .foregroundStyle(pattern.category.color)
                                }
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(pattern.category.name)
                                    .font(.orbBody)

                                HStack(spacing: 4) {
                                    Text("Ripetuta \(pattern.occurrences) volte")
                                        .font(.orbCaption)
                                        .foregroundStyle(Color.orbMuted)
                                    Text("•")
                                        .font(.orbCaption)
                                        .foregroundStyle(Color.orbMuted)
                                    Text(pattern.account.name)
                                        .font(.orbCaption)
                                        .foregroundStyle(Color.orbMuted)
                                }
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(formatAmount(pattern.averageAmount))
                                    .font(.orbBody.bold())

                                Button {
                                    patternToConfirm = pattern
                                    showingConfirmPatternAlert = true
                                } label: {
                                    Text("Conferma")
                                        .font(.orbCaption.bold())
                                        .foregroundStyle(Color.orbOnAccent)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(Color.orbAccent)
                                        )
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "repeat.circle.fill")
                                .foregroundStyle(Color.orbHighlight)
                            Text("Ricorrenti Suggerite")
                                .foregroundStyle(Color.orbText)
                        }
                        Spacer()
                    }
                    .font(.orbSubheadline.bold())
                    .textCase(nil)
//                    .padding(.horizontal, 16)
                } footer: {
                    Text("Queste transazioni sono state rilevate come ricorrenti negli ultimi \(appSettings.recurringDetectionDays) giorni. Premi 'Conferma' per registrarle.")
//                        .padding(.horizontal, 16)
                }.listRowBackground(Color.orbCard)
            }

            // Sezione PREVISTE (automatiche)
            if !previsteTransactions.isEmpty {
                Section {
                    ForEach(previsteTransactions) { transaction in
                        NavigationLink {
                            EditTransactionView(transaction: transaction)
                        } label: {
                            TransactionRowView(transaction: transaction)
                                .padding(.vertical, 6)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orbLine, style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                handleDeleteTransaction(transaction)
                            } label: {
                                Label("Elimina", systemImage: "trash")
                            }
                            
                            Button {
                                duplicateTransaction(transaction)
                            } label: {
                                Label("Duplica", systemImage: "doc.on.doc")
                            }
                            .tint(Color.orbAccent)
                        }
                    }
                } header: {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundStyle(Color.orbHighlight)
                            Text("Previste")
                                .foregroundStyle(Color.orbText)
                        }
                        Spacer()
                        Text(formatAmount(previsteTotal))
                            .foregroundStyle(Color.orbMuted)
                    }
                    .font(.orbSubheadline.bold())
                    .textCase(nil)
//                    .padding(.horizontal, 16)
                }.listRowBackground(Color.orbCard)
            }

            // Sezione DA CONFERMARE (manuali o scadute)
            if !daConfermare.isEmpty {
                Section {
                    ForEach(daConfermare) { transaction in
                        NavigationLink {
                            EditTransactionView(transaction: transaction)
                        } label: {
                            TransactionRowView(transaction: transaction).modifier(OrbShimmer())
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                handleDeleteTransaction(transaction)
                            } label: {
                                Label("Elimina", systemImage: "trash")
                            }
                            
                            Button {
                                duplicateTransaction(transaction)
                            } label: {
                                Label("Duplica", systemImage: "doc.on.doc")
                            }
                            .tint(Color.orbAccent)
                        }
                    }
                } header: {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.badge.exclamationmark")
                                .foregroundStyle(Color.orbHighlight)
                            Text("Da Confermare")
                                .foregroundStyle(Color.orbHighlight)
                        }
                        Spacer()
                        Text(formatAmount(daConfermareTota))
                            .foregroundStyle(Color.orbMuted)
                    }
                    .font(.orbSubheadline.bold())
                    .textCase(nil)
//                    .padding(.horizontal, 16)
                }.listRowBackground(Color.orbCard)
            }

            // Sezione transazioni eseguite
            if !dayTransactions.isEmpty {
                Section {
                    ForEach(dayTransactions) { transaction in
                        NavigationLink {
                            EditTransactionView(transaction: transaction)
                        } label: {
                            TransactionRowView(transaction: transaction, isCompact: true)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                handleDeleteTransaction(transaction)
                            } label: {
                                Label("Elimina", systemImage: "trash")
                            }
                            
                            Button {
                                duplicateTransaction(transaction)
                            } label: {
                                Label("Duplica", systemImage: "doc.on.doc")
                            }
                            .tint(Color.orbAccent)
                        }
                    }
                } header: {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.orbPositive)
                            Text("Eseguite")
                                .foregroundStyle(Color.orbText)
                        }
                        Spacer()
                        Text(formatAmount(dayTransactionsTotal))
                            .foregroundStyle(totalColor)
                    }
                    .font(.orbSubheadline.bold())
                    .textCase(nil)
//                    .padding(.horizontal, 16)
                }.listRowBackground(Color.orbCard)
            }
        }.orbScreen()
        .animation(orbMotion ? .spring(response: 0.45, dampingFraction: 0.8) : nil, value: dayTransactions.count)
        .id(patternsUpdateTrigger)  // CRITICAL FIX: Forza il refresh della List quando i pattern cambiano
//        .listStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 60))
                .foregroundStyle(Color.orbAccent.opacity(0.3))

            Text("Nessuna transazione")
                .font(.orbTitle3.bold())
                .foregroundStyle(Color.orbText)

            Text("Tocca + per aggiungere una transazione")
                .font(.orbSubheadline)
                .foregroundStyle(Color.orbMuted)

            Spacer()
        }
    }

    // MARK: - Helper Methods

    private func handleDeleteTransaction(_ transaction: Transaction) {
        // Se è una transazione ricorrente, mostra l'alert
        if transaction.isRecurring {
            transactionToDelete = transaction
            showingDeleteRecurringAlert = true
        } else {
            // Altrimenti elimina direttamente
            deleteTransaction(transaction, deleteAll: false)
        }
    }
    
    private func duplicateTransaction(_ transaction: Transaction) {
        // Crea una nuova transazione con gli stessi dati
        let newTransaction = Transaction(
            transactionType: transaction.transactionType,
            amount: transaction.amount,
            currency: transaction.currency,
            date: Date(), // Usa la data odierna
            notes: transaction.notes,
            account: transaction.account,
            category: transaction.category,
            destinationAccount: transaction.destinationAccount
        )
        
        // Copia altri campi importanti
        newTransaction.currencyRecord = transaction.currencyRecord
        newTransaction.destinationAmount = transaction.destinationAmount
        newTransaction.exchangeRateSnapshot = transaction.exchangeRateSnapshot
        newTransaction.isCustomRate = transaction.isCustomRate
        newTransaction.interestAmount = transaction.interestAmount
        newTransaction.interestPercentage = transaction.interestPercentage
        newTransaction.status = .executed // La nuova transazione è sempre eseguita
        
        // NON copiare i campi di ricorrenza per evitare duplicati ricorrenti
        newTransaction.isRecurring = false
        newTransaction.recurrenceRule = nil
        newTransaction.recurrenceEndDate = nil
        newTransaction.parentRecurringTransactionId = nil
        
        // Salva nel context
        modelContext.insert(newTransaction)
        
        try? modelContext.save()
        
        // Aggiorna i saldi degli account
        if let account = transaction.account {
            account.updateBalance(context: modelContext)
        }
        if let destinationAccount = transaction.destinationAccount {
            destinationAccount.updateBalance(context: modelContext)
        }
        
        try? modelContext.save()
        
        // Haptic feedback
        HapticManager.shared.success()
        
        // Refresh transactions
        refreshTransactionsSafely()
    }

    private func deleteTransaction(_ transaction: Transaction, deleteAll: Bool) {
        // IMPORTANTE: Salva TUTTE le informazioni necessarie PRIMA
        let transactionId = transaction.id
        let isRecurring = transaction.isRecurring
        let parentRecurringId = transaction.parentRecurringTransactionId
        let isScheduled = transaction.isScheduled
        let accountToUpdate = transaction.account
        let destinationAccountToUpdate = transaction.destinationAccount

        // Add to deletedTransactionIds IMMEDIATELY to prevent UI access
        deletedTransactionIds.insert(transactionId)

        // Haptic feedback for transaction deletion
        HapticManager.shared.transactionDeleted()

        // If deleting all recurring, also add all related IDs
        if deleteAll && isRecurring {
            let templateId = parentRecurringId ?? transactionId
            for t in transactions where t.id == templateId || t.parentRecurringTransactionId == templateId {
                deletedTransactionIds.insert(t.id)
            }
        }

        // Esegui eliminazione con DispatchQueue e delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [modelContext, transactions] in
            // Filtra le transazioni valide (non eliminate/detached)
            let safeTransactions = transactions.filter { $0.modelContext != nil }

            if deleteAll && isRecurring {
                // Elimina tutte le transazioni della ricorrenza
                let templateId = parentRecurringId ?? transactionId

                let allRelated = safeTransactions.filter {
                    $0.id == templateId || $0.parentRecurringTransactionId == templateId
                }

                withAnimation {
                    for related in allRelated {
                        let relatedId = related.id
                        let relatedIsScheduled = related.isScheduled

                        if relatedIsScheduled {
                            LocalNotificationManager.shared.cancelNotification(transactionId: relatedId)
                        }
                        modelContext.delete(related)
                    }
                }
            } else {
                // Elimina solo questa transazione
                if let transactionToDelete = safeTransactions.first(where: { $0.id == transactionId }) {
                    if isScheduled {
                        LocalNotificationManager.shared.cancelNotification(transactionId: transactionId)
                    }
                    withAnimation {
                        modelContext.delete(transactionToDelete)
                    }
                }
            }

            // Salva prima di aggiornare i bilanci
            try? modelContext.save()

            // Aggiorna i saldi degli account coinvolti
            if let account = accountToUpdate {
                account.updateBalance(context: modelContext)
            }

            if let destinationAccount = destinationAccountToUpdate {
                destinationAccount.updateBalance(context: modelContext)
            }

            try? modelContext.save()
        }
    }
}

// MARK: - Transaction Row View

struct TransactionRowView: View {
    @Environment(\.appSettings) var appSettings
    @Environment(\.colorScheme) var colorScheme
    let transaction: Transaction
    var isCompact: Bool = false
    var contextAccount: Account? = nil  // Conto da cui stiamo visualizzando (per mostrare il nome dell'altro conto nei trasferimenti)

    // Cached values from init to avoid accessing deleted transaction
    private let cachedTransactionType: TransactionType
    private let cachedTransactionId: UUID
    private let wasDeletedAtInit: Bool

    init(transaction: Transaction, isCompact: Bool = false, contextAccount: Account? = nil) {
        self.transaction = transaction
        self.isCompact = isCompact
        self.contextAccount = contextAccount

        // Check if deleted before accessing any properties
        if transaction.modelContext == nil {
            self.wasDeletedAtInit = true
            self.cachedTransactionType = .expense  // Default
            self.cachedTransactionId = UUID()
        } else {
            self.wasDeletedAtInit = false
            // Cache values immediately to avoid accessing deleted transaction later
            self.cachedTransactionType = transaction.transactionType
            self.cachedTransactionId = transaction.id
        }
    }

    private var isDeleted: Bool {
        // Controlla se la transazione era eliminata all'init o lo è ora
        // Also check the global tracker
        return wasDeletedAtInit ||
               transaction.modelContext == nil ||
               DeletedTransactionTracker.shared.isDeleted(cachedTransactionId)
    }

    var body: some View {
        // Se la transazione è stata eliminata, mostra una view vuota
        if isDeleted {
            EmptyView()
        } else {
            transactionContent
        }
    }

    @ViewBuilder
    private var transactionContent: some View {
        // Guard against race condition where isDeleted was false
        // but modelContext became nil between body check and this evaluation
        if transaction.modelContext == nil {
            EmptyView()
        } else {
            contentView
        }
    }

    @ViewBuilder
    private var contentView: some View {
        if transaction.modelContext == nil {
            EmptyView()
        } else {
            actualContentView
        }
    }

    @ViewBuilder
    private var actualContentView: some View {
        // Final safety check
        if transaction.modelContext == nil {
            EmptyView()
        } else {
            HStack(spacing: 12) {
                // Icon (custom image or SF Symbol)
                if let category = transaction.category,
                   let imageData = category.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                } else {
                    ZStack {
                        Circle()
                            .fill(iconBackgroundColor)
                            .frame(width: 44, height: 44)

                        Image(systemName: transaction.category?.icon ?? defaultIcon)
                            .font(.system(size: 18))
                            .foregroundStyle(iconColor)
                    }
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayTitle)
                        .font(.orbBody)
                        .foregroundStyle(Color.orbText)

                    HStack(spacing: 4) {
                        if transaction.modelContext != nil && transaction.isScheduled {
                            Image(systemName: "clock")
                                .font(.orbCaption2)
                            Text(transaction.date.formatted(date: .omitted, time: .shortened))
                                .font(.orbCaption)
                        } else if transaction.modelContext != nil {
                            Text(transaction.date.formatted(date: .omitted, time: .shortened))
                                .font(.orbCaption)
                        }

                        if transaction.modelContext != nil && transaction.isScheduled, let icon = scheduleIcon {
                            Image(systemName: icon)
                                .font(.orbCaption2)
                        }
                    }
                    .foregroundStyle(Color.orbMuted)
                }

                Spacer()

                // Amount with colored background
                Text(transaction.modelContext != nil ? transaction.orbDisplayAmount : "")
                    .font(.orbBody.bold())
                    .foregroundStyle(amountTextColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(amountBackgroundColor)
                    )
            }
        }
    }

    // Titolo da mostrare (per trasferimenti, mostra il nome del conto)
    private var displayTitle: String {
        guard !isDeleted else { return "" }
        guard transaction.modelContext != nil else { return "" }

        if cachedTransactionType == .transfer, let contextAccount = contextAccount {
            // Determina se questo è un trasferimento in uscita o in entrata
            if transaction.account?.id == contextAccount.id {
                // Trasferimento in uscita: mostra il conto di destinazione
                if let destAccount = transaction.destinationAccount {
                    return "Trasferito a: \(destAccount.name)"
                }
                return "Trasferimento"
            } else if transaction.destinationAccount?.id == contextAccount.id {
                // Trasferimento in entrata: mostra il conto di origine
                if let sourceAccount = transaction.account {
                    return "Ricevuto da: \(sourceAccount.name)"
                }
                return "Trasferimento"
            }
        }

        // Per non-trasferimenti o quando non c'è contextAccount
        return transaction.category?.name ?? cachedTransactionType.rawValue
    }

    private var iconBackgroundColor: Color {
        guard !isDeleted else { return Color.orbMuted.opacity(0.15) }
        guard transaction.modelContext != nil else { return Color.orbMuted.opacity(0.15) }

        if transaction.isScheduled {
            return Color.orbHighlight.opacity(0.15)
        }
        return (transaction.category?.color ?? Color.orbAccent).opacity(0.15)
    }

    private var iconColor: Color {
        guard !isDeleted else { return Color.orbMuted }
        guard transaction.modelContext != nil else { return Color.orbMuted }

        if transaction.isScheduled {
            return Color.orbHighlight
        }
        return transaction.category?.color ?? Color.orbAccent
    }

    private var defaultIcon: String {
        guard !isDeleted else { return "questionmark" }
        guard transaction.modelContext != nil else { return "questionmark" }

        if transaction.isScheduled {
            return "clock"
        }
        switch cachedTransactionType {
        case .expense: return "cart"
        case .income: return "dollarsign.circle"
        case .transfer: return "arrow.left.arrow.right"
        case .liabilityPayment: return "creditcard.and.123"
        case .adjustment: return "plus.minus"
        }
    }

    // Background color for amount based on transaction type
    private var amountBackgroundColor: Color {
        guard !isDeleted else { return Color.orbMuted.opacity(0.15) }

        switch cachedTransactionType {
        case .expense:
            return Color.orbNegative.opacity(0.15)
        case .income:
            return Color.orbPositive.opacity(0.15)
        case .transfer:
            return Color.orbAccent.opacity(0.15)
        case .liabilityPayment:
            return Color.orbHighlight.opacity(0.15)
        case .adjustment:
            return Color.orbHighlight.opacity(0.15)
        }
    }

    // Text color for amount based on transaction type
    private var amountTextColor: Color {
        guard !isDeleted else { return Color.orbMuted.opacity(0.15) }

        switch cachedTransactionType {
        case .expense:
            return Color.orbNegative
        case .income:
            return Color.orbPositive
        case .transfer:
            return Color.orbAccent
        case .liabilityPayment:
            return Color.orbHighlight
        case .adjustment:
            return Color.orbHighlight
        }
    }

    private var lineColor: Color {
        guard !isDeleted else { return Color.orbMuted }

        switch cachedTransactionType {
        case .expense:
            return Color.orbNegative
        case .income:
            return Color.orbPositive
        case .transfer:
            return Color.orbAccent
        case .liabilityPayment:
            return Color.orbHighlight
        case .adjustment:
            return Color.orbHighlight
        }
    }

    private var scheduleIcon: String? {
        guard !isDeleted else { return nil }
        guard transaction.modelContext != nil else { return nil }

        if transaction.isAutomatic {
            return "bolt.fill"
        }
        return nil
    }
}

extension TransactionType: Identifiable {
    var id: String { self.rawValue }
}

#Preview {
    TodayView()
        .environment(\.appSettings, AppSettings.shared)
        .modelContainer(for: [Account.self, Transaction.self, Category.self, CategoryGroup.self])
}
