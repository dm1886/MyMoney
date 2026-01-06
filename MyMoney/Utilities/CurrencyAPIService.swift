//
//  CurrencyAPIService.swift
//  MoneyTracker
//
//  Created on 2026-01-01.
//

import Foundation

class CurrencyAPIService {
    static let shared = CurrencyAPIService()

    private init() {}

    // Updated to use new API with API key
    private let apiKey = "8d4bde32bba42c21365d2303"
    private let baseURL = "https://v6.exchangerate-api.com/v6/"

    func fetchExchangeRates(baseCurrency: Currency) async throws -> [Currency: Decimal] {
        let urlString = "\(baseURL)\(apiKey)/latest/\(baseCurrency.rawValue)"

        print("🌐 [CurrencyAPI] Starting fetch for base currency: \(baseCurrency.rawValue)")
        print("🌐 [CurrencyAPI] URL: \(urlString)")

        guard let url = URL(string: urlString) else {
            print("❌ [CurrencyAPI] Invalid URL: \(urlString)")
            throw CurrencyAPIError.invalidURL
        }

        print("📡 [CurrencyAPI] Sending request...")
        let (data, response) = try await URLSession.shared.data(from: url)
        print("✅ [CurrencyAPI] Received response, data size: \(data.count) bytes")

        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [CurrencyAPI] Response is not HTTPURLResponse")
            throw CurrencyAPIError.invalidResponse
        }

        print("📊 [CurrencyAPI] HTTP Status Code: \(httpResponse.statusCode)")

        guard (200...299).contains(httpResponse.statusCode) else {
            print("❌ [CurrencyAPI] Invalid status code: \(httpResponse.statusCode)")
            throw CurrencyAPIError.invalidResponse
        }

        print("🔄 [CurrencyAPI] Decoding JSON response...")
        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(ExchangeRateResponse.self, from: data)
        print("✅ [CurrencyAPI] Successfully decoded. Base: \(apiResponse.base), Rates count: \(apiResponse.rates.count)")

        var rates: [Currency: Decimal] = [:]

        for currency in Currency.allCases {
            if let rate = apiResponse.rates[currency.rawValue] {
                rates[currency] = Decimal(rate)
            }
        }

        print("✅ [CurrencyAPI] Converted \(rates.count) rates to Decimal format")
        return rates
    }

    func updateAllRates(baseCurrency: Currency) async throws {
        print("🚀 [CurrencyAPI] Starting updateAllRates with base: \(baseCurrency.rawValue)")

        // Fetch rates once - this gives us all conversion rates from the base currency
        let rates = try await fetchExchangeRates(baseCurrency: baseCurrency)

        print("💾 [CurrencyAPI] Updating \(rates.count) rates in CurrencyConverter...")
        var updatedCount = 0

        // Update all rates from base currency to other currencies
        for (toCurrency, rate) in rates {
            CurrencyConverter.shared.updateExchangeRate(
                from: baseCurrency,
                to: toCurrency,
                rate: rate
            )
            updatedCount += 1

            if updatedCount % 20 == 0 {
                print("📝 [CurrencyAPI] Progress: Updated \(updatedCount)/\(rates.count) rates")
            }
        }

        print("✅ [CurrencyAPI] Successfully updated \(updatedCount) exchange rates!")
        print("✅ [CurrencyAPI] Update completed at \(Date())")
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
