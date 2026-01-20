//
//  DefaultAccountSelectionView.swift
//  MoneyTracker
//
//  Created on 2026-01-19.
//

import SwiftUI
import SwiftData

/// A view for selecting a default account for a category, with "None" option
struct DefaultAccountSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Account.name) private var accounts: [Account]

    @Binding var selectedAccount: Account?

    // Raggruppa conti per tipo
    private var groupedAccountsByType: [(AccountType, String, String, Color, [Account])] {
        var groups: [(AccountType, String, String, Color, [Account])] = []

        let cashAccounts = accounts.filter { $0.accountType == .cash }
        if !cashAccounts.isEmpty {
            groups.append((.cash, "Contanti", "banknote.fill", .green, cashAccounts))
        }

        let paymentAccounts = accounts.filter { $0.accountType == .payment }
        if !paymentAccounts.isEmpty {
            groups.append((.payment, "Pagamento", "creditcard.fill", .blue, paymentAccounts))
        }

        let prepaidAccounts = accounts.filter { $0.accountType == .prepaidCard }
        if !prepaidAccounts.isEmpty {
            groups.append((.prepaidCard, "Carte Prepagate", "creditcard.fill", .cyan, prepaidAccounts))
        }

        let creditCardAccounts = accounts.filter { $0.accountType == .creditCard }
        if !creditCardAccounts.isEmpty {
            groups.append((.creditCard, "Carta di Credito", "creditcard.fill", .orange, creditCardAccounts))
        }

        let assetAccounts = accounts.filter { $0.accountType == .asset }
        if !assetAccounts.isEmpty {
            groups.append((.asset, "Attività", "building.columns.fill", .purple, assetAccounts))
        }

        let liabilityAccounts = accounts.filter { $0.accountType == .liability }
        if !liabilityAccounts.isEmpty {
            groups.append((.liability, "Passività", "chart.line.downtrend.xyaxis", .red, liabilityAccounts))
        }

        return groups
    }

    var body: some View {
        List {
            // Option for no default account
            Section {
                noneOptionRow
            }

            // Grouped accounts by type
            ForEach(groupedAccountsByType, id: \.0) { _, title, icon, color, typeAccounts in
                Section {
                    ForEach(typeAccounts) { account in
                        accountRow(account)
                    }
                } header: {
                    HStack(spacing: 6) {
                        Image(systemName: icon)
                            .foregroundStyle(color)
                        Text(title)
                            .foregroundStyle(.primary)
                    }
                    .font(.subheadline.bold())
                    .textCase(nil)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Conto Predefinito")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var noneOptionRow: some View {
        Button {
            selectedAccount = nil
            dismiss()
        } label: {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: "xmark.circle")
                        .foregroundStyle(.gray)
                }

                Text("Nessuno")
                    .foregroundStyle(.primary)

                Spacer()

                if selectedAccount == nil {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func accountRow(_ account: Account) -> some View {
        Button {
            selectedAccount = account
            dismiss()
        } label: {
            HStack(spacing: 12) {
                accountIcon(account)

                VStack(alignment: .leading, spacing: 4) {
                    Text(account.name)
                        .foregroundStyle(.primary)

                    if let currencyRecord = account.currencyRecord {
                        HStack(spacing: 4) {
                            Text(currencyRecord.flagEmoji)
                                .font(.caption2)
                            Text(currencyRecord.code)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatBalance(account))
                        .font(.body)
                        .foregroundColor(account.currentBalance < 0 ? .red : .primary)

                    if selectedAccount?.id == account.id {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(account.color)
                            .font(.caption)
                    }
                }
            }
        }
    }

    private func formatBalance(_ account: Account) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let code = account.currencyRecord?.code ?? account.currency.rawValue
        let amountString = formatter.string(from: account.currentBalance as NSDecimalNumber) ?? "0.00"
        return "\(code) \(amountString)"
    }

    @ViewBuilder
    private func accountIcon(_ account: Account) -> some View {
        if let imageData = account.imageData,
           let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(account.color, lineWidth: 2)
                )
        } else {
            ZStack {
                Circle()
                    .fill(account.color.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: account.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(account.color)
            }
        }
    }
}
