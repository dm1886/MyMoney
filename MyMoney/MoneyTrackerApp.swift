//
//  MoneyTrackerApp.swift
//  MoneyTracker
//
//  Created on 2026-01-01.
//

import SwiftUI
import SwiftData
import BackgroundTasks

@main
struct MoneyTrackerApp: App {
    @State private var appSettings = AppSettings.shared
    @Environment(\.scenePhase) private var scenePhase

    // Notification delegate
    private let notificationDelegate = NotificationDelegate()

    init() {
        // Register background tasks
        BackgroundTaskManager.shared.registerBackgroundTasks()

        // Setup local notifications
        LocalNotificationManager.shared.setupNotificationCategories()
    }

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
                .environment(\.appSettings, appSettings)
                .preferredColorScheme(appSettings.themeMode.colorScheme)
                .onAppear {
                    // Start transaction scheduler and check missed transactions
                    Task { @MainActor in
                        // Configure notification delegate with model context
                        notificationDelegate.modelContext = sharedModelContainer.mainContext
                        UNUserNotificationCenter.current().delegate = notificationDelegate

                        // Request notification permissions
                        _ = await LocalNotificationManager.shared.requestPermission()

                        TransactionScheduler.shared.startScheduler(container: sharedModelContainer)

                        // Clear badge when app is opened
                        await BackgroundTaskManager.shared.clearBadge()

                        // Check for missed transactions (important if app was force-closed)
                        let missed = await MissedTransactionManager.shared.checkMissedTransactions(
                            modelContext: sharedModelContainer.mainContext
                        )

                        if missed.automatic > 0 {
                            print("✅ Executed \(missed.automatic) missed automatic transaction(s) on app launch")
                        }

                        if missed.manual > 0 {
                            print("⏳ \(missed.manual) manual transaction(s) are waiting for confirmation")
                        }

                        // Generate recurring transaction instances
                        await RecurringTransactionManager.shared.generateRecurringInstances(
                            modelContext: sharedModelContainer.mainContext,
                            monthsAhead: 3
                        )

                        // Debug: List pending notifications
                        await LocalNotificationManager.shared.listPendingNotifications()
                    }
                }
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .background:
                // App went to background - schedule background task
                print("📱 App entering background - scheduling background task")
                BackgroundTaskManager.shared.scheduleBackgroundTask()

            case .active:
                // App became active - clear badge
                print("📱 App became active - clearing badge")
                Task { @MainActor in
                    await BackgroundTaskManager.shared.clearBadge()
                }

            case .inactive:
                break

            @unknown default:
                break
            }
        }
    }
}
