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
            CurrencyRecord.self,    // Modello valute
            ExchangeRate.self,      // Modello tassi di cambio
            Budget.self             // Modello budget
        ])

        // Enable iCloud sync with CloudKit
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

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
                } catch {
                    print("❌ [App] Currency migration failed: \(error)")
                    print("⚠️ [App] App will continue with legacy currency system")
                }
            }

            // Populate currency cache to avoid main thread I/O
            CurrencyService.shared.populateCache(context: context)

            // Download exchange rates only on first app launch
            let isFirstLaunch = !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
            if isFirstLaunch {
                print("🌐 [App] First launch detected - downloading exchange rates...")
                UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")

                DispatchQueue.global(qos: .utility).async {
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
                            Swift.print("✅ [App] First launch exchange rates downloaded successfully")
                        }
                    } catch {
                        Swift.print("⚠️ [App] First launch rate download failed: \(error)")
                        Swift.print("   You can download rates manually from Settings")
                    }
                }
            } else {
                print("ℹ️ [App] Not first launch - skipping automatic rate download")
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
                .tint(appSettings.accentColor)  // Applica accent color globalmente
                .onAppear {
                    // Start transaction scheduler and check missed transactions
                    Task { @MainActor in
                        // Refresh currency cache on app appear
                        CurrencyService.shared.populateCache(context: sharedModelContainer.mainContext)

                        // Configure notification delegate with model context
                        notificationDelegate.modelContext = sharedModelContainer.mainContext
                        UNUserNotificationCenter.current().delegate = notificationDelegate

                        // Request notification permissions
                        _ = await LocalNotificationManager.shared.requestPermission()

                        // Clean orphan notifications (notifications for deleted transactions)
                        let descriptor = FetchDescriptor<Transaction>()
                        if let allTransactions = try? sharedModelContainer.mainContext.fetch(descriptor) {
                            let validIds = Set(allTransactions.map { $0.id })
                            let orphanCount = await LocalNotificationManager.shared.cleanOrphanNotifications(validTransactionIds: validIds)
                            if orphanCount > 0 {
                                print("🧹 Cleaned \(orphanCount) orphan notification(s) on app launch")
                            }
                        }

                        TransactionScheduler.shared.startScheduler(container: sharedModelContainer)

                        // Clear badge when app is opened
                        await BackgroundTaskManager.shared.clearBadge()

                        // Check for missed transactions (important if app was force-closed)
                        let missed = await MissedTransactionManager.shared.checkMissedTransactions(
                            modelContext: sharedModelContainer.mainContext
                        )

                        if missed.automatic > 0 {
                            LogManager.shared.success("Executed \(missed.automatic) missed automatic transaction(s) on app launch", category: "AppLaunch")
                        }

                        if missed.manual > 0 {
                            LogManager.shared.warning("\(missed.manual) manual transaction(s) are waiting for confirmation", category: "AppLaunch")

                            // Set badge to notify user
                            try? await UNUserNotificationCenter.current().setBadgeCount(missed.manual)

                            // Send local notification to alert user
                            let content = UNMutableNotificationContent()
                            content.title = "Transazioni in Attesa"
                            content.body = missed.manual == 1
                                ? "1 transazione programmata è in attesa di conferma"
                                : "\(missed.manual) transazioni programmate sono in attesa di conferma"
                            content.sound = .default
                            content.badge = NSNumber(value: missed.manual)

                            let request = UNNotificationRequest(
                                identifier: "missed-transactions-\(Date().timeIntervalSince1970)",
                                content: content,
                                trigger: nil  // Deliver immediately
                            )

                            try? await UNUserNotificationCenter.current().add(request)
                        }

                        // Generate recurring transaction instances (12 months ahead)
                        await RecurringTransactionManager.shared.generateRecurringInstances(
                            modelContext: sharedModelContainer.mainContext,
                            monthsAhead: 12
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
                // App became active - clear badge and regenerate recurring instances
                Task { @MainActor in
                    await BackgroundTaskManager.shared.clearBadge()

                    // Regenerate recurring transaction instances (extends 12 months from today)
                    // This ensures "forever" recurring transactions always have future instances
                    await RecurringTransactionManager.shared.generateRecurringInstances(
                        modelContext: sharedModelContainer.mainContext,
                        monthsAhead: 12
                    )
                }

            case .inactive:
                break

            @unknown default:
                break
            }
        }
    }
}
