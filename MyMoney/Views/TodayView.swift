//
//  TodayView.swift
//  MoneyTracker
//
//  Created on 2026-01-01.
//

import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appSettings) var appSettings
    @Environment(\.colorScheme) var colorScheme
    @Query private var transactions: [Transaction]
    @Query private var allCurrencies: [CurrencyRecord]
    @Query private var exchangeRates: [ExchangeRate]

    @State private var showingAddTransaction = false
    @State private var selectedTransactionType: TransactionType?
    @State private var selectedDate = Date()
    @State private var showingCalendar = false
    @State private var transactionToDelete: Transaction?
    @State private var showingDeleteRecurringAlert = false
    @State private var detectedPatterns: [DetectedRecurringPattern] = []

    var preferredCurrencyRecord: CurrencyRecord? {
        allCurrencies.first { $0.code == appSettings.preferredCurrencyEnum.rawValue }
    }

    // Transazioni del giorno selezionato (eseguite)
    var dayTransactions: [Transaction] {
        transactions
            .filter { transaction in
                Calendar.current.isDate(transaction.date, inSameDayAs: selectedDate) &&
                transaction.status == .executed
            }
            .sorted { $0.date > $1.date }
    }

    // Transazioni PREVISTE (automatiche ricorrenti)
    var previsteTransactions: [Transaction] {
        transactions
            .filter { transaction in
                guard let scheduledDate = transaction.scheduledDate else { return false }
                let isSameDay = Calendar.current.isDate(scheduledDate, inSameDayAs: selectedDate)
                let isRecurringTemplate = transaction.isRecurring && transaction.parentRecurringTransactionId == nil

                return transaction.isScheduled &&
                       transaction.status == .pending &&
                       transaction.isAutomatic &&
                       isSameDay &&
                       !isRecurringTemplate
            }
            .sorted { ($0.scheduledDate ?? Date()) < ($1.scheduledDate ?? Date()) }
    }

    // Transazioni DA CONFERMARE (solo manuali, MAI automatiche)
    var daConfermare: [Transaction] {
        return transactions
            .filter { transaction in
                guard let scheduledDate = transaction.scheduledDate else { return false }
                let isSameDay = Calendar.current.isDate(scheduledDate, inSameDayAs: selectedDate)
                let isRecurringTemplate = transaction.isRecurring && transaction.parentRecurringTransactionId == nil

                // Solo transazioni MANUALI (mai automatiche)
                let isManual = !transaction.isAutomatic

                return transaction.isScheduled &&
                       transaction.status == .pending &&
                       isManual &&
                       isSameDay &&
                       !isRecurringTemplate
            }
            .sorted { ($0.scheduledDate ?? Date()) < ($1.scheduledDate ?? Date()) }
    }

    var allTransactions: [Transaction] {
        (previsteTransactions + daConfermare + dayTransactions).sorted { t1, t2 in
            if t1.isScheduled && !t2.isScheduled {
                return true
            } else if !t1.isScheduled && t2.isScheduled {
                return false
            }
            return (t1.scheduledDate ?? t1.date) > (t2.scheduledDate ?? t2.date)
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
        return previsteTransactions.reduce(Decimal(0)) { sum, transaction in
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
        return daConfermare.reduce(Decimal(0)) { sum, transaction in
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

    // Calcola il totale delle transazioni eseguite
    var dayTransactionsTotal: Decimal {
        guard let preferredCurrency = preferredCurrencyRecord else { return 0 }
        return dayTransactions.reduce(Decimal(0)) { sum, transaction in
            guard let transactionCurrency = transaction.currencyRecord else { return sum }
            let convertedAmount = CurrencyService.shared.convert(
                amount: transaction.amount,
                from: transactionCurrency,
                to: preferredCurrency,
                context: modelContext
            )
            let signedAmount = transaction.transactionType == .expense ? -convertedAmount : convertedAmount
            return sum + signedAmount
        }
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let amountString = formatter.string(from: amount as NSDecimalNumber) ?? "0.00"
        return "\(appSettings.preferredCurrencyEnum.rawValue) \(amountString)"
    }

    private func updateDetectedPatterns() {
        if appSettings.recurringDetectionEnabled {
            detectedPatterns = RecurringPatternDetector.shared.detectRecurringPatterns(
                from: transactions,
                daysThreshold: appSettings.recurringDetectionDays
            )
        } else {
            detectedPatterns = []
        }
    }

    private func confirmRecurringPattern(_ pattern: DetectedRecurringPattern) {
        _ = RecurringPatternDetector.shared.createTransactionFromPattern(
            pattern,
            modelContext: modelContext
        )

        try? modelContext.save()

        // Remove the pattern from the detected list immediately
        detectedPatterns.removeAll { $0.id == pattern.id }

        // Then update the full list
        updateDetectedPatterns()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 16)

                // LISTA TRANSAZIONI
                if allTransactions.isEmpty {
                    emptyStateView
                } else {
                    transactionsList
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)

            
            //-------------------
            .onAppear {
                updateDetectedPatterns()
            }
            .onChange(of: transactions) { _, _ in
                updateDetectedPatterns()
            }
            .onChange(of: appSettings.recurringDetectionEnabled) { _, _ in
                updateDetectedPatterns()
            }
            .onChange(of: appSettings.recurringDetectionDays) { _, _ in
                updateDetectedPatterns()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddTransaction = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(appSettings.accentColor)
                    }
                }
            }
            .sheet(isPresented: $showingAddTransaction) {
                TransactionTypeSelectionView(selectedType: $selectedTransactionType)
            }
            .sheet(item: $selectedTransactionType) { type in
                AddTransactionView(transactionType: type)
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
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(weekdayName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(monthYear)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()
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
                        .font(.title3)
                        .foregroundStyle(appSettings.accentColor)
                }

                Spacer()

                Text(monthYear)
                    .font(.headline)

                Spacer()

                Button {
                    withAnimation {
                        selectedDate = Calendar.current.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                        .foregroundStyle(appSettings.accentColor)
                }
            }
            .padding(.horizontal)

            // Grid calendario
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                // Header giorni settimana
                ForEach(["lun", "mar", "mer", "gio", "ven", "sab", "dom"], id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                .font(.caption)
                .foregroundStyle(appSettings.accentColor)

                Spacer()

                Button("Chiudi") {
                    withAnimation(.spring(response: 0.3)) {
                        showingCalendar = false
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func calendarDayCell(date: Date) -> some View {
        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
        let isToday = Calendar.current.isDateInToday(date)
        let hasTransactions = transactions.contains { Calendar.current.isDate($0.date, inSameDayAs: date) && $0.status == .executed }

        // Controlla se ci sono transazioni programmate per questo giorno
        let hasScheduledTransactions = transactions.contains { transaction in
            guard let scheduledDate = transaction.scheduledDate,
                  transaction.status == .pending else {
                return false
            }
            return Calendar.current.isDate(scheduledDate, inSameDayAs: date)
        }

        return Button {
            withAnimation {
                selectedDate = date
            }
        } label: {
            VStack(spacing: 2) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.body)
                    .foregroundStyle(isSelected ? .white : (isToday ? appSettings.accentColor : .primary))

                // Mostra puntini in base al tipo di transazioni
                HStack(spacing: 2) {
                    if hasTransactions {
                        Circle()
                            .fill(isSelected ? .white : appSettings.accentColor)
                            .frame(width: 4, height: 4)
                    }

                    if hasScheduledTransactions {
                        Circle()
                            .fill(isSelected ? .white : .orange)
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
                    .fill(isSelected ? appSettings.accentColor : (isToday ? appSettings.accentColor.opacity(0.1) : Color.clear))
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
            // Sezione RICORRENTI RILEVATE
            if !detectedPatterns.isEmpty && appSettings.recurringDetectionEnabled {
                Section {
                    ForEach(detectedPatterns) { pattern in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(pattern.category.color.opacity(0.2))
                                    .frame(width: 44, height: 44)

                                Image(systemName: pattern.category.icon)
                                    .foregroundStyle(pattern.category.color)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(pattern.category.name)
                                    .font(.body)

                                HStack(spacing: 4) {
                                    Text("Ripetuta \(pattern.occurrences) volte")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("•")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(pattern.account.name)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(formatAmount(pattern.averageAmount))
                                    .font(.body.bold())

                                Button {
                                    confirmRecurringPattern(pattern)
                                } label: {
                                    Text("Conferma")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(appSettings.accentColor)
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
                                .foregroundStyle(.purple)
                            Text("Ricorrenti Suggerite")
                                .foregroundStyle(.primary)
                        }
                        Spacer()
                    }
                    .font(.subheadline.bold())
                    .textCase(nil)
//                    .padding(.horizontal, 16)
                } footer: {
                    Text("Queste transazioni sono state rilevate come ricorrenti negli ultimi \(appSettings.recurringDetectionDays) giorni. Premi 'Conferma' per registrarle.")
//                        .padding(.horizontal, 16)
                }
            }

            // Sezione PREVISTE (automatiche)
            if !previsteTransactions.isEmpty {
                Section {
                    ForEach(previsteTransactions) { transaction in
                        NavigationLink {
                            EditTransactionView(transaction: transaction)
                        } label: {
                            TransactionRowView(transaction: transaction)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                handleDeleteTransaction(transaction)
                            } label: {
                                Label("Elimina", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundStyle(.blue)
                            Text("Previste")
                                .foregroundStyle(.primary)
                        }
                        Spacer()
                        Text(formatAmount(previsteTotal))
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline.bold())
                    .textCase(nil)
//                    .padding(.horizontal, 16)
                }
            }

            // Sezione DA CONFERMARE (manuali o scadute)
            if !daConfermare.isEmpty {
                Section {
                    ForEach(daConfermare) { transaction in
                        NavigationLink {
                            EditTransactionView(transaction: transaction)
                        } label: {
                            TransactionRowView(transaction: transaction)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                handleDeleteTransaction(transaction)
                            } label: {
                                Label("Elimina", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.badge.exclamationmark")
                                .foregroundStyle(.orange)
                            Text("Da Confermare")
                                .foregroundStyle(.orange)
                        }
                        Spacer()
                        Text(formatAmount(daConfermareTota))
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline.bold())
                    .textCase(nil)
//                    .padding(.horizontal, 16)
                }
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
                        }
                    }
                } header: {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Eseguite")
                                .foregroundStyle(.primary)
                        }
                        Spacer()
                        Text(formatAmount(dayTransactionsTotal))
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline.bold())
                    .textCase(nil)
//                    .padding(.horizontal, 16)
                }
            }
        }
//        .listStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 60))
                .foregroundStyle(appSettings.accentColor.opacity(0.3))

            Text("Nessuna transazione")
                .font(.title3.bold())
                .foregroundStyle(.primary)

            Text("Tocca + per aggiungere una transazione")
                .font(.subheadline)
                .foregroundStyle(.secondary)

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

    private func deleteTransaction(_ transaction: Transaction, deleteAll: Bool) {
        print("🔄 [DEBUG] TodayView.deleteTransaction - deleteAll: \(deleteAll)")

        // IMPORTANTE: Salva TUTTE le informazioni necessarie PRIMA
        let transactionId = transaction.id
        let isRecurring = transaction.isRecurring
        let parentRecurringId = transaction.parentRecurringTransactionId
        let isScheduled = transaction.isScheduled
        let accountToUpdate = transaction.account
        let destinationAccountToUpdate = transaction.destinationAccount

        print("   ✅ Got transactionId: \(transactionId)")
        print("   ✅ Got isRecurring: \(isRecurring)")
        print("   ✅ Got parentId: \(parentRecurringId?.uuidString ?? "nil")")
        print("   ✅ Got isScheduled: \(isScheduled)")

        // Esegui eliminazione in modo asincrono per evitare crash
        Task { @MainActor in
            // Piccolo delay per assicurarsi che eventuali animazioni siano completate
            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 secondi

            print("⏳ [DEBUG] Executing deletion...")

            if deleteAll && isRecurring {
                // Elimina tutte le transazioni della ricorrenza
                let templateId = parentRecurringId ?? transactionId

                let allRelated = transactions.filter {
                    $0.id == templateId || $0.parentRecurringTransactionId == templateId
                }

                print("   Deleting \(allRelated.count) related transactions")
                for related in allRelated {
                    let relatedId = related.id
                    let relatedIsScheduled = related.isScheduled

                    if relatedIsScheduled {
                        LocalNotificationManager.shared.cancelNotification(transactionId: relatedId)
                    }
                    modelContext.delete(related)
                }
            } else {
                // Elimina solo questa transazione
                if let transactionToDelete = transactions.first(where: { $0.id == transactionId }) {
                    if isScheduled {
                        LocalNotificationManager.shared.cancelNotification(transactionId: transactionId)
                    }
                    modelContext.delete(transactionToDelete)
                    print("   ✅ Deleted single transaction")
                }
            }

            // Aggiorna i saldi degli account coinvolti usando i riferimenti salvati
            if let account = accountToUpdate {
                account.updateBalance(context: modelContext)
            }

            if let destinationAccount = destinationAccountToUpdate {
                destinationAccount.updateBalance(context: modelContext)
            }

            try? modelContext.save()
            print("✅ [DEBUG] TodayView.deleteTransaction - COMPLETED")
        }
    }
}

// MARK: - Transaction Row View

struct TransactionRowView: View {
    @Environment(\.appSettings) var appSettings
    @Environment(\.colorScheme) var colorScheme
    let transaction: Transaction
    var isCompact: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconBackgroundColor)
                    .frame(width: 44, height: 44)

                Image(systemName: transaction.category?.icon ?? defaultIcon)
                    .font(.system(size: 18))
                    .foregroundStyle(iconColor)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.category?.name ?? transaction.transactionType.rawValue)
                    .font(.body)
                    .foregroundStyle(.primary)

                HStack(spacing: 4) {
                    if transaction.isScheduled {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(transaction.scheduledDate?.formatted(date: .omitted, time: .shortened) ?? "")
                            .font(.caption)
                    } else {
                        Text(transaction.date.formatted(date: .omitted, time: .shortened))
                            .font(.caption)
                    }

                    if transaction.isScheduled, let icon = scheduleIcon {
                        Image(systemName: icon)
                            .font(.caption2)
                    }
                }
                .foregroundStyle(.secondary)
            }

            Spacer()

            // Amount with colored background
            Text(transaction.displayAmount)
                .font(.body.bold())
                .foregroundStyle(amountTextColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(amountBackgroundColor)
                )
        }
    }

    private var iconBackgroundColor: Color {
        if transaction.isScheduled {
            return .orange.opacity(0.15)
        }
        return (transaction.category?.color ?? appSettings.accentColor).opacity(0.15)
    }

    private var iconColor: Color {
        if transaction.isScheduled {
            return .orange
        }
        return transaction.category?.color ?? appSettings.accentColor
    }

    private var defaultIcon: String {
        if transaction.isScheduled {
            return "clock"
        }
        switch transaction.transactionType {
        case .expense: return "cart"
        case .income: return "dollarsign.circle"
        case .transfer: return "arrow.left.arrow.right"
        case .adjustment: return "plus.minus"
        }
    }

    // Background color for amount based on transaction type
    private var amountBackgroundColor: Color {
        switch transaction.transactionType {
        case .expense:
            return .red.opacity(0.15)
        case .income:
            return .green.opacity(0.15)
        case .transfer:
            return .blue.opacity(0.15)
        case .adjustment:
            return .orange.opacity(0.15)
        }
    }

    // Text color for amount based on transaction type
    private var amountTextColor: Color {
        switch transaction.transactionType {
        case .expense:
            return .red
        case .income:
            return .green
        case .transfer:
            return .blue
        case .adjustment:
            return .orange
        }
    }

    private var lineColor: Color {
        switch transaction.transactionType {
        case .expense:
            return .red
        case .income:
            return .green
        case .transfer:
            return .blue
        case .adjustment:
            return .orange
        }
    }

    private var scheduleIcon: String? {
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
