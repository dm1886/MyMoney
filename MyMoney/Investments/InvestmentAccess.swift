import Foundation
import StoreKit
import Observation

@MainActor @Observable
final class InvestmentAccess {
    static let shared = InvestmentAccess()
    private(set) var entitled = false
    private(set) var products: [Product] = []
    private(set) var message: String?
    private(set) var busy = false
    private(set) var signedTransaction: String?
    private var listener: Task<Void, Never>?
    var productIDs: [String] { Bundle.main.object(forInfoDictionaryKey: "InvestmentProductIDs") as? [String] ?? [] }
    var hasAccess: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-investment-preview") { return true }
        #endif
        return entitled
    }
    private init() {
        listener = Task { [weak self] in
            for await result in StoreKit.Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = result, self.productIDs.contains(transaction.productID) {
                    await self.refresh(); await transaction.finish()
                }
            }
        }
    }
    func refresh() async {
        var access = false, token: String?
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               productIDs.contains(transaction.productID), transaction.revocationDate == nil {
                access = true; token = result.jwsRepresentation
            }
        }
        entitled = access; signedTransaction = token
    }
    func load() async {
        await refresh()
        guard !productIDs.isEmpty else { message = "MyMoney Pro sarà disponibile prossimamente. Nessun acquisto è attivo in questa versione."; return }
        do { products = try await Product.products(for: productIDs); message = products.isEmpty ? "Offerte temporaneamente non disponibili." : nil }
        catch { message = error.localizedDescription }
    }
    func purchase(_ product: Product) async {
        guard !busy else { return }; busy = true; defer { busy = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else { message = "Acquisto non verificato. Riprova con Ripristina acquisti."; return }
                await refresh(); await transaction.finish()
            case .pending: message = "Acquisto in attesa di approvazione."
            case .userCancelled: break
            @unknown default: break
            }
        } catch { message = error.localizedDescription }
    }
    func restore() async {
        busy = true; defer { busy = false }
        do { try await AppStore.sync(); await refresh(); message = entitled ? "Acquisto ripristinato." : "Nessun acquisto attivo trovato." }
        catch { message = error.localizedDescription }
    }
}
