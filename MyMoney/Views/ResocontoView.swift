import SwiftUI
import SwiftData

struct ResocontoView: View {
    @Environment(\.appSettings) var appSettings
    @Environment(\.dynamicTypeSize) private var textSize
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: textSize.isAccessibilitySize ? 1 : 2)
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: 16) {
                        OrbView(size: 74, isAnimating: false) {
                            Image(systemName: "chart.bar.doc.horizontal").font(.title2)
                        }.accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Resoconto").font(.orbTitle)
                            Text("Analizza entrate e uscite nel tempo")
                                .font(.orbSubheadline).foregroundStyle(Color.orbMuted)
                        }
                    }
                    OrbSectionHeader(title: "Report disponibili")
                    LazyVGrid(columns: columns, spacing: 12) {
                        NavigationLink { HistoricalBalanceView() } label: {
                            reportCard("Saldo Storico", subtitle: "Il saldo dei conti nel tempo", icon: "clock.arrow.circlepath", index: 0)
                        }
                        NavigationLink { IncomeExpenseReportView() } label: {
                            reportCard("Entrate e Uscite", subtitle: "Movimenti, medie e totali", icon: "chart.bar.xaxis", index: 1)
                        }
                        NavigationLink { CategoryExpensesReportView() } label: {
                            reportCard("Spese per Categoria", subtitle: "Dove vanno i tuoi soldi", icon: "chart.pie.fill", index: 2)
                        }
                        NavigationLink { RecurringTransactionsReportView() } label: {
                            reportCard("Transazioni Ricorrenti", subtitle: "Le operazioni ripetitive previste", icon: "repeat.circle.fill", index: 3)
                        }
                    }.buttonStyle(.plain)
                    Text("Seleziona un report per visualizzare statistiche e analisi dettagliate")
                        .font(.orbCaption).foregroundStyle(Color.orbMuted)
                }.padding(20)
            }.orbScreen().background(OrbTabReselect(tab: 3)).navigationBarTitleDisplayMode(.inline)
        }
    }
    private func reportCard(_ title: String, subtitle: String, icon: String, index: Int) -> some View {
        OrbCard {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: icon).font(.title2).foregroundStyle(Color.orbHighlight)
                    .frame(width: 44, height: 44).background(Color.orbCard2, in: Circle())
                Text(title).font(.orbHeadline).foregroundStyle(Color.orbText).fixedSize(horizontal: false, vertical: true)
                Text(subtitle).font(.orbCaption).foregroundStyle(Color.orbMuted).fixedSize(horizontal: false, vertical: true)
                HStack { Spacer(); Image(systemName: "arrow.up.right").foregroundStyle(Color.orbHighlight) }
            }.frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
        }.riseIn(index)
    }
}

#Preview { ResocontoView().modifier(OrbThemeScope()) }
