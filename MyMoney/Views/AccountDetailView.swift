//
//  AccountDetailView.swift
//  MoneyTracker
//
//  Created on 2026-01-01.
//

import SwiftUI
import SwiftData

struct AccountDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var account: Account

    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false

    var sortedTransactions: [Transaction] {
        (account.transactions ?? []).sorted { $0.date > $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    // Mostra immagine personalizzata se esiste, altrimenti icona
                    if let imageData = account.imageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(account.color, lineWidth: 3)
                            )
                    } else {
                        ZStack {
                            Circle()
                                .fill(account.color.opacity(0.2))
                                .frame(width: 80, height: 80)

                            Image(systemName: account.icon)
                                .font(.system(size: 40))
                                .foregroundStyle(account.color)
                        }
                    }

                    VStack(spacing: 4) {
                        Text(account.name)
                            .font(.title.bold())

                        Text(account.accountType.rawValue)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 4) {
                        Text("Saldo Attuale")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text("\(account.currency.symbol)\(formatDecimal(account.currentBalance))")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                    }

                    if !account.accountDescription.isEmpty {
                        Text(account.accountDescription)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                )
                .padding(.horizontal)
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Transazioni")
                        .font(.title2.bold())
                        .padding(.horizontal)

                    if sortedTransactions.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "list.bullet.clipboard")
                                .font(.system(size: 50))
                                .foregroundStyle(.secondary)

                            Text("Nessuna transazione")
                                .font(.headline)

                            Text("Le transazioni per questo conto appariranno qui")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 40)
                        .frame(maxWidth: .infinity)
                    } else {
                        ForEach(sortedTransactions) { transaction in
                            TransactionRow(transaction: transaction)
                                .padding(.horizontal)
                        }
                    }
                }

                Spacer(minLength: 40)
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Dettagli Conto")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showingEditSheet = true
                    } label: {
                        Label("Modifica", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("Elimina", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditAccountView(account: account)
        }
        .alert("Elimina Conto", isPresented: $showingDeleteAlert) {
            Button("Annulla", role: .cancel) { }
            Button("Elimina", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("Sei sicuro di voler eliminare questo conto? Tutte le transazioni associate verranno eliminate.")
        }
        .onAppear {
            account.updateBalance()
        }
    }

    private func formatDecimal(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "0.00"
    }

    private func deleteAccount() {
        modelContext.delete(account)
        try? modelContext.save()
        dismiss()
    }
}

struct TransactionRow: View {
    let transaction: Transaction

    var needsConversion: Bool {
        guard let account = transaction.account else { return false }
        return transaction.currency != account.currency
    }

    var convertedAmount: Decimal? {
        guard needsConversion, let account = transaction.account else { return nil }
        return CurrencyConverter.shared.convert(
            amount: transaction.amount,
            from: transaction.currency,
            to: account.currency
        )
    }

    // Precompute a formatted converted display string for the target account currency
    private var formattedConvertedDisplay: String? {
        guard let converted = convertedAmount, let account = transaction.account else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let amountString = formatter.string(from: converted as NSDecimalNumber) ?? "0.00"
        return "\(account.currency.symbol)\(amountString)"
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(hex: transaction.transactionType.color)?.opacity(0.2) ?? .blue.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: transaction.category?.icon ?? transaction.transactionType.icon)
                    .foregroundStyle(Color(hex: transaction.transactionType.color) ?? .blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.category?.name ?? transaction.transactionType.rawValue)
                    .font(.body.bold())

                Text(transaction.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !transaction.notes.isEmpty {
                    Text(transaction.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                // Mostra valuta originale se diversa
                if needsConversion {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption2)
                        Text("Originale: \(transaction.displayAmount)")
                    }
                    .font(.caption)
                    .foregroundStyle(.blue)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let displayText = formattedConvertedDisplay {
                    Text(transaction.transactionType == .expense ? "-\(displayText)" : "+\(displayText)")
                        .font(.body.bold())
                        .foregroundStyle(transaction.transactionType == .expense ? .red : .green)
                } else {
                    Text(transaction.transactionType == .expense ? "-\(transaction.displayAmount)" : "+\(transaction.displayAmount)")
                        .font(.body.bold())
                        .foregroundStyle(transaction.transactionType == .expense ? .red : .green)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        )
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Account.self, Transaction.self, configurations: config)

    let account = Account(name: "Test Account", accountType: .payment, currency: .EUR)
    container.mainContext.insert(account)

    return NavigationStack {
        AccountDetailView(account: account)
    }
    .modelContainer(container)
}

