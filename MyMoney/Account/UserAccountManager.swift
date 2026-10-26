import Foundation
import Observation
import FirebaseCore
import FirebaseAuth

struct UserAccountSnapshot: Equatable {
    let id: String
    let email: String
    let name: String
    let emailVerified: Bool
}

/// Authentication is independent of the existing SwiftData/CloudKit financial library.
@MainActor @Observable
final class UserAccountManager {
    static let shared = UserAccountManager()
    private(set) var user: UserAccountSnapshot?
    private(set) var isBusy = false
    private(set) var isConfigured = false
    var message: String?
    @ObservationIgnored private var auth: Auth?
    @ObservationIgnored private var observer: AuthStateDidChangeListenerHandle?

    init(authentication: Auth? = nil) {
        if let authentication {
            auth = authentication
            isConfigured = true
            updateUser()
            return
        }
        if FirebaseApp.app() == nil {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-firebase-auth-emulator") {
                let options = FirebaseOptions(googleAppID: "1:123456789:ios:0123456789abcdef", gcmSenderID: "123456789")
                options.apiKey = "demo-key-not-a-real-secret"
                options.projectID = "demo-mymoney"
                options.bundleID = Bundle.main.bundleIdentifier ?? "damianomiazzi.MyMoney"
                FirebaseApp.configure(options: options)
            } else if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
                      let options = FirebaseOptions(contentsOfFile: path) {
                FirebaseApp.configure(options: options)
            }
            #else
            if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
               let options = FirebaseOptions(contentsOfFile: path) {
                FirebaseApp.configure(options: options)
            }
            #endif
        }
        guard FirebaseApp.app() != nil else { return }
        let configuredAuth = Auth.auth()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-firebase-auth-emulator") {
            configuredAuth.useEmulator(withHost: "127.0.0.1", port: 9099)
        }
        #endif
        auth = configuredAuth
        isConfigured = true
        updateUser()
        observer = configuredAuth.addStateDidChangeListener { [weak self] _, _ in
            Task { @MainActor in self?.updateUser() }
        }
    }

    private func updateUser() {
        user = auth?.currentUser.map {
            UserAccountSnapshot(id: $0.uid, email: $0.email ?? "", name: $0.displayName ?? "", emailVerified: $0.isEmailVerified)
        }
    }

    func register(name: String, email: String, password: String) async {
        await perform {
            guard let auth = self.auth else { return }
            let result = try await auth.createUser(withEmail: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
            // Persisted by Firebase Auth; passwords are never saved by MyMoney.
            self.updateUser()
            let profile = result.user.createProfileChangeRequest()
            profile.displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            try await profile.commitChanges()
            self.updateUser()
            do {
                try await result.user.sendEmailVerification()
                self.message = "Account creato. Apri il link ricevuto via email, poi premi Aggiorna stato."
            } catch {
                self.message = "Account creato. Non è stato possibile inviare la verifica: usa Invia email di verifica per riprovare."
            }
        }
    }

    func signIn(email: String, password: String) async {
        await perform {
            _ = try await self.auth?.signIn(withEmail: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
            self.updateUser()
        }
    }

    func refresh() async {
        await perform {
            try await self.auth?.currentUser?.reload()
            self.updateUser()
            self.message = self.user?.emailVerified == true ? "Email verificata." : "L'email non risulta ancora verificata."
        }
    }

    func sendVerification() async {
        await perform {
            try await self.auth?.currentUser?.sendEmailVerification()
            self.message = "Email di verifica inviata."
        }
    }

    func resetPassword(email: String) async {
        await perform {
            try await self.auth?.sendPasswordReset(withEmail: email.trimmingCharacters(in: .whitespacesAndNewlines))
            self.message = "Se l'indirizzo è registrato, riceverai le istruzioni per recuperare la password."
        }
    }

    func signOut() {
        guard !isBusy else { return }
        do { try auth?.signOut(); updateUser() }
        catch { message = Self.errorMessage(error) }
    }

    private func perform(_ operation: () async throws -> Void) async {
        guard isConfigured, !isBusy else { return }
        isBusy = true
        message = nil
        defer { isBusy = false; updateUser() }
        do { try await operation() }
        catch { message = Self.errorMessage(error) }
    }

    static func errorMessage(_ error: Error) -> String {
        let code = (error as NSError).code
        switch code {
        case AuthErrorCode.emailAlreadyInUse.rawValue: return "Questo indirizzo è già registrato. Accedi o recupera la password."
        case AuthErrorCode.invalidEmail.rawValue: return "Controlla l'indirizzo email."
        case AuthErrorCode.weakPassword.rawValue: return "Scegli una password più sicura."
        case AuthErrorCode.networkError.rawValue: return "Connessione non disponibile. Riprova."
        case AuthErrorCode.tooManyRequests.rawValue: return "Troppi tentativi. Attendi prima di riprovare."
        default: return "Operazione non riuscita. Controlla i dati e riprova."
        }
    }
}
