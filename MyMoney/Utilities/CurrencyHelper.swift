//
//  CurrencyHelper.swift
//  MoneyTracker
//
//  Created on 2026-01-01.
//

import Foundation

struct CurrencyHelper {

    /// Mappa il codice valuta al codice paese per ottenere la bandiera corretta
    static func countryCode(for currency: Currency) -> String {
        switch currency {
        // Europa
        case .EUR: return "EU"
        case .GBP: return "GB"
        case .CHF: return "CH"
        case .SEK: return "SE"
        case .NOK: return "NO"
        case .DKK: return "DK"
        case .PLN: return "PL"
        case .CZK: return "CZ"
        case .HUF: return "HU"
        case .RON: return "RO"
        case .BGN: return "BG"
        case .HRK: return "HR"
        case .RUB: return "RU"
        case .TRY: return "TR"
        case .UAH: return "UA"
        case .ISK: return "IS"
        case .ALL: return "AL"
        case .BAM: return "BA"
        case .MKD: return "MK"
        case .RSD: return "RS"
        case .MDL: return "MD"
        case .GEL: return "GE"
        case .AMD: return "AM"
        case .AZN: return "AZ"
        case .BYN: return "BY"

        // Americhe
        case .USD: return "US"
        case .CAD: return "CA"
        case .MXN: return "MX"
        case .BRL: return "BR"
        case .ARS: return "AR"
        case .CLP: return "CL"
        case .COP: return "CO"
        case .PEN: return "PE"
        case .VES: return "VE"
        case .UYU: return "UY"
        case .PYG: return "PY"
        case .BOB: return "BO"
        case .CRC: return "CR"
        case .GTQ: return "GT"
        case .HNL: return "HN"
        case .NIO: return "NI"
        case .PAB: return "PA"
        case .DOP: return "DO"
        case .JMD: return "JM"
        case .TTD: return "TT"
        case .BBD: return "BB"
        case .BSD: return "BS"
        case .BZD: return "BZ"

        // Asia
        case .JPY: return "JP"
        case .CNY: return "CN"
        case .HKD: return "HK"
        case .MOP: return "MO"
        case .TWD: return "TW"
        case .KRW: return "KR"
        case .SGD: return "SG"
        case .THB: return "TH"
        case .MYR: return "MY"
        case .IDR: return "ID"
        case .PHP: return "PH"
        case .VND: return "VN"
        case .INR: return "IN"
        case .PKR: return "PK"
        case .BDT: return "BD"
        case .LKR: return "LK"
        case .NPR: return "NP"
        case .AFN: return "AF"
        case .MMK: return "MM"
        case .KHR: return "KH"
        case .LAK: return "LA"
        case .BND: return "BN"
        case .MNT: return "MN"
        case .KZT: return "KZ"
        case .UZS: return "UZ"
        case .KGS: return "KG"
        case .TJS: return "TJ"
        case .TMT: return "TM"

        // Medio Oriente
        case .AED: return "AE"
        case .SAR: return "SA"
        case .QAR: return "QA"
        case .KWD: return "KW"
        case .BHD: return "BH"
        case .OMR: return "OM"
        case .ILS: return "IL"
        case .JOD: return "JO"
        case .LBP: return "LB"
        case .SYP: return "SY"
        case .IQD: return "IQ"
        case .YER: return "YE"
        case .IRR: return "IR"

        // Oceania
        case .AUD: return "AU"
        case .NZD: return "NZ"
        case .FJD: return "FJ"
        case .PGK: return "PG"
        case .WST: return "WS"
        case .SBD: return "SB"
        case .TOP: return "TO"
        case .VUV: return "VU"

        // Africa
        case .ZAR: return "ZA"
        case .EGP: return "EG"
        case .NGN: return "NG"
        case .KES: return "KE"
        case .GHS: return "GH"
        case .MAD: return "MA"
        case .TND: return "TN"
        case .DZD: return "DZ"
        case .AOA: return "AO"
        case .XOF: return "SN" // West African CFA (Senegal)
        case .XAF: return "CM" // Central African CFA (Cameroon)
        case .ETB: return "ET"
        case .TZS: return "TZ"
        case .UGX: return "UG"
        case .MWK: return "MW"
        case .ZMW: return "ZM"
        case .BWP: return "BW"
        case .MUR: return "MU"
        case .SCR: return "SC"
        case .MZN: return "MZ"
        case .NAD: return "NA"
        case .SZL: return "SZ"
        case .LSL: return "LS"
        case .GMD: return "GM"
        case .SLL: return "SL"
        case .LRD: return "LR"
        case .RWF: return "RW"
        case .BIF: return "BI"
        case .DJF: return "DJ"
        case .ERN: return "ER"
        case .STN: return "ST"
        case .CVE: return "CV"
        case .GNF: return "GN"
        case .MRU: return "MR"
        case .SOS: return "SO"
        case .SDG: return "SD"
        case .SSP: return "SS"
        case .LYD: return "LY"

        // Altre
        case .BTC: return "XX" // Bitcoin (nessuna bandiera specifica)
        case .XAU: return "XX" // Oro (nessuna bandiera)
        case .XAG: return "XX" // Argento (nessuna bandiera)
        }
    }

    /// Genera l'emoji della bandiera dal codice paese
    static func flagEmoji(for countryCode: String) -> String {
        // Gestione speciale per codici non standard
        if countryCode == "EU" {
            return "🇪🇺"
        }
        if countryCode == "XX" {
            return "🌐" // Globo per valute non nazionali
        }

        let base: UInt32 = 127397
        var emoji = ""
        for scalar in countryCode.uppercased().unicodeScalars {
            if let unicode = UnicodeScalar(base + scalar.value) {
                emoji.append(String(unicode))
            }
        }
        return emoji.isEmpty ? "🏳️" : emoji
    }

    /// Ottiene la bandiera per una valuta
    static func flag(for currency: Currency) -> String {
        return flagEmoji(for: countryCode(for: currency))
    }
}
