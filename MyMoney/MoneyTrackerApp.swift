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
            CategoryGroup.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])

            let context = container.mainContext

            let fetchDescriptor = FetchDescriptor<CategoryGroup>()
            let existingGroups = try? context.fetch(fetchDescriptor)

            if existingGroups?.isEmpty ?? true {
                DefaultDataManager.createDefaultCategories(context: context)
                try? context.save()
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
