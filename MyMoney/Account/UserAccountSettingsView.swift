import SwiftUI

struct UserAccountSection: View {
    @State private var manager = UserAccountManager.shared
    var body: some View {
        Section {
            NavigationLink {
                UserAccountSettingsView()
            } label: {
                OrbListRow(icon: "person.crop.circle.fill", title: "Account MyMoney",
                           subtitle: manager.user.map { $0.emailVerified ? "Registrato · Email verificata" : "Registrato · Email da verificare" } ?? "Registrati o accedi")
            }
        } header: { Text("Account") }
        footer: { Text("La registrazione non modifica i conti esistenti e non attiva la condivisione delle spese.") }
        .listRowBackground(Color.orbCard)
    }
}

struct UserAccountSettingsView: View {
    @State private var manager = UserAccountManager.shared
    @State private var credentials: CredentialsMode?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        List {
            Section {
                if !manager.isConfigured {
                    Label("Servizio account non configurato in questa build", systemImage: "exclamationmark.triangle")
                } else if let user = manager.user {
                    LabeledContent("Stato", value: "Registrato")
                    if !user.name.isEmpty { LabeledContent("Nome", value: user.name) }
                    LabeledContent("Email", value: user.email)
                    Label(user.emailVerified ? "Email verificata" : "Email da verificare",
                          systemImage: user.emailVerified ? "checkmark.seal.fill" : "envelope.badge")
                        .foregroundStyle(user.emailVerified ? Color.orbPositive : Color.orbHighlight)
                    if !user.emailVerified {
                        Button("Invia email di verifica") { Task { await manager.sendVerification() } }
                    }
                    Button("Aggiorna stato") { Task { await manager.refresh() } }
                    Button("Esci dall’account", role: .destructive) { manager.signOut() }
                } else {
                    LabeledContent("Stato", value: "Non registrato")
                    Button("Crea un account") { credentials = .register }
                        .accessibilityIdentifier("account.register")
                    Button("Accedi con un account esistente") { credentials = .signIn }
                }
                if manager.isBusy { ProgressView("Operazione in corso…") }
            } header: { Text("Account MyMoney") }
            .disabled(manager.isBusy)
            .listRowBackground(Color.orbCard)

            Section {
                LabeledContent("Condivisione spese", value: "Non attiva")
                Text("Conti e movimenti esistenti continuano a usare la configurazione locale e iCloud già presente. Il cambio di account MyMoney non trasferisce né elimina questi dati.")
                    .font(.orbBody).foregroundStyle(Color.orbMuted)
            } header: { Text("Dati e famiglia") }
            .listRowBackground(Color.orbCard)
        }
        .navigationTitle("Account MyMoney")
        .orbScreen()
        .sheet(item: $credentials) { mode in
            UserAccountCredentialsView(mode: mode, manager: manager)
        }
        .alert("Account MyMoney", isPresented: Binding(get: { manager.message != nil && credentials == nil }, set: { if !$0 { manager.message = nil } })) {
            Button("OK") { manager.message = nil }
        } message: { Text(manager.message ?? "") }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, manager.user != nil { Task { await manager.refresh() } }
        }
    }
}

enum CredentialsMode: String, Identifiable {
    case register, signIn
    var id: String { rawValue }
}

struct UserAccountCredentialsView: View {
    let mode: CredentialsMode
    @Bindable var manager: UserAccountManager
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmation = ""

    private var canSubmit: Bool {
        !manager.isBusy && email.contains("@") && !password.isEmpty &&
        (mode == .signIn || (!name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && password.count >= 8 && password == confirmation))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if mode == .register { TextField("Nome", text: $name).textContentType(.name) }
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress).keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("Password", text: $password)
                        .textContentType(mode == .register ? .newPassword : .password)
                    if mode == .register {
                        SecureField("Conferma password", text: $confirmation).textContentType(.newPassword)
                    }
                } footer: {
                    if mode == .register { Text("Usa almeno 8 caratteri. Verrà creato un account Firebase con il nome e l'email indicati. Conti e spese non vengono caricati.") }
                }
                .listRowBackground(Color.orbCard)
                Section {
                    Button(mode == .register ? "Registrati" : "Accedi") {
                        Task {
                            if mode == .register { await manager.register(name: name, email: email, password: password) }
                            else { await manager.signIn(email: email, password: password) }
                            if manager.user != nil { password = ""; confirmation = ""; dismiss() }
                        }
                    }.disabled(!canSubmit)
                    if mode == .signIn {
                        Button("Password dimenticata") { Task { await manager.resetPassword(email: email) } }
                            .disabled(manager.isBusy || !email.contains("@"))
                    }
                    if manager.isBusy { ProgressView() }
                    if let message = manager.message { Text(message).font(.orbFootnote) }
                }.listRowBackground(Color.orbCard)
            }
            .orbScreen()
            .navigationTitle(mode == .register ? "Crea un account" : "Accedi")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() }.disabled(manager.isBusy) } }
            .interactiveDismissDisabled(manager.isBusy)
        }.presentationDetents([.large])
    }
}
