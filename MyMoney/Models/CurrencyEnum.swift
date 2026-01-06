//
//  CurrencyEnum.swift
//  MoneyTracker
//
//  Created on 2026-01-01.
//

import Foundation

enum Currency: String, Codable, CaseIterable {
    // Europa (25)
    case EUR, GBP, CHF, SEK, NOK, DKK, PLN, CZK, HUF, RON
    case BGN, HRK, RUB, TRY, UAH, ISK, ALL, BAM, MKD, RSD
    case MDL, GEL, AMD, AZN, BYN

    // Americhe (22)
    case USD, CAD, MXN, BRL, ARS, CLP, COP, PEN, VES, UYU
    case PYG, BOB, CRC, GTQ, HNL, NIO, PAB, DOP, JMD, TTD
    case BBD, BSD, BZD

    // Asia (27)
    case JPY, CNY, HKD, MOP, TWD, KRW, SGD, THB, MYR, IDR
    case PHP, VND, INR, PKR, BDT, LKR, NPR, AFN, MMK, KHR
    case LAK, BND, MNT, KZT, UZS, KGS, TJS, TMT

    // Medio Oriente (13)
    case AED, SAR, QAR, KWD, BHD, OMR, ILS, JOD, LBP, SYP
    case IQD, YER, IRR

    // Oceania (8)
    case AUD, NZD, FJD, PGK, WST, SBD, TOP, VUV

    // Africa (40)
    case ZAR, EGP, NGN, KES, GHS, MAD, TND, DZD, AOA, XOF
    case XAF, ETB, TZS, UGX, MWK, ZMW, BWP, MUR, SCR, MZN
    case NAD, SZL, LSL, GMD, SLL, LRD, RWF, BIF, DJF, ERN
    case STN, CVE, GNF, MRU, SOS, SDG, SSP, LYD

    // Crypto & Commodities (3)
    case BTC, XAU, XAG

    var symbol: String {
        let symbols: [Currency: String] = [
            // Europa
            .EUR: "€", .GBP: "£", .CHF: "Fr", .SEK: "kr", .NOK: "kr", .DKK: "kr",
            .PLN: "zł", .CZK: "Kč", .HUF: "Ft", .RON: "lei", .BGN: "лв", .HRK: "kn",
            .RUB: "₽", .TRY: "₺", .UAH: "₴", .ISK: "kr", .ALL: "L", .BAM: "KM",
            .MKD: "ден", .RSD: "дин", .MDL: "L", .GEL: "₾", .AMD: "֏", .AZN: "₼", .BYN: "Br",

            // Americhe
            .USD: "$", .CAD: "C$", .MXN: "Mex$", .BRL: "R$", .ARS: "AR$", .CLP: "CLP$",
            .COP: "COL$", .PEN: "S/", .VES: "Bs.S", .UYU: "$U", .PYG: "₲", .BOB: "Bs",
            .CRC: "₡", .GTQ: "Q", .HNL: "L", .NIO: "C$", .PAB: "B/.", .DOP: "RD$",
            .JMD: "J$", .TTD: "TT$", .BBD: "Bds$", .BSD: "B$", .BZD: "BZ$",

            // Asia
            .JPY: "¥", .CNY: "¥", .HKD: "HK$", .MOP: "MOP$", .TWD: "NT$", .KRW: "₩",
            .SGD: "S$", .THB: "฿", .MYR: "RM", .IDR: "Rp", .PHP: "₱", .VND: "₫",
            .INR: "₹", .PKR: "₨", .BDT: "৳", .LKR: "Rs", .NPR: "₨", .AFN: "؋",
            .MMK: "K", .KHR: "៛", .LAK: "₭", .BND: "B$", .MNT: "₮", .KZT: "₸",
            .UZS: "so'm", .KGS: "с", .TJS: "SM", .TMT: "m",

            // Medio Oriente
            .AED: "د.إ", .SAR: "﷼", .QAR: "ر.ق", .KWD: "د.ك", .BHD: "د.ب", .OMR: "ر.ع",
            .ILS: "₪", .JOD: "د.ا", .LBP: "ل.ل", .SYP: "£S", .IQD: "ع.د", .YER: "﷼", .IRR: "﷼",

            // Oceania
            .AUD: "A$", .NZD: "NZ$", .FJD: "FJ$", .PGK: "K", .WST: "T", .SBD: "SI$",
            .TOP: "T$", .VUV: "VT",

            // Africa
            .ZAR: "R", .EGP: "E£", .NGN: "₦", .KES: "KSh", .GHS: "₵", .MAD: "د.م",
            .TND: "د.ت", .DZD: "د.ج", .AOA: "Kz", .XOF: "Fr", .XAF: "Fr", .ETB: "Br",
            .TZS: "TSh", .UGX: "USh", .MWK: "MK", .ZMW: "ZK", .BWP: "P", .MUR: "₨",
            .SCR: "₨", .MZN: "MT", .NAD: "N$", .SZL: "L", .LSL: "L", .GMD: "D",
            .SLL: "Le", .LRD: "L$", .RWF: "Fr", .BIF: "Fr", .DJF: "Fr", .ERN: "Nfk",
            .STN: "Db", .CVE: "$", .GNF: "Fr", .MRU: "UM", .SOS: "Sh", .SDG: "£",
            .SSP: "£", .LYD: "ل.د",

            // Crypto & Commodities
            .BTC: "₿", .XAU: "Au", .XAG: "Ag"
        ]
        return symbols[self] ?? rawValue
    }

    var flag: String {
        return CurrencyHelper.flag(for: self)
    }

    var fullName: String {
        let names: [Currency: String] = [
            // Europa
            .EUR: "Euro", .GBP: "Sterlina Britannica", .CHF: "Franco Svizzero",
            .SEK: "Corona Svedese", .NOK: "Corona Norvegese", .DKK: "Corona Danese",
            .PLN: "Zloty Polacco", .CZK: "Corona Ceca", .HUF: "Fiorino Ungherese",
            .RON: "Leu Rumeno", .BGN: "Lev Bulgaro", .HRK: "Kuna Croata",
            .RUB: "Rublo Russo", .TRY: "Lira Turca", .UAH: "Grivnia Ucraina",
            .ISK: "Corona Islandese", .ALL: "Lek Albanese", .BAM: "Marco Convertibile",
            .MKD: "Denar Macedone", .RSD: "Dinaro Serbo", .MDL: "Leu Moldavo",
            .GEL: "Lari Georgiano", .AMD: "Dram Armeno", .AZN: "Manat Azero", .BYN: "Rublo Bielorusso",

            // Americhe
            .USD: "Dollaro Statunitense", .CAD: "Dollaro Canadese", .MXN: "Peso Messicano",
            .BRL: "Real Brasiliano", .ARS: "Peso Argentino", .CLP: "Peso Cileno",
            .COP: "Peso Colombiano", .PEN: "Sol Peruviano", .VES: "Bolivar Venezuelano",
            .UYU: "Peso Uruguaiano", .PYG: "Guaraní Paraguaiano", .BOB: "Boliviano",
            .CRC: "Colón Costaricano", .GTQ: "Quetzal Guatemalteco", .HNL: "Lempira Honduregno",
            .NIO: "Córdoba Nicaraguense", .PAB: "Balboa Panamense", .DOP: "Peso Dominicano",
            .JMD: "Dollaro Giamaicano", .TTD: "Dollaro di Trinidad e Tobago", .BBD: "Dollaro di Barbados",
            .BSD: "Dollaro delle Bahamas", .BZD: "Dollaro del Belize",

            // Asia
            .JPY: "Yen Giapponese", .CNY: "Renminbi Cinese", .HKD: "Dollaro di Hong Kong",
            .MOP: "Pataca di Macao", .TWD: "Dollaro di Taiwan", .KRW: "Won Sudcoreano",
            .SGD: "Dollaro di Singapore", .THB: "Baht Thailandese", .MYR: "Ringgit Malese",
            .IDR: "Rupia Indonesiana", .PHP: "Peso Filippino", .VND: "Dong Vietnamita",
            .INR: "Rupia Indiana", .PKR: "Rupia Pakistana", .BDT: "Taka Bangladese",
            .LKR: "Rupia dello Sri Lanka", .NPR: "Rupia Nepalese", .AFN: "Afghani",
            .MMK: "Kyat Birmano", .KHR: "Riel Cambogiano", .LAK: "Kip Laotiano",
            .BND: "Dollaro del Brunei", .MNT: "Tugrik Mongolo", .KZT: "Tenge Kazako",
            .UZS: "Som Uzbeko", .KGS: "Som Kirghiso", .TJS: "Somoni Tagiko", .TMT: "Manat Turkmeno",

            // Medio Oriente
            .AED: "Dirham degli Emirati", .SAR: "Riyal Saudita", .QAR: "Riyal del Qatar",
            .KWD: "Dinaro del Kuwait", .BHD: "Dinaro del Bahrain", .OMR: "Rial dell'Oman",
            .ILS: "Shekel Israeliano", .JOD: "Dinaro Giordano", .LBP: "Lira Libanese",
            .SYP: "Lira Siriana", .IQD: "Dinaro Iracheno", .YER: "Rial Yemenita", .IRR: "Rial Iraniano",

            // Oceania
            .AUD: "Dollaro Australiano", .NZD: "Dollaro Neozelandese", .FJD: "Dollaro delle Figi",
            .PGK: "Kina della Papua Nuova Guinea", .WST: "Tala Samoano", .SBD: "Dollaro delle Salomone",
            .TOP: "Paʻanga Tongano", .VUV: "Vatu di Vanuatu",

            // Africa
            .ZAR: "Rand Sudafricano", .EGP: "Sterlina Egiziana", .NGN: "Naira Nigeriana",
            .KES: "Scellino Keniota", .GHS: "Cedi Ghanese", .MAD: "Dirham Marocchino",
            .TND: "Dinaro Tunisino", .DZD: "Dinaro Algerino", .AOA: "Kwanza Angolano",
            .XOF: "Franco CFA Occidentale", .XAF: "Franco CFA Centrale", .ETB: "Birr Etiope",
            .TZS: "Scellino Tanzaniano", .UGX: "Scellino Ugandese", .MWK: "Kwacha Malawiano",
            .ZMW: "Kwacha Zambiano", .BWP: "Pula del Botswana", .MUR: "Rupia Mauriziana",
            .SCR: "Rupia delle Seychelles", .MZN: "Metical Mozambicano", .NAD: "Dollaro Namibiano",
            .SZL: "Lilangeni dello Swaziland", .LSL: "Loti del Lesotho", .GMD: "Dalasi Gambiano",
            .SLL: "Leone della Sierra Leone", .LRD: "Dollaro Liberiano", .RWF: "Franco Ruandese",
            .BIF: "Franco del Burundi", .DJF: "Franco di Gibuti", .ERN: "Nakfa Eritreo",
            .STN: "Dobra di Sao Tomé", .CVE: "Escudo di Capo Verde", .GNF: "Franco Guineano",
            .MRU: "Ouguiya Mauritano", .SOS: "Scellino Somalo", .SDG: "Sterlina Sudanese",
            .SSP: "Sterlina Sud-Sudanese", .LYD: "Dinaro Libico",

            // Crypto & Commodities
            .BTC: "Bitcoin", .XAU: "Oro", .XAG: "Argento"
        ]
        return names[self] ?? rawValue
    }

    var displayName: String {
        return "\(flag) \(rawValue) - \(fullName)"
    }
}
