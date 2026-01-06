//
//  BiometricAuthManager.swift
//  MoneyTracker
//
//  Created on 2026-01-01.
//

import Foundation
import LocalAuthentication
import Combine

enum BiometricType {
    case none
    case touchID
    case faceID
}

final class BiometricAuthManager: ObservableObject {
    static let shared = BiometricAuthManager()

    @Published var isAuthenticated: Bool = false
    @Published var isBiometricEnabled: Bool = false
    @Published var authenticationError: String?

    private let biometricEnabledKey = "biometricAuthEnabled"

    private init() {
        loadSettings()
    }

    // MARK: - Biometric Availability

    var biometricType: BiometricType {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }

        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        default:
            return .none
        }
    }

    var biometricAvailable: Bool {
        return biometricType != .none
    }

    var biometricName: String {
        switch biometricType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .none:
            return "Biometrics"
        }
    }

    // MARK: - Authentication

    func authenticate(reason: String = "Accedi per visualizzare i tuoi dati finanziari", completion: @escaping (Bool, Error?) -> Void) {
        let context = LAContext()
        var error: NSError?

        // Check if biometric authentication is available
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            DispatchQueue.main.async {
                self.authenticationError = error?.localizedDescription ?? "Biometric authentication not available"
                completion(false, error)
            }
            return
        }

        // Perform authentication
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authError in
            DispatchQueue.main.async {
                if success {
                    self.isAuthenticated = true
                    self.authenticationError = nil
                    completion(true, nil)
                } else {
                    self.isAuthenticated = false
                    self.authenticationError = authError?.localizedDescription
                    completion(false, authError)
                }
            }
        }
    }

    // Async/await version
    func authenticate(reason: String = "Accedi per visualizzare i tuoi dati finanziari") async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            authenticate(reason: reason) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: success)
                }
            }
        }
    }

    // MARK: - Settings Management

    func enableBiometric() {
        isBiometricEnabled = true
        UserDefaults.standard.set(true, forKey: biometricEnabledKey)
    }

    func disableBiometric() {
        isBiometricEnabled = false
        isAuthenticated = false
        UserDefaults.standard.set(false, forKey: biometricEnabledKey)
    }

    private func loadSettings() {
        isBiometricEnabled = UserDefaults.standard.bool(forKey: biometricEnabledKey)

        // If biometric is enabled but app just launched, require authentication
        if isBiometricEnabled {
            isAuthenticated = false
        } else {
            // If biometric is disabled, user is always "authenticated"
            isAuthenticated = true
        }
    }

    // MARK: - Passcode Fallback

    func authenticateWithPasscode(reason: String = "Accedi a MoneyTracker", completion: @escaping (Bool, Error?) -> Void) {
        let context = LAContext()

        // This allows passcode as fallback
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                if success {
                    self.isAuthenticated = true
                    self.authenticationError = nil
                    completion(true, nil)
                } else {
                    self.isAuthenticated = false
                    self.authenticationError = error?.localizedDescription
                    completion(false, error)
                }
            }
        }
    }

    // MARK: - Reset on App Termination

    func resetAuthenticationState() {
        if isBiometricEnabled {
            isAuthenticated = false
        }
    }

    // MARK: - Error Messages

    func getErrorMessage(for error: Error?) -> String {
        guard let error = error as? LAError else {
            return "Errore di autenticazione sconosciuto"
        }

        switch error.code {
        case .authenticationFailed:
            return "Autenticazione fallita. Riprova."
        case .userCancel:
            return "Autenticazione annullata"
        case .userFallback:
            return "Utilizza il passcode del dispositivo"
        case .biometryNotAvailable:
            return "\(biometricName) non disponibile"
        case .biometryNotEnrolled:
            return "\(biometricName) non configurato su questo dispositivo"
        case .biometryLockout:
            return "\(biometricName) bloccato. Usa il passcode del dispositivo."
        case .passcodeNotSet:
            return "Nessun passcode configurato sul dispositivo"
        default:
            return error.localizedDescription
        }
    }
}
