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
            Color.orbBackground.ignoresSafeArea()
            VStack(spacing: 28) {
                Spacer()
                Text("MyMoney").font(.orbTitle)
                Text("Accedi per visualizzare i tuoi dati finanziari")
                    .font(.orbSubheadline).foregroundStyle(Color.orbMuted).multilineTextAlignment(.center)
                OrbView(size: 170, showsRings: true) {
                    Image(systemName: biometricIcon).font(.system(size: 54, weight: .light))
                }.padding(.vertical, 24).accessibilityHidden(true)
                Text("Sblocca con \(biometricManager.biometricName)").font(.orbHeadline)
                Spacer()
                Button { authenticate() } label: {
                    Label("Autentica con \(biometricManager.biometricName)", systemImage: biometricIcon)
                }.buttonStyle(OrbPrimaryButtonStyle())
                Button { authenticateWithPasscode() } label: {
                    Text("Usa il Passcode del Dispositivo").font(.orbSubheadline)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .overlay(Capsule().stroke(Color.orbLine, lineWidth: 1))
                }
            }.padding(.horizontal, 28).padding(.bottom, 30).riseIn()
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
