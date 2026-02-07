//
//  AppSettings.swift
//  MoneyTracker
//
//  Created on 2026-01-01.
//

import Foundation
import SwiftUI

enum ThemeMode: String, CaseIterable, Codable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var displayName: String {
        switch self {
        case .system: return "Sistema"
        case .light: return "Chiaro"
        case .dark: return "Scuro"
        }
    }

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

enum BalanceHeaderStyle: String, CaseIterable, Codable {
    case totalBalance = "Saldo Totale"
    case assetsDebts = "Attivi e Debiti"
    case onlyPositive = "Solo Positivi"
    case onlyNegative = "Solo Debiti"
    case horizontalBars = "Grafico a Barre"
    case weeklyTrend = "Trend Settimanale"

    var icon: String {
        switch self {
        case .totalBalance: return "banknote"
        case .assetsDebts: return "chart.pie"
        case .onlyPositive: return "arrow.up.circle"
        case .onlyNegative: return "arrow.down.circle"
        case .horizontalBars: return "chart.bar.xaxis"
        case .weeklyTrend: return "chart.line.uptrend.xyaxis"
        }
    }

    var description: String {
        switch self {
        case .totalBalance: return "Mostra il saldo totale di tutti i conti"
        case .assetsDebts: return "Mostra attivi e debiti separati con grafico"
        case .onlyPositive: return "Mostra solo la somma dei saldi positivi"
        case .onlyNegative: return "Mostra solo la somma dei debiti"
        case .horizontalBars: return "Grafico con barre orizzontali"
        case .weeklyTrend: return "Andamento spese ultimi 7 giorni"
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
    // IMPORTANTE: Non ha più didSet per evitare conflitti con themeMode
    var isDarkMode: Bool = false

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

    var balanceHeaderStyle: BalanceHeaderStyle = .totalBalance {
        didSet {
            UserDefaults.standard.set(balanceHeaderStyle.rawValue, forKey: "balanceHeaderStyle")
        }
    }
    
    var groupedCategoryView: Bool = false {
        didSet {
            UserDefaults.standard.set(groupedCategoryView, forKey: "groupedCategoryView")
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

        // Non aggiorniamo più isDarkMode per evitare conflitti con themeMode
        // isDarkMode è deprecato e rimane a false di default
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

        // Load balanceHeaderStyle
        if let savedStyle = UserDefaults.standard.string(forKey: "balanceHeaderStyle"),
           let style = BalanceHeaderStyle(rawValue: savedStyle) {
            self.balanceHeaderStyle = style
        }
        
        // Load groupedCategoryView
        self.groupedCategoryView = UserDefaults.standard.bool(forKey: "groupedCategoryView")
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
