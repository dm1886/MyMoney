//
//  ICloudSyncManager.swift
//  MoneyTracker
//
//  Created on 2026-01-13.
//

import Foundation
import SwiftData
import CloudKit

@Observable
final class ICloudSyncManager {
    static let shared = ICloudSyncManager()

    var isSyncing: Bool = false
    var lastSyncDate: Date?
    var syncError: String?

    private init() {
        loadLastSyncDate()
    }

    // MARK: - iCloud Status

    func checkICloudStatus() async -> Bool {
        let container = CKContainer.default()

        do {
            let status = try await container.accountStatus()
            return status == .available
        } catch {
            print("❌ [iCloud] Error checking status: \(error)")
            return false
        }
    }

    func getICloudStatusMessage() async -> String {
        let container = CKContainer.default()

        do {
            let status = try await container.accountStatus()
            switch status {
            case .available:
                return "✓ iCloud disponibile"
            case .noAccount:
                return "⚠️ Nessun account iCloud"
            case .restricted:
                return "⚠️ iCloud limitato"
            case .couldNotDetermine:
                return "⚠️ Stato sconosciuto"
            case .temporarilyUnavailable:
                return "⚠️ Temporaneamente non disponibile"
            @unknown default:
                return "⚠️ Stato sconosciuto"
            }
        } catch {
            return "❌ Errore: \(error.localizedDescription)"
        }
    }

    // MARK: - Sync Operations

    /// Forces a save to trigger CloudKit sync
    func forceSyncIfNeeded(container: ModelContainer) async {
        await MainActor.run {
            isSyncing = true
            syncError = nil
        }

        do {
            // SwiftData with CloudKit syncs automatically when you save
            // We just need to ensure all pending changes are saved
            let context = ModelContext(container)

            if context.hasChanges {
                try context.save()
                print("✅ [iCloud] Forced save to trigger sync")
            } else {
                print("ℹ️ [iCloud] No changes to sync")
            }

            // Update last sync date
            await MainActor.run {
                let now = Date()
                lastSyncDate = now
                AppSettings.shared.lastICloudSync = now
                saveLastSyncDate(now)
                isSyncing = false
            }

        } catch {
            print("❌ [iCloud] Sync error: \(error)")
            await MainActor.run {
                syncError = error.localizedDescription
                isSyncing = false
            }
        }
    }

    // MARK: - Persistence

    private func loadLastSyncDate() {
        if let date = AppSettings.shared.lastICloudSync {
            lastSyncDate = date
        }
    }

    private func saveLastSyncDate(_ date: Date) {
        UserDefaults.standard.set(date, forKey: "lastICloudSync")
    }
}
