//
//  BalanceAdjustmentView.swift
//  MoneyTracker
//
//  Created on 2026-01-06.
//

import SwiftUI
import SwiftData

struct BalanceAdjustmentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var account: Account

    @State private var newBalanceText: String = ""
    @State private var notes: String = ""
    @State private var useAvailableCredit = false
    @State private var showingSuccessAnimation = false

    var currentBalance: Decimal {
        account.currentBalance
    }

    var newBalance: Decimal? {
        // Rimuovi TUTTI i punti (separatori migliaia) e sostituisci virgola con punto per il parsing
        let cleanedText = newBalanceText
            .replacingOccurrences(of: ".", with: "")  // Rimuovi punti delle migliaia
            .replacingOccurrences(of: ",", with: ".")  // Virgola decimale → punto per Decimal
        guard let value = Decimal(string: cleanedText) else { return nil }
        return isCreditCard && useAvailableCredit ? CreditCardMath.netBalance(available: value, limit: account.creditLimit ?? 0) : value
    }

    var difference: Decimal? {
        guard let newBal = newBalance else { return nil }
        return newBal - currentBalance
    }

    var isPositiveDifference: Bool {
        guard let diff = difference else { return false }
        return diff > 0
    }

    var isCreditCard: Bool {
        account.accountType == .creditCard
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // IMPORTANTE: Nota per carte di credito
                    if isCreditCard {
                        creditCardReminderBanner
                    }

                    // Saldo Attuale Card
                    currentBalanceCard

                    // Nuovo Saldo Card
                    newBalanceCard

                    // Note Section
                    notesCard

                    Spacer(minLength: 40)
                }
                .padding()
            }.orbScreen()
            .background(Color.orbBackground)
            .navigationTitle("Aggiusta Saldo")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Inizializza il campo con il saldo attuale formattato SENZA punti delle migliaia
                if newBalanceText.isEmpty {
                    newBalanceText = formatAmountForEditing(currentBalance)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        withAnimation(.spring(response: 0.3)) {
                            showingSuccessAnimation = true
                        }

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            saveAdjustment()
                        }
                    }
                    .disabled(!isValid)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Credit Card Reminder Banner

    private var creditCardReminderBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Saldo della carta").font(.orbHeadline)
            Toggle("Inserisco disponibilità incluso plafond", isOn: $useAvailableCredit)
                .disabled(account.creditLimit == nil)
                .onChange(of: useAvailableCredit) { _, enabled in
                    newBalanceText = formatAmountForEditing(currentBalance + (enabled ? account.creditLimit ?? 0 : 0))
                }
            Text(useAvailableCredit ? "Il saldo netto è disponibilità meno limite. Esempio: 90.000 − 60.000 = +30.000 di proprietà." : "Inserisci il saldo netto: positivo per il tuo credito, negativo per il debito. Il plafond è escluso.").font(.orbSubheadline)
            if let net = newBalance { Text("Saldo netto risultante: " + OrbCurrency.string(net, symbol: account.currencySymbol)).font(.orbHeadline).lineLimit(1).minimumScaleFactor(0.2) }
        }.padding(16).orbSurface()
    }

    private var currentBalanceCard: some View {
        VStack(spacing: 16) {
            HStack {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [account.color.opacity(0.2), account.color.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)

                    Image(systemName: account.icon)
                        .font(.orbTitle2)
                        .foregroundStyle(account.color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(account.name)
                        .font(.orbHeadline)
                        .foregroundStyle(Color.orbText)

                    Text(account.accountType.rawValue)
                        .font(.orbCaption)
                        .foregroundStyle(Color.orbMuted)
                }

                Spacer()
            }

            Divider()

            VStack(spacing: 8) {
                Text("Saldo Attuale")
                    .font(.orbSubheadline)
                    .foregroundStyle(Color.orbMuted)
                    .textCase(.uppercase)
                    .tracking(1)

                HStack(spacing: 8) {
                    Text(formatAmount(currentBalance))
                        .font(.orb(36, weight: .bold, relativeTo: .title))
                        .foregroundStyle(
                            LinearGradient(
                                colors: currentBalance >= 0 ? [Color.orbPositive, Color.orbAccent] : [Color.orbNegative, Color.orbHighlight],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .padding(20)
        .orbSurface()
    }

    // MARK: - New Balance Card

    private var newBalanceCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .font(.orbTitle2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.orbAccent, Color.orbAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Nuovo Saldo")
                    .font(.orbHeadline.bold())
                    .foregroundStyle(Color.orbText)

                Spacer()
            }

            Divider()

            // Input Field
            HStack(spacing: 12) {
                Text(account.currencyRecord?.displaySymbol ?? (account.currency.rawValue == "USD" ? "$" : account.currency.rawValue))
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.orbMuted)

                TextField("0,00", text: $newBalanceText)
                    .keyboardType(.decimalPad)
                    .font(.orb(28, weight: .bold, relativeTo: .title))
                    .multilineTextAlignment(.leading)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.orbCard)
                    )
                    .onChange(of: newBalanceText) { oldValue, newValue in
                        // Filtra caratteri non validi: permetti solo numeri, virgola e segno meno
                        let filtered = newValue.filter { "0123456789,-".contains($0) }
                        
                        // Assicurati che ci sia al massimo una virgola
                        let commaCount = filtered.filter { $0 == "," }.count
                        if commaCount > 1 {
                            // Rimuovi virgole extra
                            var result = ""
                            var commaFound = false
                            for char in filtered {
                                if char == "," {
                                    if !commaFound {
                                        result.append(char)
                                        commaFound = true
                                    }
                                } else {
                                    result.append(char)
                                }
                            }
                            newBalanceText = result
                        } else if filtered != newValue {
                            newBalanceText = filtered
                        }
                    }

                if let currencyRecord = account.currencyRecord {
                    Text(currencyRecord.flagEmoji)
                        .font(.system(size: 28))
                }
            }

            // Difference Indicator
            if let diff = difference, diff != 0 {
                VStack(spacing: 12) {
                    Divider()

                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(isPositiveDifference ? Color.orbPositive.opacity(0.15) : Color.orbNegative.opacity(0.15))
                                .frame(width: 40, height: 40)

                            Image(systemName: isPositiveDifference ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                .font(.orbTitle3)
                                .foregroundStyle(isPositiveDifference ? Color.orbPositive : Color.orbNegative)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Differenza")
                                .font(.orbCaption)
                                .foregroundStyle(Color.orbMuted)

                            Text(formatAmountWithSign(diff))
                                .font(.orbTitle3.bold())
                                .foregroundStyle(isPositiveDifference ? Color.orbPositive : Color.orbNegative)
                        }

                        Spacer()
                    }

                    // Footer Info
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .font(.orbCaption)
                            .foregroundStyle(Color.orbHighlight)

                        Text("Verrà creata una transazione di aggiustamento")
                            .font(.orbCaption)
                            .foregroundStyle(Color.orbMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.orbAccent.opacity(0.05))
                    )
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(20)
        .orbSurface()
        .animation(.spring(response: 0.3), value: difference)
    }

    // MARK: - Notes Card

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "note.text")
                    .font(.orbHeadline)
                    .foregroundStyle(Color.orbMuted)

                Text("Note (opzionale)")
                    .font(.orbHeadline)
                    .foregroundStyle(Color.orbMuted)
            }

            TextField("Motivo dell'aggiustamento...", text: $notes, axis: .vertical)
                .lineLimit(3...6)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orbCard)
                )
        }
        .padding(20)
        .orbSurface()
    }

    // MARK: - Validation

    private var isValid: Bool {
        guard let _ = newBalance,
              let diff = difference,
              diff != 0 else {
            return false
        }
        return true
    }

    // MARK: - Save Function

    private func saveAdjustment() {
        guard let diff = difference, diff != 0 else {
            LogManager.shared.warning("Balance adjustment attempted with zero or invalid difference", category: "BalanceAdjustment")
            return
        }

        LogManager.shared.info("Creating balance adjustment for account '\(account.name)': Current: \(currentBalance), New: \(newBalance ?? 0), Diff: \(diff)", category: "BalanceAdjustment")

        // Create adjustment transaction with signed amount
        // Positive diff = balance increase, negative diff = balance decrease
        let adjustmentTransaction = Transaction(
            transactionType: .adjustment,
            amount: diff,  // Store signed value
            currency: account.currency,
            date: Date(),
            notes: notes.isEmpty ? "Aggiustamento saldo" : notes,
            account: account,
            category: nil,
            destinationAccount: nil
        )

        adjustmentTransaction.currencyRecord = account.currencyRecord

        modelContext.insert(adjustmentTransaction)

        // Update account balance
        account.updateBalance(context: modelContext)

        do {
            try modelContext.save()
            LogManager.shared.success("Balance adjustment saved for account '\(account.name)'. Amount: \(diff)", category: "BalanceAdjustment")

            // Haptic feedback
            HapticManager.shared.success()
        } catch {
            LogManager.shared.error("Failed to save balance adjustment: \(error.localizedDescription)", category: "BalanceAdjustment")

            // Haptic feedback
            HapticManager.shared.error()
        }

        dismiss()
    }

    // MARK: - Formatting
    
    /// Formatta un importo per l'editing: solo virgola decimale, SENZA punti delle migliaia
    private func formatAmountForEditing(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = ""  // NESSUN separatore migliaia
        formatter.decimalSeparator = ","
        
        return formatter.string(from: amount as NSDecimalNumber) ?? "0,00"
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = "."
        formatter.decimalSeparator = ","

        let amountString = formatter.string(from: amount as NSDecimalNumber) ?? "0,00"
        let symbol = account.currencyRecord?.displaySymbol ?? (account.currency.rawValue == "USD" ? "$" : account.currency.rawValue)

        return "\(symbol) \(amountString)"
    }

    private func formatAmountWithSign(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = "."
        formatter.decimalSeparator = ","

        let amountString = formatter.string(from: abs(amount) as NSDecimalNumber) ?? "0,00"
        let sign = amount >= 0 ? "+" : "-"
        let symbol = account.currencyRecord?.displaySymbol ?? (account.currency.rawValue == "USD" ? "$" : account.currency.rawValue)

        return "\(sign)\(symbol) \(amountString)"
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Account.self, Transaction.self, configurations: config)

    let account = Account(name: "Visa Platinum", accountType: .creditCard, currency: .EUR)
    account.currentBalance = -500.00
    container.mainContext.insert(account)

    return BalanceAdjustmentView(account: account)
        .modelContainer(container)
}
