//
//  ResocontoView.swift
//  MoneyTracker
//
//  Created on 2026-01-11.
//

import SwiftUI
import SwiftData

struct ResocontoView: View {
    @Environment(\.appSettings) var appSettings

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        HistoricalBalanceView()
                    } label: {
                        HStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(appSettings.accentColor.opacity(0.15))
                                    .frame(width: 44, height: 44)

                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 20))
                                    .foregroundStyle(appSettings.accentColor)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Saldo Storico")
                                    .font(.body.bold())
                                    .foregroundStyle(.primary)

                                Text("Visualizza il saldo di un conto in una data specifica")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    NavigationLink {
                        IncomeExpenseReportView()
                    } label: {
                        HStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.green.opacity(0.15))
                                    .frame(width: 44, height: 44)

                                Image(systemName: "chart.bar.xaxis")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.green)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Entrate e Uscite")
                                    .font(.body.bold())
                                    .foregroundStyle(.primary)

                                Text("Analizza entrate e uscite nel tempo")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.bar.doc.horizontal.fill")
                            .foregroundStyle(appSettings.accentColor)
                        Text("Report Disponibili")
                            .foregroundStyle(.primary)
                    }
                    .font(.subheadline.bold())
                    .textCase(nil)
                } footer: {
                    Text("Seleziona un report per visualizzare statistiche e analisi dettagliate")
                }
            }
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
