//
//  CurrencyUpdateManager.swift
//  MoneyTracker
//
//  Created on 2026-01-06.
//

import Foundation
import SwiftData
import Combine

class CurrencyUpdateManager: ObservableObject {
    @MainActor @Published var isUpdating = false
    @MainActor @Published var showSuccess = false
    @MainActor @Published var errorMessage: String?

    func updateRates(container: ModelContainer) {
        Swift.print("🔄 [UpdateManager] Starting update - Thread: \(Thread.isMainThread ? "MAIN" : "BACKGROUND")")

        Task { @MainActor in
            self.isUpdating = true
            self.errorMessage = nil
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            Swift.print("🔄 [UpdateManager] DispatchQueue started - Thread: \(Thread.isMainThread ? "MAIN" : "BACKGROUND")")

            // Create background context ON background thread
            let backgroundContext = ModelContext(container)
            Swift.print("💾 [UpdateManager] Created background context - Thread: \(Thread.isMainThread ? "MAIN" : "BACKGROUND")")

            do {
                // Fetch API
                Swift.print("🌐 [UpdateManager] Fetching API...")
                let semaphore = DispatchSemaphore(value: 0)
                var apiResponse: String?
                var apiError: Error?

                Task {
                    do {
                        apiResponse = try await CurrencyAPIService.shared.fetchRawAPI(baseCurrency: "EUR")
                    } catch {
                        apiError = error
                    }
                    semaphore.signal()
                }

                semaphore.wait()

                if let error = apiError {
                    throw error
                }

                guard let response = apiResponse else {
                    throw NSError(domain: "UpdateManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No API response"])
                }

                Swift.print("✅ [UpdateManager] API fetch completed")

                // Parse and save to database (in background)
                Swift.print("🔄 [UpdateManager] Starting parse...")
                try CurrencyAPIService.shared.parseCurrency(jsonString: response, context: backgroundContext)
                Swift.print("✅ [UpdateManager] Parse completed")

                // Update UI on main thread
                DispatchQueue.main.async {
                    Swift.print("✅ [UpdateManager] Updating UI - Thread: \(Thread.isMainThread ? "MAIN" : "BACKGROUND")")
                    self.isUpdating = false
                    self.showSuccess = true
                }

            } catch {
                Swift.print("❌ [UpdateManager] Error: \(error)")
                DispatchQueue.main.async {
                    self.isUpdating = false
                    self.errorMessage = "Errore: \(error.localizedDescription)"
                }
            }
        }

        Swift.print("🔄 [UpdateManager] Task launched, returning to caller")
    }
}
