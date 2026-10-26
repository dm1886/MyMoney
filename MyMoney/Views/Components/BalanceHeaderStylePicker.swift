//
//  BalanceHeaderStylePicker.swift
//  MoneyTracker
//
//  Created on 2026-01-19.
//

import SwiftUI

struct BalanceHeaderStylePicker: View {
    @Environment(\.appSettings) var appSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(BalanceHeaderStyle.allCases, id: \.self) { style in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appSettings.balanceHeaderStyle = style
                    }
                } label: {
                    HStack(spacing: 16) {
                        // Icon
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(appSettings.balanceHeaderStyle == style ?
                                      Color.orbAccent.opacity(0.15) :
                                      Color.orbCard2)
                                .frame(width: 44, height: 44)

                            Image(systemName: style.icon)
                                .font(.orbTitle3)
                                .foregroundStyle(appSettings.balanceHeaderStyle == style ?
                                                 Color.orbAccent :
                                                 .secondary)
                        }

                        // Info
                        VStack(alignment: .leading, spacing: 4) {
                            Text(style.rawValue)
                                .font(.orbBody.weight(.medium))
                                .foregroundStyle(Color.orbText)

                            Text(style.description)
                                .font(.orbCaption)
                                .foregroundStyle(Color.orbMuted)
                                .lineLimit(2)
                        }

                        Spacer()

                        // Checkmark
                        if appSettings.balanceHeaderStyle == style {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.orbTitle2)
                                .foregroundStyle(Color.orbHighlight)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(appSettings.balanceHeaderStyle == style ?
                              Color.orbAccent.opacity(0.08) :
                              Color.clear)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                )
            }
        }.orbScreen()
        .listStyle(.insetGrouped)
        .navigationTitle("Stile Bilancio")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview with sample data
struct BalanceHeaderStylePreview: View {
    @Environment(\.appSettings) var appSettings

    var body: some View {
        VStack(spacing: 20) {
            // Preview of selected style
            Text("Anteprima")
                .font(.orbHeadline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            BalanceHeaderView(
                totalBalance: 12345.67,
                positiveBalance: 15000.00,
                negativeBalance: -2654.33,
                weeklyExpenses: [
                    DailyExpense(date: Date().addingTimeInterval(-6*24*3600), amount: 45.50, dayName: "Lun"),
                    DailyExpense(date: Date().addingTimeInterval(-5*24*3600), amount: 120.00, dayName: "Mar"),
                    DailyExpense(date: Date().addingTimeInterval(-4*24*3600), amount: 35.00, dayName: "Mer"),
                    DailyExpense(date: Date().addingTimeInterval(-3*24*3600), amount: 200.00, dayName: "Gio"),
                    DailyExpense(date: Date().addingTimeInterval(-2*24*3600), amount: 80.00, dayName: "Ven"),
                    DailyExpense(date: Date().addingTimeInterval(-1*24*3600), amount: 150.00, dayName: "Sab"),
                    DailyExpense(date: Date(), amount: 60.00, dayName: "Dom")
                ],
                currencySymbol: "EUR"
            )

            Spacer()
        }
        .padding(.top)
    }
}

#Preview {
    NavigationStack {
        BalanceHeaderStylePicker()
    }
}
