//
//  BackupView.swift
//  MoneyTracker
//
//  Created on 2026-01-01.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct BackupView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var accounts: [Account]
    @Query private var transactions: [Transaction]
    @Query private var categories: [Category]
    @Query private var categoryGroups: [CategoryGroup]
    @Query private var currencyRecords: [CurrencyRecord]
    @Query private var exchangeRates: [ExchangeRate]

    @State private var showingExportPicker = false
    @State private var showingImportPicker = false
    @State private var showingRestoreAlert = false
    @State private var exportFileURL: URL?

    @State private var alertMessage = ""
    @State private var showingAlert = false
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var selectedExportOption: BackupExportOption = .full
    @State private var showingExportOptions = false

    var body: some View {
        List {
            // MARK: - Backup Section
            Section {
                // Selezione opzione export
                Picker("Cosa Esportare", selection: $selectedExportOption) {
                    ForEach(BackupExportOption.allCases) { option in
                        HStack {
                            Image(systemName: option.icon)
                            Text(option.rawValue)
                        }
                        .tag(option)
                    }
                }

                // Descrizione opzione selezionata
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.blue)
                    Text(selectedExportOption.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Export Backup
                Button {
                    exportBackup()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Esporta Backup")
                                .foregroundStyle(.primary)
                            Text("Salva i dati selezionati in un file")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if isExporting {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isExporting)

                // Import Backup
                Button {
                    showingImportPicker = true
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Importa Backup")
                                .foregroundStyle(.primary)
                            Text("Ripristina dati da un file")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if isImporting {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isImporting)

            } header: {
                Text("Gestione Backup")
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("💡 Scegli cosa esportare:")
                        .font(.caption.bold())
                        .foregroundStyle(.blue)

                    Text("• Solo Conti: Esporta la struttura dei conti senza transazioni")
                        .font(.caption)

                    Text("• Conti + Transazioni: Include tutte le transazioni (normali, ricorrenti, programmate)")
                        .font(.caption)

                    Text("• Backup Completo: Tutto incluso (categorie, valute, tassi, impostazioni)")
                        .font(.caption)

                    Text("⚠️ L'importazione sostituirà TUTTI i dati esistenti")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.top, 4)
                }
            }

            // MARK: - Info Section
            Section("Informazioni") {
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
                    Text("Valute")
                    Spacer()
                    Text("\(currencyRecords.count)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Tassi di Cambio")
                    Spacer()
                    Text("\(exchangeRates.count)")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Backup & Sicurezza")
        .navigationBarTitleDisplayMode(.inline)
        .fileExporter(
            isPresented: $showingExportPicker,
            document: BackupDocument(data: exportFileURL.flatMap { try? Data(contentsOf: $0) } ?? Data()),
            contentType: .json,
            defaultFilename: BackupManager.shared.getBackupFileName(option: selectedExportOption)
        ) { result in
            handleExportResult(result)
        }
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
        }
        .alert("Conferma Ripristino", isPresented: $showingRestoreAlert) {
            Button("Annulla", role: .cancel) { }
            Button("Ripristina", role: .destructive) {
                performRestore()
            }
        } message: {
            Text("Sei sicuro di voler ripristinare il backup? Tutti i dati attuali verranno sostituiti.")
        }
        .alert(alertMessage, isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        }
    }

    // MARK: - Export

    private func exportBackup() {
        isExporting = true

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let backupData = try BackupManager.shared.createBackup(
                    accounts: accounts,
                    transactions: transactions,
                    categories: categories,
                    categoryGroups: categoryGroups,
                    currencyRecords: currencyRecords,
                    exchangeRates: exchangeRates,
                    option: selectedExportOption
                )

                // Salva temporaneamente
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(BackupManager.shared.getBackupFileName())
                try backupData.write(to: tempURL)

                DispatchQueue.main.async {
                    exportFileURL = tempURL
                    showingExportPicker = true
                    isExporting = false
                }

            } catch {
                DispatchQueue.main.async {
                    isExporting = false
                    alertMessage = "Errore durante l'esportazione: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }

    private func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            alertMessage = "✅ Backup esportato con successo!"
            showingAlert = true
        case .failure(let error):
            alertMessage = "Errore: \(error.localizedDescription)"
            showingAlert = true
        }
    }

    // MARK: - Import

    @State private var pendingImportURL: URL?

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            pendingImportURL = url
            showingRestoreAlert = true

        case .failure(let error):
            alertMessage = "Errore nella selezione del file: \(error.localizedDescription)"
            showingAlert = true
        }
    }

    private func performRestore() {
        guard let url = pendingImportURL else { return }

        isImporting = true

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Accedi al file in sicurezza
                guard url.startAccessingSecurityScopedResource() else {
                    throw NSError(domain: "BackupError", code: 1, userInfo: [
                        NSLocalizedDescriptionKey: "Impossibile accedere al file"
                    ])
                }
                defer { url.stopAccessingSecurityScopedResource() }

                let data = try Data(contentsOf: url)

                DispatchQueue.main.async {
                    do {
                        let result = try BackupManager.shared.restoreBackup(
                            from: data,
                            modelContext: modelContext
                        )

                        isImporting = false
                        alertMessage = """
                        ✅ Backup ripristinato con successo!

                        Conti: \(result.accounts)
                        Transazioni: \(result.transactions)
                        Categorie: \(result.categories)
                        Valute: \(result.currencies)
                        Tassi di Cambio: \(result.rates)
                        """
                        showingAlert = true

                    } catch {
                        isImporting = false
                        alertMessage = "Errore durante il ripristino: \(error.localizedDescription)"
                        showingAlert = true
                    }
                }

            } catch {
                DispatchQueue.main.async {
                    isImporting = false
                    alertMessage = "Errore nella lettura del file: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
}

// MARK: - Document Type for Export

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

#Preview {
    NavigationStack {
        BackupView()
            .modelContainer(for: [Account.self, Transaction.self, Category.self, CategoryGroup.self])
    }
}
