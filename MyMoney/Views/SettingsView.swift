//
//  SettingsView.swift
//  MoneyTracker
//
//  Created on 2026-01-01.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appSettings) var appSettings
    @Query private var accounts: [Account]
    @Query private var transactions: [Transaction]
    @Query private var categories: [Category]
    @Query private var categoryGroups: [CategoryGroup]
    @Query private var allCurrencies: [CurrencyRecord]

    @State private var showingDeleteAllAlert = false
    @State private var showingDeleteRecurringAlert = false
    @State private var showingDeleteScheduledAlert = false
    @State private var updateManager = CurrencyUpdateManager()
    @State private var selectedPreferredCurrency: CurrencyRecord?
    @State private var orphanNotificationsCount: Int?
    @State private var iCloudManager = ICloudSyncManager.shared
    @State private var iCloudStatus: String = "Controllo..."

    var pendingTransactionsCount: Int {
        transactions.filter { $0.status == .pending && $0.isScheduled }.count
    }

    var recurringTransactionsCount: Int {
        // Count all recurring transactions (templates + instances)
        transactions.filter { $0.isRecurring || $0.parentRecurringTransactionId != nil }.count
    }

    var scheduledTransactionsCount: Int {
        // Count all scheduled transactions (pending)
        transactions.filter { $0.isScheduled && $0.status == .pending }.count
    }

    var body: some View {
        @Bindable var settings = appSettings

        NavigationStack {
            List {
                HStack(spacing: 12) {
                    OrbView(size: 64, isAnimating: false) { Image(systemName: "slider.horizontal.3") }
                        .accessibilityHidden(true)
                    Text("Impostazioni").font(.orbTitle)
                }.listRowBackground(Color.clear).listRowSeparator(.hidden)
                UserAccountSection()
                // MARK: - Customization Section
                Section {
                    ThemeStrip()
                    NavigationLink {
                        ThemePickerView()
                    } label: {
                        OrbListRow(icon: "paintpalette.fill", title: "Tema colori", subtitle: "Scegli, crea e modifica i tuoi temi")
                    }
                    Toggle("Animazioni ridotte", isOn: $settings.reduceDecorativeMotion)

                    NavigationLink(destination: CategoriesView()) {
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundStyle(Color.orbHighlight)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Categorie")
                                Text("Gestisci le tue categorie e gruppi")
                                    .font(.orbCaption)
                                    .foregroundStyle(Color.orbMuted)
                            }
                        }
                    }

                    NavigationLink {
                        BalanceHeaderStylePicker()
                    } label: {
                        HStack {
                            Image(systemName: appSettings.balanceHeaderStyle.icon)
                                .foregroundStyle(Color.orbHighlight)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Stile Intestazione Bilancio")
                                Text(appSettings.balanceHeaderStyle.rawValue)
                                    .font(.orbCaption)
                                    .foregroundStyle(Color.orbMuted)
                            }
                        }
                    }
                    
                    Toggle(isOn: $settings.groupedCategoryView) {
                        HStack {
                            Image(systemName: "square.grid.2x2.fill")
                                .foregroundStyle(Color.orbHighlight)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Vista Categorie Raggruppata")
                                Text(settings.groupedCategoryView ? "Griglia con gruppi" : "Lista completa")
                                    .font(.orbCaption)
                                    .foregroundStyle(Color.orbMuted)
                            }
                        }
                    }
                } header: {
                    Text("Aspetto e personalizzazione")
                } footer: {
                    Text("Scegli il tema dell'app, gestisci le categorie e personalizza la visualizzazione del bilancio. La vista raggruppata mostra le categorie organizzate per gruppi con indicatori budget.")
                }.listRowBackground(Color.orbCard)
                Section {
                    Picker("Modalità", selection: $settings.themeMode) {
                        ForEach(ThemeMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }.pickerStyle(.segmented)

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Tema Selezionato")
                                .font(.orbBody)
                            Text(themeDescription)
                                .font(.orbCaption)
                                .foregroundStyle(Color.orbMuted)
                        }
                        Spacer()
                        themeIcon
                    }
                } header: {
                    Text("Aspetto")
                } footer: {
                    Text("'Sistema' segue automaticamente il tema del tuo dispositivo (chiaro di giorno, scuro di notte).")
                }.listRowBackground(Color.orbCard)

                Section {
                    NavigationLink {
                        CurrencySelectionView(selectedCurrency: $selectedPreferredCurrency)
                    } label: {
                        HStack {
                            Text("Valuta Preferita")
                                .foregroundStyle(Color.orbText)

                            Spacer()

                            if let currency = selectedPreferredCurrency {
                                HStack(spacing: 8) {
                                    Text(currency.flagEmoji)
                                    Text(currency.code)
                                        .foregroundStyle(Color.orbMuted)
                                }
                            }
                        }
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Valuta Selezionata")
                                .font(.orbBody)
                            Text(selectedPreferredCurrency?.name ?? appSettings.preferredCurrencyEnum.fullName)
                                .font(.orbCaption)
                                .foregroundStyle(Color.orbMuted)
                        }
                        Spacer()
                        if let currency = selectedPreferredCurrency {
                            Text("\(currency.flagEmoji) \(currency.code)")
                                .font(.orbTitle3)
                        } else {
                            Text("\(appSettings.preferredCurrencyEnum.flag) \(appSettings.preferredCurrencyEnum.rawValue)")
                                .font(.orbTitle3)
                        }
                    }
                } header: {
                    Text("Valuta")
                }.listRowBackground(Color.orbCard)


                Section {
                    NavigationLink(destination: BudgetListView()) {
                        HStack {
                            Image(systemName: "chart.pie.fill")
                                .foregroundStyle(Color.orbPositive)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Budget")
                                Text("Gestisci i tuoi budget per categoria")
                                    .font(.orbCaption)
                                    .foregroundStyle(Color.orbMuted)
                            }
                        }
                    }

                    NavigationLink(destination: RecurringExpensesView()) {
                        HStack {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .foregroundStyle(Color.orbHighlight)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Spese Ricorrenti")
                                Text("Categorie utilizzate frequentemente")
                                    .font(.orbCaption)
                                    .foregroundStyle(Color.orbMuted)
                            }
                        }
                    }

                    Toggle(isOn: $settings.recurringDetectionEnabled) {
                        HStack {
                            Image(systemName: "repeat.circle.fill")
                                .foregroundStyle(Color.orbHighlight)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Rilevamento Ricorrenti")
                                Text("Rileva automaticamente transazioni ripetitive")
                                    .font(.orbCaption)
                                    .foregroundStyle(Color.orbMuted)
                            }
                        }
                    }

                    if settings.recurringDetectionEnabled {
                        Picker("Soglia Giorni", selection: $settings.recurringDetectionDays) {
                            Text("3 giorni").tag(3)
                            Text("5 giorni").tag(5)
                            Text("8 giorni").tag(8)
                            Text("10 giorni").tag(10)
                        }
                        .pickerStyle(.menu)
                    }
                } header: {
                    Text("Monitoraggio Spese")
                } footer: {
                    if settings.recurringDetectionEnabled {
                        Text("Imposta budget per le categorie e monitora le spese ricorrenti. Se una transazione viene ripetuta 3 volte negli ultimi \(settings.recurringDetectionDays) giorni, verrà suggerita automaticamente nella pagina Oggi.")
                    } else {
                        Text("Imposta budget per le categorie e monitora le spese ricorrenti per un migliore controllo delle tue finanze.")
                    }
                }.listRowBackground(Color.orbCard)


                Section {
                    HStack {
                        Text("Versione")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(Color.orbMuted)
                    }

                    HStack {
                        Text("Conti")
                        Spacer()
                        Text("\(accounts.count)")
                            .foregroundStyle(Color.orbMuted)
                    }

                    HStack {
                        Text("Transazioni")
                        Spacer()
                        Text("\(transactions.count)")
                            .foregroundStyle(Color.orbMuted)
                    }

                    HStack {
                        Text("Categorie")
                        Spacer()
                        Text("\(categories.count)")
                            .foregroundStyle(Color.orbMuted)
                    }

                    HStack {
                        Text("Gruppi di Categorie")
                        Spacer()
                        Text("\(categoryGroups.count)")
                            .foregroundStyle(Color.orbMuted)
                    }
                } header: {
                    Text("Informazioni")
                }.listRowBackground(Color.orbCard)

                Section {
                    NavigationLink(destination: PendingTransactionsView()) {
                        HStack {
                            Image(systemName: "clock.badge.exclamationmark")
                                .foregroundStyle(Color.orbHighlight)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Da Confermare")
                                Text("Transazioni in attesa di conferma")
                                    .font(.orbCaption)
                                    .foregroundStyle(Color.orbMuted)
                            }
                            Spacer()
                            if pendingTransactionsCount > 0 {
                                Text("\(pendingTransactionsCount)")
                                    .font(.orbCaption.bold())
                                    .foregroundStyle(Color.orbOnAccent)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(Color.orbHighlight))
                            }
                        }
                    }

                    NavigationLink(destination: ScheduledTransactionsView()) {
                        HStack {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundStyle(Color.orbHighlight)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Gestisci Programmate")
                                Text("Tutte le transazioni programmate")
                                    .font(.orbCaption)
                                    .foregroundStyle(Color.orbMuted)
                            }
                        }
                    }
                } header: {
                    Text("Transazioni Programmate")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Le transazioni programmate vengono eseguite automaticamente o richiedono conferma manuale alla data impostata.")

                        Text("⚠️ IMPORTANTE: NON chiudere forzatamente l'app")
                            .font(.orbCaption.bold())
                            .foregroundStyle(Color.orbHighlight)

                        Text("Per ricevere notifiche e badge quando l'app è chiusa, premi solo il tasto Home. Se forzi la chiusura (swipe up), iOS blocca tutte le notifiche in background.")
                            .font(.orbCaption)

                        Text("Le transazioni automatiche scadute verranno eseguite quando riapri l'app.")
                            .font(.orbCaption)
                            .foregroundStyle(Color.orbMuted)
                    }
                }.listRowBackground(Color.orbCard)

                Section {
                    BiometricAuthToggle()

                    if BiometricAuthManager.shared.isBiometricEnabled {
                        Toggle(isOn: $settings.superSecure) {
                            HStack {
                                Image(systemName: "shield.lefthalf.filled")
                                    .foregroundStyle(Color.orbHighlight)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Super Secure")
                                    Text(settings.superSecure ? "Blocca in background" : "Blocca solo alla chiusura")
                                        .font(.orbCaption)
                                        .foregroundStyle(Color.orbMuted)
                                }
                            }
                        }
                    }

                    NavigationLink(destination: BackupView()) {
                        HStack {
                            Image(systemName: "lock.shield.fill")
                                .foregroundStyle(Color.orbPositive)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Backup & Sicurezza")
                                Text("Esporta/Importa i tuoi dati")
                                    .font(.orbCaption)
                                    .foregroundStyle(Color.orbMuted)
                            }
                        }
                    }
                } header: {
                    Text("Sicurezza")
                } footer: {
                    if BiometricAuthManager.shared.biometricAvailable {
                        if BiometricAuthManager.shared.isBiometricEnabled {
                            Text("Richiedi \(BiometricAuthManager.shared.biometricName) ogni volta che apri l'app. Super Secure controlla quando richiedere l'autenticazione: ON blocca anche quando vai in background, OFF blocca solo quando chiudi completamente l'app.")
                        } else {
                            Text("Richiedi \(BiometricAuthManager.shared.biometricName) ogni volta che apri l'app per proteggere i tuoi dati finanziari.")
                        }
                    } else {
                        Text("Configura Face ID o Touch ID nelle impostazioni del dispositivo per abilitare questa funzione.")
                    }
                }.listRowBackground(Color.orbCard)

                Section {
                    HStack {
                        Image(systemName: "icloud.fill")
                            .foregroundStyle(Color.orbHighlight)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Stato iCloud")
                            Text(iCloudStatus)
                                .font(.orbCaption)
                                .foregroundStyle(Color.orbMuted)
                        }
                        Spacer()
                        if iCloudStatus.contains("✓") {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.orbPositive)
                        } else if iCloudStatus.contains("⚠️") || iCloudStatus.contains("❌") {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.orbHighlight)
                        }
                    }

                    Button {
                        Task {
                            await iCloudManager.forceSyncIfNeeded(container: modelContext.container)
                        }
                    } label: {
                        HStack {
                            OrbSyncSymbol(systemName: "arrow.triangle.2.circlepath.circle.fill", isActive: iCloudManager.isSyncing)
                                .foregroundStyle(Color.orbHighlight)

                            if iCloudManager.isSyncing {
                                ProgressView()
                                    .padding(.leading, 8)
                                Text("Sincronizzazione...")
                                    .foregroundStyle(Color.orbText)
                            } else {
                                Text("Forza Sincronizzazione")
                                    .foregroundStyle(Color.orbText)
                            }

                            Spacer()
                        }
                    }
                    .disabled(iCloudManager.isSyncing || !iCloudStatus.contains("✓"))

                    if let lastSync = iCloudManager.lastSyncDate {
                        HStack {
                            Text("Ultima Sincronizzazione")
                            Spacer()
                            Text(lastSync.formatted(date: .abbreviated, time: .shortened))
                                .foregroundStyle(Color.orbMuted)
                        }
                        .font(.orbCaption)
                    }
                } header: {
                    Text("iCloud Sync")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("I tuoi dati vengono sincronizzati automaticamente con iCloud quando disponibile. La sincronizzazione avviene in background e mantiene tutti i tuoi dispositivi aggiornati.")

                        if let error = iCloudManager.syncError {
                            Text("⚠️ Errore: \(error)")
                                .font(.orbCaption)
                                .foregroundStyle(Color.orbNegative)
                        }

                        Text("Nota: Assicurati di aver configurato iCloud nelle Capabilities del progetto Xcode.")
                            .font(.orbCaption)
                            .foregroundStyle(Color.orbHighlight)
                    }
                }.listRowBackground(Color.orbCard)

                Section {
                    Button {
                        updateManager.updateRates(container: modelContext.container)
                    } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                .foregroundStyle(Color.orbPositive)

                            if updateManager.isUpdating {
                                ProgressView()
                                    .padding(.leading, 8)
                                Text("Aggiornamento in corso...")
                                    .foregroundStyle(Color.orbText)
                            } else {
                                Text("Aggiorna Tassi Automaticamente")
                                    .foregroundStyle(Color.orbText)
                            }

                            Spacer()
                        }
                    }
                    .disabled(updateManager.isUpdating)

                    if let lastUpdate = CurrencyService.shared.getLastUpdateDate(context: modelContext) {
                        HStack {
                            Text("Ultimo Aggiornamento")
                            Spacer()
                            Text(lastUpdate.formatted(date: .abbreviated, time: .shortened))
                                .foregroundStyle(Color.orbMuted)
                        }
                        .font(.orbCaption)
                    }

                    NavigationLink(destination: ExchangeRatesView()) {
                        HStack {
                            Image(systemName: "pencil.circle.fill")
                                .foregroundStyle(Color.orbHighlight)
                            Text("Gestisci Manualmente")
                        }
                    }
                } header: {
                    Text("Tassi di Cambio")
                } footer: {
                    Text("L'aggiornamento automatico sostituirà tutti i tassi di cambio manuali con i tassi correnti da internet.")
                }.listRowBackground(Color.orbCard)

                Section {
                    Button(role: .destructive) {
                        showingDeleteRecurringAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "repeat.circle")
                                .foregroundStyle(Color.orbNegative)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Elimina Tutte le Ricorrenti")
                                if recurringTransactionsCount > 0 {
                                    Text("\(recurringTransactionsCount) transazioni")
                                        .font(.orbCaption)
                                        .foregroundStyle(Color.orbMuted)
                                } else {
                                    Text("Nessuna transazione ricorrente")
                                        .font(.orbCaption)
                                        .foregroundStyle(Color.orbMuted)
                                }
                            }
                            Spacer()
                        }
                    }
                    .disabled(recurringTransactionsCount == 0)

                    Button(role: .destructive) {
                        showingDeleteScheduledAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundStyle(Color.orbNegative)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Elimina Tutte le Programmate")
                                if scheduledTransactionsCount > 0 {
                                    Text("\(scheduledTransactionsCount) transazioni")
                                        .font(.orbCaption)
                                        .foregroundStyle(Color.orbMuted)
                                } else {
                                    Text("Nessuna transazione programmata")
                                        .font(.orbCaption)
                                        .foregroundStyle(Color.orbMuted)
                                }
                            }
                            Spacer()
                        }
                    }
                    .disabled(scheduledTransactionsCount == 0)

                    NavigationLink {
                        DatabaseDebugView()
                    } label: {
                        HStack {
                            Image(systemName: "ladybug")
                                .foregroundStyle(Color.orbHighlight)
                            Text("Database Debug")
                            Spacer()
                        }
                    }

                    NavigationLink {
                        HapticTestView()
                    } label: {
                        HStack {
                            Image(systemName: "waveform.path")
                                .foregroundStyle(Color.orbHighlight)
                            Text("Test Haptic Feedback")
                            Spacer()
                        }
                    }

                    NavigationLink {
                        LogsView()
                    } label: {
                        HStack {
                            Image(systemName: "doc.text.magnifyingglass")
                                .foregroundStyle(Color.orbHighlight)
                            Text("Log Sistema")
                            Spacer()
                        }
                    }

                    Button {
                        cleanOrphanNotifications()
                    } label: {
                        HStack {
                            Image(systemName: "bell.slash")
                                .foregroundStyle(Color.orbHighlight)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Pulisci Notifiche Orfane")
                                Text("Rimuovi notifiche per transazioni eliminate")
                                    .font(.orbCaption)
                                    .foregroundStyle(Color.orbMuted)
                            }
                            Spacer()
                            if let count = orphanNotificationsCount, count > 0 {
                                Text("\(count)")
                                    .font(.orbCaption.bold())
                                    .foregroundStyle(Color.orbOnAccent)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(Color.orbHighlight))
                            }
                        }
                    }

                    Button(role: .destructive) {
                        showingDeleteAllAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Elimina Tutti i Dati")
                            Spacer()
                        }
                    }
                } header: {
                    Text("Zona Pericolosa")
                } footer: {
                    Text("Le transazioni ricorrenti includono template e tutte le transazioni generate. Le transazioni programmate sono tutte quelle in attesa. 'Elimina Tutti i Dati' rimuoverà conti, transazioni e categorie.")
                }.listRowBackground(Color.orbCard)
            }.orbScreen().background(OrbTabReselect(tab: 4))
            .navigationTitle("Impostazioni")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarTitleDisplayMode(.large)
            .alert("Elimina Transazioni Ricorrenti", isPresented: $showingDeleteRecurringAlert) {
                Button("Annulla", role: .cancel) { }
                Button("Elimina Tutto", role: .destructive) {
                    deleteAllRecurringTransactions()
                }
            } message: {
                Text("Sei sicuro di voler eliminare tutte le \(recurringTransactionsCount) transazioni ricorrenti (template e transazioni)? Questa operazione non può essere annullata.")
            }
            .alert("Elimina Transazioni Programmate", isPresented: $showingDeleteScheduledAlert) {
                Button("Annulla", role: .cancel) { }
                Button("Elimina Tutto", role: .destructive) {
                    deleteAllScheduledTransactions()
                }
            } message: {
                Text("Sei sicuro di voler eliminare tutte le \(scheduledTransactionsCount) transazioni programmate? Questa operazione non può essere annullata.")
            }
            .alert("Elimina Tutti i Dati", isPresented: $showingDeleteAllAlert) {
                Button("Annulla", role: .cancel) { }
                Button("Elimina Tutto", role: .destructive) {
                    deleteAllData()
                }
            } message: {
                Text("Sei sicuro di voler eliminare tutti i dati? Questa operazione non può essere annullata.")
            }
            .alert("Tassi Aggiornati", isPresented: $updateManager.showSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("I tassi di cambio sono stati aggiornati con successo da internet!")
            }
            .alert("Errore", isPresented: .constant(updateManager.errorMessage != nil)) {
                Button("OK", role: .cancel) {
                    updateManager.errorMessage = nil
                }
            } message: {
                Text(updateManager.errorMessage ?? "")
            }
            .onAppear {
                // Initialize selected preferred currency
                if selectedPreferredCurrency == nil {
                    selectedPreferredCurrency = allCurrencies.first { $0.code == appSettings.preferredCurrencyEnum.rawValue }
                }

                // Set default iCloud status (disabled to avoid crash without dev account)
                iCloudStatus = "⚠️ iCloud non configurato"

                // Uncomment when iCloud is properly configured in Xcode:
                // Task {
                //     iCloudStatus = await iCloudManager.getICloudStatusMessage()
                // }
            }
            .onChange(of: selectedPreferredCurrency) { oldValue, newValue in
                // Update AppSettings when currency changes
                if let newCurrency = newValue {
                    if let currencyEnum = Currency(rawValue: newCurrency.code) {
                        appSettings.preferredCurrencyEnum = currencyEnum
                    }
                }
            }
        }
    }

    private var themeDescription: String {
        switch appSettings.themeMode {
        case .system:
            return "Segue il tema del dispositivo"
        case .light:
            return "Sempre in modalità chiara"
        case .dark:
            return "Sempre in modalità scura"
        }
    }

    private var themeIcon: some View {
        Group {
            switch appSettings.themeMode {
            case .system:
                Image(systemName: "iphone")
                    .font(.orbTitle2)
                    .foregroundStyle(Color.orbHighlight)
            case .light:
                Image(systemName: "sun.max.fill")
                    .font(.orbTitle2)
                    .foregroundStyle(Color.orbHighlight)
            case .dark:
                Image(systemName: "moon.fill")
                    .font(.orbTitle2)
                    .foregroundStyle(Color.orbHighlight)
            }
        }
    }

    private func deleteAllRecurringTransactions() {
        print("🗑️ Deleting all recurring transactions...")

        // Find all recurring transactions (templates + instances)
        let recurringTransactions = transactions.filter { transaction in
            transaction.isRecurring || transaction.parentRecurringTransactionId != nil
        }

        print("   Found \(recurringTransactions.count) recurring transactions to delete")

        // Cancel notifications and delete
        for transaction in recurringTransactions {
            // IMPORTANTE: Salva l'ID PRIMA di operare
            let transactionId = transaction.id
            let isScheduled = transaction.isScheduled

            if isScheduled {
                LocalNotificationManager.shared.cancelNotification(transactionId: transactionId)
            }
            modelContext.delete(transaction)
        }

        // Update account balances for executed transactions that were deleted
        for account in accounts {
            account.updateBalance(context: modelContext)
        }

        do {
            try modelContext.save()
            print("✅ All recurring transactions deleted successfully")
        } catch {
            print("❌ Error deleting recurring transactions: \(error)")
        }
    }

    private func deleteAllScheduledTransactions() {
        print("🗑️ Deleting all scheduled transactions...")

        // Find all scheduled pending transactions
        let scheduledTransactions = transactions.filter { transaction in
            transaction.isScheduled && transaction.status == .pending
        }

        print("   Found \(scheduledTransactions.count) scheduled transactions to delete")

        // Cancel notifications and delete
        for transaction in scheduledTransactions {
            // IMPORTANTE: Salva l'ID PRIMA di eliminare
            let transactionId = transaction.id
            LocalNotificationManager.shared.cancelNotification(transactionId: transactionId)
            modelContext.delete(transaction)
        }

        // Update account balances
        for account in accounts {
            account.updateBalance(context: modelContext)
        }

        do {
            try modelContext.save()
            print("✅ All scheduled transactions deleted successfully")
        } catch {
            print("❌ Error deleting scheduled transactions: \(error)")
        }
    }

    private func deleteAllData() {
        // IMPORTANTE: Cancella tutte le notifiche PRIMA di eliminare le transazioni
        print("🔔 [DEBUG] Cancelling all notifications before deleting data...")
        for transaction in transactions {
            if transaction.isScheduled {
                LocalNotificationManager.shared.cancelNotification(transactionId: transaction.id)
            }
        }
        print("   ✅ All notifications cancelled")

        for transaction in transactions {
            modelContext.delete(transaction)
        }

        for account in accounts {
            modelContext.delete(account)
        }

        for category in categories {
            modelContext.delete(category)
        }

        for group in categoryGroups {
            modelContext.delete(group)
        }

        try? modelContext.save()

        DefaultDataManager.createDefaultCategories(context: modelContext)
        try? modelContext.save()
    }

    private func cleanOrphanNotifications() {
        Task {
            let validIds = Set(transactions.map { $0.id })
            let count = await LocalNotificationManager.shared.cleanOrphanNotifications(validTransactionIds: validIds)
            orphanNotificationsCount = count
            print("🧹 Cleaned \(count) orphan notification(s)")
        }
    }
}

// MARK: - Biometric Auth Toggle

struct BiometricAuthToggle: View {
    @State private var biometricManager = BiometricAuthManager.shared
    @State private var showingAuthError = false
    @State private var errorMessage = ""

    var body: some View {
        Toggle(isOn: Binding(
            get: { biometricManager.isBiometricEnabled },
            set: { newValue in
                if newValue {
                    enableBiometric()
                } else {
                    biometricManager.disableBiometric()
                }
            }
        )) {
            HStack {
                Image(systemName: biometricIcon)
                    .foregroundStyle(Color.orbHighlight)
                VStack(alignment: .leading, spacing: 4) {
                    Text(biometricManager.biometricName)
                    if !biometricManager.biometricAvailable {
                        Text("Non disponibile")
                            .font(.orbCaption)
                            .foregroundStyle(Color.orbNegative)
                    }
                }
            }
        }
        .disabled(!biometricManager.biometricAvailable)
        .alert("Errore Autenticazione", isPresented: $showingAuthError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    private var biometricIcon: String {
        switch biometricManager.biometricType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        case .none:
            return "lock.fill"
        }
    }

    private func enableBiometric() {
        // First authenticate to enable
        biometricManager.authenticate(reason: "Abilita \(biometricManager.biometricName) per MoneyTracker") { success, error in
            if success {
                biometricManager.enableBiometric()
            } else {
                errorMessage = biometricManager.getErrorMessage(for: error)
                showingAuthError = true
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(\.appSettings, AppSettings.shared)
        .modelContainer(for: [Account.self, Transaction.self, Category.self, CategoryGroup.self])
}
