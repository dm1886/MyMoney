//
//  AccountSelectionView.swift
//  MoneyTracker
//
//  Created on 2026-01-06.
//

import SwiftUI
import SwiftData

struct AccountSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Account.name) private var accounts: [Account]

    @Binding var selectedAccount: Account?
    let showNavigationBar: Bool

    init(selectedAccount: Binding<Account?>, showNavigationBar: Bool = true) {
        self._selectedAccount = selectedAccount
        self.showNavigationBar = showNavigationBar
    }

    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        Group {
            if showNavigationBar {
                NavigationStack {
                    content
                        .navigationTitle("Seleziona Conto")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Annulla") {
                                    dismiss()
                                }
                            }
                        }
                }
            } else {
                content
            }
        }
    }

    var content: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(accounts) { account in
                    AccountGridCard(
                        account: account,
                        isSelected: selectedAccount?.id == account.id
                    )
                    .onTapGesture {
                        selectedAccount = account
                        dismiss()
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
}

struct AccountGridCard: View {
    let account: Account
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 12) {
            // Account Image or Icon
            ZStack {
                if let imageData = account.imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(isSelected ? account.color : Color.clear, lineWidth: 3)
                        )
                } else {
                    ZStack {
                        Circle()
                            .fill(account.color.opacity(0.2))
                            .frame(width: 80, height: 80)

                        Image(systemName: account.icon)
                            .font(.system(size: 32))
                            .foregroundStyle(account.color)
                    }
                    .overlay(
                        Circle()
                            .stroke(isSelected ? account.color : Color.clear, lineWidth: 3)
                    )
                }

                // Checkmark for selected account
                if isSelected {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .background(
                                    Circle()
                                        .fill(account.color)
                                        .frame(width: 28, height: 28)
                                )
                        }
                        Spacer()
                    }
                    .frame(width: 80, height: 80)
                }
            }

            // Account Name
            Text(account.name)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 34)

            // Currency Badge
            if let currencyRecord = account.currencyRecord {
                HStack(spacing: 4) {
                    Text(currencyRecord.flagEmoji)
                        .font(.caption)
                    Text(currencyRecord.code)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray6))
                )
            }

            // Account Balance
            Text(formatAmount(account.currentBalance, currency: account.currencyRecord))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(isSelected ? 0.15 : 0.05), radius: isSelected ? 8 : 5, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? account.color.opacity(0.5) : Color.clear, lineWidth: 2)
        )
    }

    private func formatAmount(_ amount: Decimal, currency: CurrencyRecord?) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2

        let amountString = formatter.string(from: amount as NSDecimalNumber) ?? "0.00"
        return "\(currency?.symbol ?? "€")\(amountString)"
    }
}

#Preview {
    @Previewable @State var selectedAccount: Account? = nil

    AccountSelectionView(selectedAccount: $selectedAccount)
        .modelContainer(for: [Account.self, Transaction.self, Category.self, CategoryGroup.self])
}
