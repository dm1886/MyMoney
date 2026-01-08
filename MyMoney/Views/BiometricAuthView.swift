//
//  BiometricAuthView.swift
//  MoneyTracker
//
//  Created on 2026-01-01.
//

import SwiftUI
import LocalAuthentication

struct BiometricAuthView: View {
    @State private var biometricManager = BiometricAuthManager.shared
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var authAttempts = 0

    var body: some View {
        ZStack {
            // Blurred background
            Color.black.opacity(0.9)
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // App Icon/Logo
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.2))
                            .frame(width: 100, height: 100)

                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.green)
                    }

                    Text("MoneyTracker")
                        .font(.title.bold())
                        .foregroundStyle(.white)
                }

                // Biometric Icon
                VStack(spacing: 20) {
                    Image(systemName: biometricIcon)
                        .font(.system(size: 80))
                        .foregroundStyle(.blue)

                    VStack(spacing: 8) {
                        Text("Sblocca con \(biometricManager.biometricName)")
                            .font(.title3.bold())
                            .foregroundStyle(.white)

                        Text("Accedi per visualizzare i tuoi dati finanziari")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                }

                Spacer()

                // Authenticate Button
                VStack(spacing: 16) {
                    Button {
                        authenticate()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: biometricIcon)
                                .font(.title3)
                            Text("Autentica con \(biometricManager.biometricName)")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 40)

                    // Alternative: Use Passcode
                    Button {
                        authenticateWithPasscode()
                    } label: {
                        Text("Usa il Passcode del Dispositivo")
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .alert("Autenticazione Fallita", isPresented: $showingError) {
            Button("Riprova", role: .cancel) {
                authenticate()
            }
            if authAttempts >= 3 {
                Button("Usa Passcode") {
                    authenticateWithPasscode()
                }
            }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            // Auto-trigger authentication when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                authenticate()
            }
        }
    }

    private var biometricIcon: String {
        switch biometricManager.biometricType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        case .none:
            return "lock.fill"
        }
    }

    private func authenticate() {
        biometricManager.authenticate(reason: "Sblocca MoneyTracker per accedere ai tuoi dati finanziari") { success, error in
            if !success {
                authAttempts += 1
                errorMessage = biometricManager.getErrorMessage(for: error)

                // Don't show error for user cancellation
                if let error = error as? LAError, error.code == .userCancel {
                    return
                }

                showingError = true
            }
        }
    }

    private func authenticateWithPasscode() {
        biometricManager.authenticateWithPasscode(reason: "Sblocca MoneyTracker") { success, error in
            if !success {
                errorMessage = biometricManager.getErrorMessage(for: error)
                showingError = true
            }
        }
    }
}

#Preview {
    BiometricAuthView()
}
