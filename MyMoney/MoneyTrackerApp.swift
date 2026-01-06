//
//  MoneyTrackerApp.swift
//  MoneyTracker
//
//  Created on 2026-01-01.
//

import SwiftUI
import SwiftData
import Combine

@main
struct MoneyTrackerApp: App {
    @StateObject private var appSettings = AppSettings.shared

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Account.self,
            Transaction.self,
            Category.self,
            CategoryGroup.self,
            CurrencyRecord.self,    // NUOVO: Modello valute
            ExchangeRate.self       // NUOVO: Modello tassi di cambio
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])

            let context = container.mainContext

            // Setup default categories (existing)
            let fetchDescriptor = FetchDescriptor<CategoryGroup>()
            let existingGroups = try? context.fetch(fetchDescriptor)

            if existingGroups?.isEmpty ?? true {
                DefaultDataManager.createDefaultCategories(context: context)
                try? context.save()
            }

            // NUOVO: Currency migration to SwiftData
            if CurrencyMigrationManager.shared.needsMigration() {
                print("🔄 [App] Starting currency migration...")
                do {
                    try CurrencyMigrationManager.shared.performMigration(context: context)
                    print("✅ [App] Currency migration completed")

                    // Auto-download rates on first launch (in background, non-blocking)
                    Swift.print("🌐 [App] Starting automatic rate download on first launch...")

                    DispatchQueue.global(qos: .utility).async {
                        Swift.print("🔄 [App] Auto-download started - Thread: \(Thread.isMainThread ? "MAIN" : "BACKGROUND")")

                        let backgroundContext = ModelContext(container)

                        do {
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

                            if let response = apiResponse {
                                try CurrencyAPIService.shared.parseCurrency(jsonString: response, context: backgroundContext)
                                Swift.print("✅ [App] Auto-download completed successfully")
                            }
                        } catch {
                            Swift.print("⚠️ [App] Auto-download failed: \(error)")
                        }
                    }
                } catch {
                    print("❌ [App] Currency migration failed: \(error)")
                    print("⚠️ [App] App will continue with legacy currency system")
                }
            }

            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appSettings)
                .preferredColorScheme(appSettings.themeMode.colorScheme)
        }
        .modelContainer(sharedModelContainer)
    }
}
