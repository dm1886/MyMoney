//
//  CurrencyAPIService.swift
//  MoneyTracker
//
//  Created on 2026-01-01.
//

import Foundation
import SwiftUI
import SwiftData

class CurrencyAPIService {
    static let shared = CurrencyAPIService()

    private init() {}

    // Updated to use new API with API key
    private let apiKey = "8d4bde32bba42c21365d2303"
    private let baseURL = "https://v6.exchangerate-api.com/v6/"

    // MARK: - Currency Update Functions

    func fetchRawAPI(baseCurrency: String) async throws -> String {
        let urlString = "\(baseURL)\(apiKey)/latest/\(baseCurrency)"
        Swift.print("🌐 [API] Fetching URL: \(urlString)")

        guard let url = URL(string: urlString) else {
            Swift.print("❌ [API] Invalid URL")
            throw CurrencyAPIError.invalidURL
        }

        Swift.print("📡 [API] Sending request...")
        let (data, response) = try await URLSession.shared.data(from: url)
        Swift.print("✅ [API] Received \(data.count) bytes")

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            Swift.print("❌ [API] Invalid response or status code")
            throw CurrencyAPIError.invalidResponse
        }

        Swift.print("✅ [API] Status code: \(httpResponse.statusCode)")
        return String(data: data, encoding: .utf8) ?? "Unable to decode data"
    }

    func parseCurrency(jsonString: String, context: ModelContext) throws {
        Swift.print("🔄 [API] Starting parseCurrency - Thread: \(Thread.isMainThread ? "MAIN" : "BACKGROUND")")

        // Decode JSON
        guard let jsonData = jsonString.data(using: .utf8) else {
            Swift.print("❌ [API] Failed to convert string to data")
            throw CurrencyAPIError.decodingError
        }

        Swift.print("🔄 [API] Decoding JSON...")
        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(ExchangeRateResponse.self, from: jsonData)
        Swift.print("✅ [API] Decoded \(apiResponse.conversion_rates.count) rates for base: \(apiResponse.base_code)")

        // Get base currency from database
        Swift.print("💾 [API] Fetching currencies from database...")
        let allCurrencies = try context.fetch(FetchDescriptor<CurrencyRecord>())
        Swift.print("💾 [API] Found \(allCurrencies.count) currencies in database")

        let currencyMap = Dictionary(uniqueKeysWithValues: allCurrencies.map { ($0.code, $0) })

        guard let baseCurrency = currencyMap[apiResponse.base_code] else {
            Swift.print("❌ [API] Base currency not found: \(apiResponse.base_code)")
            throw NSError(domain: "CurrencyAPI", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "Base currency not found: \(apiResponse.base_code)"])
        }

        Swift.print("✅ [API] Base currency: \(baseCurrency.code)")
        var updatedCount = 0

        // Update all rates (batch mode - no save per iteration)
        Swift.print("🔄 [API] Updating rates...")
        for (currencyCode, rateValue) in apiResponse.conversion_rates {
            guard let toCurrency = currencyMap[currencyCode] else { continue }

            let rate = Decimal(rateValue)

            CurrencyService.shared.updateExchangeRate(
                from: baseCurrency,
                to: toCurrency,
                rate: rate,
                source: .api,
                context: context,
                autoSave: false
            )

            updatedCount += 1

            if updatedCount % 50 == 0 {
                Swift.print("📝 [API] Progress: \(updatedCount) rates updated...")
            }
        }

        // Save all at once
        Swift.print("💾 [API] Saving all \(updatedCount) rates to database...")
        try context.save()
        Swift.print("✅ [API] Successfully saved \(updatedCount) rates")
    }

}

struct ExchangeRateResponse: Codable {
    let result: String
    let base_code: String
    let time_last_update_utc: String
    let conversion_rates: [String: Double]

    // Keep old names for backward compatibility in code
    var base: String { base_code }
    var rates: [String: Double] { conversion_rates }
}

enum CurrencyAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL non valido"
        case .invalidResponse:
            return "Risposta del server non valida"
        case .decodingError:
            return "Errore nella decodifica dei dati"
        }
    }
}
