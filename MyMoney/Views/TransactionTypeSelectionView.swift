//
//  TransactionTypeSelectionView.swift
//  MoneyTracker
//
//  Created on 2026-01-01.
//

import SwiftUI

struct TransactionTypeSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedType: TransactionType?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Che tipo di transazione vuoi aggiungere?")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding()

                VStack(spacing: 16) {
                    TransactionTypeButton(
                        type: .expense,
                        title: "Uscita",
                        subtitle: "Aggiungi una spesa",
                        icon: "arrow.down.circle.fill",
                        color: .red
                    ) {
                        selectedType = .expense
                        dismiss()
                    }

                    TransactionTypeButton(
                        type: .income,
                        title: "Entrata",
                        subtitle: "Aggiungi un'entrata",
                        icon: "arrow.up.circle.fill",
                        color: .green
                    ) {
                        selectedType = .income
                        dismiss()
                    }

                    TransactionTypeButton(
                        type: .transfer,
                        title: "Trasferimento",
                        subtitle: "Trasferisci tra conti",
                        icon: "arrow.left.arrow.right.circle.fill",
                        color: .blue
                    ) {
                        selectedType = .transfer
                        dismiss()
                    }
                    
                    TransactionTypeButton(
                        type: .liabilityPayment,
                        title: "Pagamento Passività",
                        subtitle: "Paga debiti e carte di credito",
                        icon: "creditcard.and.123",
                        color: .orange
                    ) {
                        selectedType = .liabilityPayment
                        dismiss()
                    }
                }
                .padding()

                Spacer()
            }
            .navigationTitle("Nuova Transazione")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct TransactionTypeButton: View {
    let type: TransactionType
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 60, height: 60)

                    Image(systemName: icon)
                        .font(.title)
                        .foregroundStyle(color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            )
        }
    }
}

#Preview {
    TransactionTypeSelectionView(selectedType: .constant(nil))
}
