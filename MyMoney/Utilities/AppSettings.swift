//
//  AppSettings.swift
//  MoneyTracker
//
//  Created on 2026-01-01.
//

import Foundation
import SwiftUI

enum ThemeMode: String, CaseIterable, Codable {
    case system = "Sistema"
    case light = "Chiaro"
    case dark = "Scuro"

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil  // nil = segui il sistema
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

// Environment key per AppSettings (pattern @Observable)
private struct AppSettingsKey: EnvironmentKey {
    static let defaultValue = AppSettings.shared
}

extension EnvironmentValues {
    var appSettings: AppSettings {
        get { self[AppSettingsKey.self] }
        set { self[AppSettingsKey.self] = newValue }
    }
}

@Observable
final class AppSettings {
    static let shared = AppSettings()

    var preferredCurrency: String = Currency.EUR.rawValue {
        didSet {
            UserDefaults.standard.set(preferredCurrency, forKey: "preferredCurrency")
        }
    }

    var themeMode: ThemeMode = .system {
        didSet {
            UserDefaults.standard.set(themeMode.rawValue, forKey: "themeMode")
        }
    }

    // Backward compatibility - deprecato ma mantenuto per non rompere codice esistente
    var isDarkMode: Bool = false {
        didSet {
            // Quando isDarkMode cambia, aggiorna themeMode
            themeMode = isDarkMode ? .dark : .light
        }
    }

    var hasCompletedOnboarding: Bool = false {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
        }
    }

    var accentColorHex: String = "#007AFF" {  // Default iOS blue
        didSet {
            UserDefaults.standard.set(accentColorHex, forKey: "accentColorHex")
        }
    }

    var accentColor: Color {
        Color(hex: accentColorHex) ?? .blue
    }

    var recurringDetectionEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(recurringDetectionEnabled, forKey: "recurringDetectionEnabled")
        }
    }

    var recurringDetectionDays: Int = 5 {
        didSet {
            UserDefaults.standard.set(recurringDetectionDays, forKey: "recurringDetectionDays")
        }
    }

    var superSecure: Bool = true {
        didSet {
            UserDefaults.standard.set(superSecure, forKey: "superSecure")
        }
    }

    var iCloudSyncEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(iCloudSyncEnabled, forKey: "iCloudSyncEnabled")
        }
    }

    // iCloud sync status (read-only, just for display)
    var lastICloudSync: Date? {
        get {
            UserDefaults.standard.object(forKey: "lastICloudSync") as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "lastICloudSync")
        }
    }

    private init() {
        self.preferredCurrency = UserDefaults.standard.string(forKey: "preferredCurrency") ?? Currency.EUR.rawValue

        // Carica themeMode da UserDefaults
        if let savedTheme = UserDefaults.standard.string(forKey: "themeMode"),
           let theme = ThemeMode(rawValue: savedTheme) {
            self.themeMode = theme
        } else {
            // Migrazione da vecchio sistema isDarkMode
            let oldDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
            self.themeMode = oldDarkMode ? .dark : .system
        }

        self.isDarkMode = (themeMode == .dark)
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        self.accentColorHex = UserDefaults.standard.string(forKey: "accentColorHex") ?? "#007AFF"
        self.recurringDetectionEnabled = UserDefaults.standard.bool(forKey: "recurringDetectionEnabled")
        self.recurringDetectionDays = UserDefaults.standard.integer(forKey: "recurringDetectionDays")
        if self.recurringDetectionDays == 0 {
            self.recurringDetectionDays = 5  // Default to 5 days
        }

        // Load superSecure, default to true (most secure behavior)
        if UserDefaults.standard.object(forKey: "superSecure") != nil {
            self.superSecure = UserDefaults.standard.bool(forKey: "superSecure")
        } else {
            self.superSecure = true  // Default to true for existing users
        }
    }

    var preferredCurrencyEnum: Currency {
        get {
            Currency(rawValue: preferredCurrency) ?? .EUR
        }
        set {
            preferredCurrency = newValue.rawValue
        }
    }
}
