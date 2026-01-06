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

    var currentBalance: Decimal {
        account.currentBalance
    }

    var newBalance: Decimal? {
        Decimal(string: newBalanceText.replacingOccurrences(of: ",", with: "."))
    }

    var difference: Decimal? {
        guard let newBal = newBalance else { return nil }
        return newBal - currentBalance
    }

    var isPositiveDifference: Bool {
        guard let diff = difference else { return false }
        return diff > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        Text("Saldo Attuale")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(formatAmount(currentBalance))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                } header: {
                    Text("Informazioni Conto")
                }

                Section {
                    HStack {
                        Text(account.currencyRecord?.symbol ?? account.currency.symbol)
                            .font(.title2)
                            .foregroundStyle(.secondary)

                        TextField("Nuovo Saldo", text: $newBalanceText)
                            .keyboardType(.decimalPad)
                            .font(.title2.bold())
                    }

                    if let diff = difference, diff != 0 {
                        HStack {
                            Image(systemName: isPositiveDifference ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                .foregroundStyle(isPositiveDifference ? .green : .red)

                            Text("Differenza")
                                .foregroundStyle(.secondary)

                            Spacer()

                            Text(formatAmountWithSign(diff))
                                .font(.headline)
                                .foregroundStyle(isPositiveDifference ? .green : .red)
                        }
                    }
                } header: {
                    Text("Nuovo Saldo")
                } footer: {
                    if let diff = difference, diff != 0 {
                        Text("Verrà creata una transazione di aggiustamento per \(formatAmountWithSign(diff))")
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    TextField("Motivo dell'aggiustamento (opzionale)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Note")
                }
            }
            .navigationTitle("Aggiusta Saldo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        saveAdjustment()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private var isValid: Bool {
        guard let _ = newBalance,
              let diff = difference,
              diff != 0 else {
            return false
        }
        return true
    }

    private func saveAdjustment() {
        guard let diff = difference, diff != 0 else { return }

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

        try? modelContext.save()

        dismiss()
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2

        let amountString = formatter.string(from: amount as NSDecimalNumber) ?? "0.00"
        return "\(account.currencyRecord?.symbol ?? account.currency.symbol)\(amountString)"
    }

    private func formatAmountWithSign(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2

        let amountString = formatter.string(from: abs(amount) as NSDecimalNumber) ?? "0.00"
        let sign = amount >= 0 ? "+" : "-"
        return "\(sign)\(account.currencyRecord?.symbol ?? account.currency.symbol)\(amountString)"
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Account.self, Transaction.self, configurations: config)

    let account = Account(name: "Test Account", accountType: .payment, currency: .EUR)
    account.currentBalance = 1000.00
    container.mainContext.insert(account)

    return BalanceAdjustmentView(account: account)
        .modelContainer(container)
}
