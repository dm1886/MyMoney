//
//  PendingTransactionsView.swift
//  MoneyTracker
//
//  Created on 2026-01-06.
//

import SwiftUI
import SwiftData

struct PendingTransactionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.scheduledDate) private var allTransactions: [Transaction]

    private var pendingTransactions: [Transaction] {
        allTransactions.filter { $0.status == .pending && $0.isScheduled }
    }

    var body: some View {
        List {
            if pendingTransactions.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 60))
                        .foregroundStyle(.green)

                    Text("Nessuna Transazione in Attesa")
                        .font(.title3.bold())

                    Text("Le transazioni programmate che richiedono conferma appariranno qui")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(pendingTransactions) { transaction in
                    PendingTransactionCard(transaction: transaction)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Da Confermare")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PendingTransactionCard: View {
    @Environment(\.modelContext) private var modelContext

    let transaction: Transaction

    @State private var showingConfirmAlert = false
    @State private var showingCancelAlert = false

    // Check if transaction is deleted
    private var isDeleted: Bool {
        DeletedTransactionTracker.shared.isDeleted(transaction.id) || transaction.modelContext == nil
    }

    var isOverdue: Bool {
        guard !isDeleted else { return false }
        guard let scheduledDate = transaction.scheduledDate else { return false }
        return scheduledDate < Date()
    }

    var body: some View {
        // CRITICAL: Check if deleted before rendering
        if isDeleted {
            EmptyView()
        } else {
            cardContent
        }
    }

    private var cardContent: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                ZStack {
                    Circle()
                        .fill(Color(hex: transaction.transactionType.color)?.opacity(0.2) ?? .orange.opacity(0.2))
                        .frame(width: 50, height: 50)

                    Image(systemName: transaction.category?.icon ?? transaction.transactionType.icon)
                        .font(.title3)
                        .foregroundStyle(Color(hex: transaction.transactionType.color) ?? .orange)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(transaction.category?.name ?? transaction.transactionType.rawValue)
                        .font(.headline)

                    if let scheduledDate = transaction.scheduledDate {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption)
                            Text(scheduledDate.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                        }
                        .foregroundStyle(isOverdue ? .red : .secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(transaction.displayAmount)
                        .font(.title3.bold())
                        .foregroundStyle(Color(hex: transaction.transactionType.color) ?? .orange)

                    if isOverdue {
                        Text("In Ritardo")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.red))
                    }
                }
            }

            // Details
            if !transaction.notes.isEmpty {
                HStack {
                    Image(systemName: "note.text")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(transaction.notes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Spacer()
                }
            }

            if let account = transaction.account {
                HStack {
                    Image(systemName: "wallet.pass")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(account.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }

            Divider()

            // Actions
            HStack(spacing: 12) {
                Button {
                    showingCancelAlert = true
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                        Text("Annulla")
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.red.opacity(0.1))
                    )
                }

                Button {
                    showingConfirmAlert = true
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Conferma")
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [.green, .green.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        )
        .alert("Conferma Transazione", isPresented: $showingConfirmAlert) {
            Button("Annulla", role: .cancel) { }
            Button("Conferma") {
                confirmTransaction()
            }
        } message: {
            Text("Vuoi confermare ed eseguire questa transazione?")
        }
        .alert("Annulla Transazione", isPresented: $showingCancelAlert) {
            Button("No", role: .cancel) { }
            Button("Sì, Annulla", role: .destructive) {
                cancelTransaction()
            }
        } message: {
            Text("Vuoi annullare questa transazione programmata?")
        }
    }

    private func confirmTransaction() {
        TransactionScheduler.shared.confirmTransaction(transaction, modelContext: modelContext)
    }

    private func cancelTransaction() {
        TransactionScheduler.shared.cancelTransaction(transaction, modelContext: modelContext)
    }
}

#Preview {
    NavigationStack {
        PendingTransactionsView()
            .modelContainer(for: [Account.self, Transaction.self, Category.self, CategoryGroup.self])
    }
}
