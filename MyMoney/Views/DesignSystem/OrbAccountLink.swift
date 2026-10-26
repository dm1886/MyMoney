import SwiftUI

enum OrbAccountAction: String, Identifiable, CaseIterable {
    case transaction = "Nuova transazione", adjust = "Aggiusta saldo", edit = "Modifica", delete = "Elimina"
    var id: String { rawValue }
    var icon: String {
        switch self { case .transaction: "plus.circle"; case .adjust: "slider.horizontal.3"; case .edit: "pencil"; case .delete: "trash" }
    }
}
struct OrbAccountLink: View {
    let account: Account
    let preferredCurrency: Currency
    let preferredCurrencyRecord: CurrencyRecord?
    let exchangeRatesCount: Int
    @State private var action: OrbAccountAction?
    var body: some View {
        HStack(spacing: 8) {
            NavigationLink(destination: AccountDetailView(account: account)) {
                AccountRow(account: account, preferredCurrency: preferredCurrency, preferredCurrencyRecord: preferredCurrencyRecord, exchangeRatesCount: exchangeRatesCount)
            }
            Menu { actions } label: {
                Image(systemName: "ellipsis").font(.system(size: 16, weight: .semibold))
                    .frame(width: 36, height: 36).background(Color.orbCard2, in: Circle())
                    .frame(width: 44, height: 44)
            }.accessibilityLabel("Azioni per " + account.name)
        }
        .contextMenu { actions }
        .navigationDestination(item: $action) { AccountDetailView(account: account, initialAction: $0) }
    }
    @ViewBuilder private var actions: some View {
        ForEach(OrbAccountAction.allCases) { item in
            if item == .delete { Divider() }
            Button(role: item == .delete ? .destructive : nil) { action = item } label: { Label(item.rawValue, systemImage: item.icon) }
        }
    }
}
