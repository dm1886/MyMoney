//
//  AppSettings.swift
//  MoneyTracker
//
//  Created on 2026-01-01.
//

import Foundation
import SwiftUI
import Combine

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

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var preferredCurrency: String = Currency.EUR.rawValue {
        didSet {
            UserDefaults.standard.set(preferredCurrency, forKey: "preferredCurrency")
        }
    }

    @Published var themeMode: ThemeMode = .system {
        didSet {
            UserDefaults.standard.set(themeMode.rawValue, forKey: "themeMode")
        }
    }

    // Backward compatibility - deprecato ma mantenuto per non rompere codice esistente
    @Published var isDarkMode: Bool = false {
        didSet {
            // Quando isDarkMode cambia, aggiorna themeMode
            themeMode = isDarkMode ? .dark : .light
        }
    }

    @Published var hasCompletedOnboarding: Bool = false {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
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
