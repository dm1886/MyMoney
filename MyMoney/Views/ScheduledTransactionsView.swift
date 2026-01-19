//
//  ScheduledTransactionsView.swift
//  MoneyTracker
//
//  Created on 2026-01-06.
//

import SwiftUI
import SwiftData

struct ScheduledTransactionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Transaction> { $0.isScheduled == true },
           sort: [SortDescriptor(\Transaction.date, order: .reverse)])
    private var scheduledTransactions: [Transaction]

    @State private var selectedFilter: TransactionStatusFilter = .all

    enum TransactionStatusFilter: String, CaseIterable {
        case all = "Tutte"
        case pending = "Da Confermare"
        case executed = "Eseguite"
        case cancelled = "Annullate"

        var status: TransactionStatus? {
            switch self {
            case .all: return nil
            case .pending: return .pending
            case .executed: return .executed
            case .cancelled: return .cancelled
            }
        }
    }

    var filteredTransactions: [Transaction] {
        if let status = selectedFilter.status {
            return scheduledTransactions.filter { $0.status == status }
        }
        return scheduledTransactions
    }

    var body: some View {
        VStack(spacing: 0) {
            // Filter Picker
            Picker("Filtro", selection: $selectedFilter) {
                ForEach(TransactionStatusFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            // List
            List {
                if filteredTransactions.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: emptyStateIcon)
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)

                        Text(emptyStateTitle)
                            .font(.title3.bold())

                        Text(emptyStateMessage)
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
                    ForEach(filteredTransactions) { transaction in
                        ScheduledTransactionRow(transaction: transaction)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.plain)
        }
        .navigationTitle("Transazioni Programmate")
        .navigationBarTitleDisplayMode(.inline)
    }

    var emptyStateIcon: String {
        switch selectedFilter {
        case .all: return "calendar.badge.clock"
        case .pending: return "clock"
        case .executed: return "checkmark.circle"
        case .cancelled: return "xmark.circle"
        }
    }

    var emptyStateTitle: String {
        switch selectedFilter {
        case .all: return "Nessuna Transazione Programmata"
        case .pending: return "Nessuna Transazione in Attesa"
        case .executed: return "Nessuna Transazione Eseguita"
        case .cancelled: return "Nessuna Transazione Annullata"
        }
    }

    var emptyStateMessage: String {
        switch selectedFilter {
        case .all: return "Le transazioni programmate appariranno qui"
        case .pending: return "Non ci sono transazioni in attesa di conferma"
        case .executed: return "Le transazioni programmate ed eseguite appariranno qui"
        case .cancelled: return "Le transazioni annullate appariranno qui"
        }
    }
}

struct ScheduledTransactionRow: View {
    @Environment(\.modelContext) private var modelContext

    let transaction: Transaction

    @State private var showingDeleteAlert = false

    // Check if transaction is deleted
    private var isDeleted: Bool {
        DeletedTransactionTracker.shared.isDeleted(transaction.id) || transaction.modelContext == nil
    }

    var statusColor: Color {
        guard !isDeleted else { return .gray }
        return Color(hex: transaction.status.color) ?? .gray
    }

    var executionTypeText: String {
        guard !isDeleted else { return "" }
        return transaction.isAutomatic ? "Automatica" : "Manuale"
    }

    var executionTypeIcon: String {
        guard !isDeleted else { return "questionmark" }
        return transaction.isAutomatic ? "bolt.fill" : "hand.tap.fill"
    }

    var body: some View {
        // CRITICAL: Check if deleted before rendering
        if isDeleted {
            EmptyView()
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            // Status Icon
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: transaction.status.icon)
                    .foregroundStyle(statusColor)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.category?.name ?? transaction.transactionType.rawValue)
                    .font(.body.bold())

                Text(transaction.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    Image(systemName: executionTypeIcon)
                        .font(.caption2)
                    Text(executionTypeText)
                        .font(.caption2)
                }
                .foregroundStyle(.blue)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(Color.blue.opacity(0.1))
                )
            }

            Spacer()

            // Amount & Status
            VStack(alignment: .trailing, spacing: 4) {
                Text(transaction.displayAmount)
                    .font(.body.bold())
                    .foregroundStyle(.primary)

                Text(transaction.status.rawValue)
                    .font(.caption2.bold())
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(statusColor.opacity(0.15))
                    )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                showingDeleteAlert = true
            } label: {
                Label("Elimina", systemImage: "trash")
            }
        }
        .alert("Elimina Transazione", isPresented: $showingDeleteAlert) {
            Button("Annulla", role: .cancel) { }
            Button("Elimina", role: .destructive) {
                deleteTransaction()
            }
        } message: {
            Text("Vuoi eliminare questa transazione programmata?")
        }
    }

    private func deleteTransaction() {
        // IMPORTANTE: Salva l'ID PRIMA di eliminare per evitare crash
        let transactionId = transaction.id

        // Cancel notification when deleting scheduled transaction
        LocalNotificationManager.shared.cancelNotification(transactionId: transactionId)

        modelContext.delete(transaction)
        try? modelContext.save()
    }
}

#Preview {
    NavigationStack {
        ScheduledTransactionsView()
            .modelContainer(for: [Account.self, Transaction.self, Category.self, CategoryGroup.self])
    }
}
