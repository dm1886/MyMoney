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
    @Query(sort: \Transaction.date) private var allTransactions: [Transaction]

    private var pendingTransactions: [Transaction] {
        allTransactions.filter { $0.status == .pending && $0.isScheduled }
    }

    var body: some View {
        List {
            if pendingTransactions.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 60))
                        .foregroundStyle(Color.orbPositive)

                    Text("Nessuna Transazione in Attesa")
                        .font(.orbTitle3.bold())

                    Text("Le transazioni programmate che richiedono conferma appariranno qui")
                        .font(.orbSubheadline)
                        .foregroundStyle(Color.orbMuted)
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
        }.orbScreen()
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
        return transaction.date < Date()
    }
    
    private var displayTitle: String {
        // Per i trasferimenti, mostra solo "Trasferimento"
        if transaction.transactionType == .transfer {
            return "Trasferimento"
        }
        
        // Per gli altri tipi, mostra categoria o tipo
        return transaction.category?.name ?? transaction.transactionType.rawValue
    }
    
    private var transferDetail: String? {
        // Dettagli del trasferimento (conti coinvolti)
        guard transaction.transactionType == .transfer else { return nil }
        
        if let sourceAccount = transaction.account, let destAccount = transaction.destinationAccount {
            return "\(sourceAccount.name) → \(destAccount.name)"
        }
        
        return nil
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
                // Category icon (custom image or SF Symbol)
                if let category = transaction.category,
                   let imageData = category.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                } else {
                    ZStack {
                        Circle()
                            .fill(transaction.transactionType.orbColor.opacity(0.2))
                            .frame(width: 50, height: 50)

                        Image(systemName: transaction.category?.icon ?? transaction.transactionType.icon)
                            .font(.orbTitle3)
                            .foregroundStyle(transaction.transactionType.orbColor)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayTitle)
                        .font(.orbHeadline)
                    
                    // Dettagli trasferimento (se applicabile)
                    if let transferDetail = transferDetail {
                        Text(transferDetail)
                            .font(.orbCaption)
                            .foregroundStyle(Color.orbMuted)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.orbCaption)
                        Text(transaction.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.orbCaption)
                    }
                    .foregroundStyle(isOverdue ? Color.orbNegative : Color.orbMuted)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(transaction.orbDisplayAmount)
                        .font(.orbTitle3.bold())
                        .foregroundStyle(transaction.transactionType.orbColor)

                    if isOverdue {
                        Text("In Ritardo")
                            .font(.orbCaption2.bold())
                            .foregroundStyle(Color.orbOnAccent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.orbNegative))
                    }
                }
            }

            // Details
            if !transaction.notes.isEmpty {
                HStack {
                    Image(systemName: "note.text")
                        .font(.orbCaption)
                        .foregroundStyle(Color.orbMuted)
                    Text(transaction.notes)
                        .font(.orbSubheadline)
                        .foregroundStyle(Color.orbMuted)
                        .lineLimit(2)
                    Spacer()
                }
            }

            if let account = transaction.account {
                HStack {
                    Image(systemName: "wallet.pass")
                        .font(.orbCaption)
                        .foregroundStyle(Color.orbMuted)
                    Text(account.name)
                        .font(.orbSubheadline)
                        .foregroundStyle(Color.orbMuted)
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
                    .font(.orbSubheadline.bold())
                    .foregroundStyle(Color.orbNegative)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.orbNegative.opacity(0.1))
                    )
                }

                Button {
                    showingConfirmAlert = true
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Conferma")
                    }
                    .font(.orbSubheadline.bold())
                    .foregroundStyle(Color.orbOnAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [Color.orbPositive, Color.orbPositive.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                }
            }
        }
        .padding()
        .orbSurface()
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
