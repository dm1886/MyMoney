import Foundation

/// Production contract with the MyMoney market-data gateway. Provider keys remain
/// on the server; the gateway must verify the signed StoreKit entitlement and its
/// licensed exchange coverage. No synthetic quote is substituted on failure.
struct InvestmentMarketService {
    var baseURL: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "InvestmentMarketURL") as? String,
              let url = URL(string: raw), url.scheme == "https", url.host != nil else { return nil }
        return url
    }
    var configured: Bool { baseURL != nil }
    func search(_ text: String) async throws -> [InvestmentInstrument] {
        try await request("search", parameters: [URLQueryItem(name: "q", value: text)])
    }
    func quotes(for instrument: InvestmentInstrument, accountCurrency: String, from: Date) async throws -> [InvestmentQuote] {
        let values: [InvestmentQuote] = try await request("quotes", parameters: [
            URLQueryItem(name: "instrument", value: instrument.id),
            URLQueryItem(name: "currency", value: accountCurrency),
            URLQueryItem(name: "from", value: ISO8601DateFormatter().string(from: from))
        ])
        guard values.allSatisfy({ $0.instrumentID == instrument.id && $0.price > 0 && $0.fxToAccount > 0 && $0.date <= Date().addingTimeInterval(60) }) else {
            throw InvestmentError.invalidTrade
        }
        return values
    }
    private func request<T: Decodable>(_ path: String, parameters: [URLQueryItem]) async throws -> T {
        guard InvestmentAccess.shared.hasAccess else { throw InvestmentError.proRequired }
        guard let baseURL else { throw InvestmentError.unavailable }
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = parameters
        guard let url = components.url else { throw InvestmentError.unavailable }
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = InvestmentAccess.shared.signedTransaction { request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization") }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else { throw InvestmentError.unavailable }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }
}
