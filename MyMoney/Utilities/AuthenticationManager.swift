//
//  AuthenticationManager.swift
//  MoneyTracker
//
//  Created on 2026-01-01.
//

import Foundation
import AuthenticationServices
import Combine

enum AuthenticationState {
    case undefined
    case authenticated
    case unauthenticated
}

final class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()

    @Published var authenticationState: AuthenticationState = .undefined
    @Published var userID: String?
    @Published var userName: String?
    @Published var userEmail: String?

    private let userIDKey = "userID"
    private let userNameKey = "userName"
    private let userEmailKey = "userEmail"

    private init() {
        loadStoredCredentials()
    }

    // MARK: - Sign In with Apple

    func handleSignInWithAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                let userID = appleIDCredential.user

                // Extract a localized display name from PersonNameComponents if provided this run
                var formattedName: String?
                if let nameComponents = appleIDCredential.fullName {
                    let formatter = PersonNameComponentsFormatter()
                    formatter.style = .default
                    let display = formatter.string(from: nameComponents).trimmingCharacters(in: .whitespacesAndNewlines)
                    formattedName = display.isEmpty ? nil : display
                }

                // Email is only provided the first time the user authorizes your app
                let userEmail = appleIDCredential.email

                // Save credentials
                self.userID = userID
                self.userName = formattedName ?? self.userName // keep existing if not provided again
                self.userEmail = userEmail ?? self.userEmail   // keep existing if not provided again

                saveCredentials()
                authenticationState = .authenticated
            }

        case .failure(let error):
            print("Sign in with Apple failed: \(error.localizedDescription)")
            authenticationState = .unauthenticated
        }
    }

    func signOut() {
        userID = nil
        userName = nil
        userEmail = nil
        clearCredentials()
        authenticationState = .unauthenticated
    }

    // MARK: - Credential Check

    func checkCredentialState() {
        guard let userID = userID else {
            authenticationState = .unauthenticated
            return
        }

        let appleIDProvider = ASAuthorizationAppleIDProvider()
        appleIDProvider.getCredentialState(forUserID: userID) { credentialState, _ in
            DispatchQueue.main.async {
                switch credentialState {
                case .authorized:
                    self.authenticationState = .authenticated
                case .revoked, .notFound:
                    self.authenticationState = .unauthenticated
                    self.clearCredentials()
                default:
                    self.authenticationState = .undefined
                }
            }
        }
    }

    // MARK: - Persistence

    private func saveCredentials() {
        UserDefaults.standard.set(userID, forKey: userIDKey)
        UserDefaults.standard.set(userName, forKey: userNameKey)
        UserDefaults.standard.set(userEmail, forKey: userEmailKey)
    }

    private func loadStoredCredentials() {
        userID = UserDefaults.standard.string(forKey: userIDKey)
        userName = UserDefaults.standard.string(forKey: userNameKey)
        userEmail = UserDefaults.standard.string(forKey: userEmailKey)

        if userID != nil {
            checkCredentialState()
        } else {
            authenticationState = .unauthenticated
        }
    }

    private func clearCredentials() {
        UserDefaults.standard.removeObject(forKey: userIDKey)
        UserDefaults.standard.removeObject(forKey: userNameKey)
        UserDefaults.standard.removeObject(forKey: userEmailKey)
    }

    // MARK: - Computed Properties

    var isAuthenticated: Bool {
        authenticationState == .authenticated
    }

    var displayName: String {
        userName ?? userEmail ?? "Utente"
    }
}
