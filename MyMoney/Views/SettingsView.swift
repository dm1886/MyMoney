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
    @EnvironmentObject var appSettings: AppSettings
    @Query private var accounts: [Account]
    @Query private var transactions: [Transaction]
    @Query private var categories: [Category]
    @Query private var categoryGroups: [CategoryGroup]

    @State private var showingDeleteAllAlert = false
    @State private var isUpdatingRates = false
    @State private var showingUpdateSuccess = false
    @State private var updateError: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Valuta Preferita", selection: $appSettings.preferredCurrencyEnum) {
                        ForEach(Currency.allCases, id: \.self) { currency in
                            Text(currency.displayName)
                                .tag(currency)
                        }
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Valuta Selezionata")
                                .font(.body)
                            Text(appSettings.preferredCurrencyEnum.fullName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(appSettings.preferredCurrencyEnum.flag) \(appSettings.preferredCurrencyEnum.rawValue)")
                            .font(.title3)
                    }
                } header: {
                    Text("Valuta")
                }

                Section {
                    Picker("Tema", selection: $appSettings.themeMode) {
                        ForEach(ThemeMode.allCases, id: \.self) { mode in
                            HStack {
                                switch mode {
                                case .system:
                                    Image(systemName: "iphone")
                                case .light:
                                    Image(systemName: "sun.max.fill")
                                case .dark:
                                    Image(systemName: "moon.fill")
                                }
                                Text(mode.rawValue)
                            }
                            .tag(mode)
                        }
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Tema Selezionato")
                                .font(.body)
                            Text(themeDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        themeIcon
                    }
                } header: {
                    Text("Aspetto")
                } footer: {
                    Text("'Sistema' segue automaticamente il tema del tuo dispositivo (chiaro di giorno, scuro di notte).")
                }

                Section {
                    HStack {
                        Text("Versione")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Conti")
                        Spacer()
                        Text("\(accounts.count)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Transazioni")
                        Spacer()
                        Text("\(transactions.count)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Categorie")
                        Spacer()
                        Text("\(categories.count)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Gruppi di Categorie")
                        Spacer()
                        Text("\(categoryGroups.count)")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Informazioni")
                }

                Section {
                    BiometricAuthToggle()

                    NavigationLink(destination: BackupView()) {
                        HStack {
                            Image(systemName: "lock.shield.fill")
                                .foregroundStyle(.green)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Backup & Sicurezza")
                                Text("Esporta/Importa i tuoi dati")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Sicurezza")
                } footer: {
                    if BiometricAuthManager.shared.biometricAvailable {
                        Text("Richiedi \(BiometricAuthManager.shared.biometricName) ogni volta che apri l'app per proteggere i tuoi dati finanziari.")
                    } else {
                        Text("Configura Face ID o Touch ID nelle impostazioni del dispositivo per abilitare questa funzione.")
                    }
                }

                Section {
                    Button {
                        updateRatesAutomatically()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                .foregroundStyle(.green)

                            if isUpdatingRates {
                                ProgressView()
                                    .padding(.leading, 8)
                                Text("Aggiornamento in corso...")
                                    .foregroundStyle(.primary)
                            } else {
                                Text("Aggiorna Tassi Automaticamente")
                                    .foregroundStyle(.primary)
                            }

                            Spacer()
                        }
                    }
                    .disabled(isUpdatingRates)

                    if let lastUpdate = CurrencyConverter.shared.getLastUpdateDate() {
                        HStack {
                            Text("Ultimo Aggiornamento")
                            Spacer()
                            Text(lastUpdate.formatted(date: .abbreviated, time: .shortened))
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                    }

                    NavigationLink(destination: ExchangeRatesView()) {
                        HStack {
                            Image(systemName: "pencil.circle.fill")
                                .foregroundStyle(.blue)
                            Text("Gestisci Manualmente")
                        }
                    }
                } header: {
                    Text("Tassi di Cambio")
                } footer: {
                    Text("L'aggiornamento automatico sostituirà tutti i tassi di cambio manuali con i tassi correnti da internet.")
                }

                Section {
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
                    Text("Questa azione eliminerà tutti i conti, transazioni e categorie. Questa operazione non può essere annullata.")
                }
            }
            .navigationTitle("Impostazioni")
            .navigationBarTitleDisplayMode(.large)
            .alert("Elimina Tutti i Dati", isPresented: $showingDeleteAllAlert) {
                Button("Annulla", role: .cancel) { }
                Button("Elimina Tutto", role: .destructive) {
                    deleteAllData()
                }
            } message: {
                Text("Sei sicuro di voler eliminare tutti i dati? Questa operazione non può essere annullata.")
            }
            .alert("Tassi Aggiornati", isPresented: $showingUpdateSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("I tassi di cambio sono stati aggiornati con successo da internet!")
            }
            .alert("Errore", isPresented: .constant(updateError != nil)) {
                Button("OK", role: .cancel) {
                    updateError = nil
                }
            } message: {
                Text(updateError ?? "")
            }
        }
    }

    private func updateRatesAutomatically() {
        print("⚙️ [SettingsView] User pressed 'Aggiorna' button")
        isUpdatingRates = true
        updateError = nil

        Task {
            do {
                print("⚙️ [SettingsView] Starting currency update task...")
                try await CurrencyAPIService.shared.updateAllRates(baseCurrency: .EUR)

                print("⚙️ [SettingsView] Update successful! Showing success message...")
                await MainActor.run {
                    isUpdatingRates = false
                    showingUpdateSuccess = true
                }
            } catch {
                print("❌ [SettingsView] Update failed with error: \(error)")
                print("❌ [SettingsView] Error description: \(error.localizedDescription)")
                await MainActor.run {
                    isUpdatingRates = false
                    updateError = "Impossibile aggiornare i tassi: \(error.localizedDescription)"
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
                    .font(.title2)
                    .foregroundStyle(.blue)
            case .light:
                Image(systemName: "sun.max.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
            case .dark:
                Image(systemName: "moon.fill")
                    .font(.title2)
                    .foregroundStyle(.indigo)
            }
        }
    }

    private func deleteAllData() {
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
}

// MARK: - Biometric Auth Toggle

struct BiometricAuthToggle: View {
    @ObservedObject private var biometricManager = BiometricAuthManager.shared
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
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 4) {
                    Text(biometricManager.biometricName)
                    if !biometricManager.biometricAvailable {
                        Text("Non disponibile")
                            .font(.caption)
                            .foregroundStyle(.red)
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
        .environmentObject(AppSettings.shared)
        .modelContainer(for: [Account.self, Transaction.self, Category.self, CategoryGroup.self])
}
