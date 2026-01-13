//
//  ResocontoView.swift
//  MoneyTracker
//
//  Created on 2026-01-11.
//

import SwiftUI
import SwiftData

struct ResocontoView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appSettings) var appSettings
    @Query private var transactions: [Transaction]
    @Query private var accounts: [Account]

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()

                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.system(size: 60))
                    .foregroundStyle(appSettings.accentColor.opacity(0.3))

                Text("Resoconto")
                    .font(.title.bold())

                Text("Grafici e statistiche in arrivo")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Resoconto")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ResocontoView()
        .environment(\.appSettings, AppSettings.shared)
        .modelContainer(for: [Transaction.self, Account.self])
}
