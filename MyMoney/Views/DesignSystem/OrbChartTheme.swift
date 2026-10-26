import SwiftUI

struct OrbChartPalette {
    let inc, exp, grid, axis, other: String
    let dark: Bool
    var ok: String { dark ? "#6EE7B7" : "#047857" }
    var warning: String { dark ? "#FBBF24" : "#B45309" }
    var exceeded: String { dark ? "#FDA4AF" : "#B42318" }
    var expSoft: Color { Color(hex: exp)!.opacity(dark ? 0.40 : 0.35) }
    var areaFill: Color { Color(hex: inc)!.opacity(dark ? 0.18 : 0.10) }
}
extension ThemeColors {
    /// Computed, so themes and backups saved before v1.2 remain decodable.
    var chart: OrbChartPalette {
        let dark = ThemeFactory.luminance(bg) < 0.3
        let income: String
        switch a1.uppercased() {
        case "#6B4DFF": income = dark ? "#8B74FF" : "#6B4DFF"
        case "#0B7A6E": income = dark ? "#1FA392" : "#079A88"
        case "#C2410C": income = dark ? "#4C8DFF" : "#2A78D6"
        case "#2563EB": income = dark ? "#4C8DFF" : "#2563EB"
        case "#D4F25C", "#4D7C0F": income = dark ? "#5B8CFF" : "#3B6EF5"
        default: income = dark ? "#5B8CFF" : "#2A78D6"
        }
        return OrbChartPalette(inc: income, exp: dark ? "#E86A35" : (a1.uppercased() == "#C2410C" ? "#C2410C" : "#EB6834"), grid: card2, axis: line, other: dark ? "#4A5874" : "#A3AEC2", dark: dark)
    }
}
extension Color {
    private static func chartColor(_ key: KeyPath<OrbChartPalette, String>) -> Color {
        let selected = ThemeManager.shared.selected
        return Color(uiColor: UIColor { traits in
            let colors = (traits.userInterfaceStyle == .dark ? selected.dark : selected.light).chart
            let rgb = ThemeFactory.rgb(colors[keyPath: key])
            return UIColor(red: rgb[0], green: rgb[1], blue: rgb[2], alpha: 1)
        })
    }
    static var chartOnTrack: Color { chartColor(\.ok) }
    static var chartWarning: Color { chartColor(\.warning) }
    static var chartExceeded: Color { chartColor(\.exceeded) }
    static var chartIncome: Color { chartColor(\.inc) }
    static var chartExpense: Color { chartColor(\.exp) }
    static var chartGrid: Color { chartColor(\.grid) }
    static var chartAxis: Color { chartColor(\.axis) }
    static var chartOther: Color { chartColor(\.other) }
}

/// Presentation formatting only; currency conversion and Decimal values are unchanged.
enum OrbCurrency {
    static func string(_ amount: Decimal, symbol: String) -> String {
        symbol + " " + FormatterCache.formatCurrencyFixed(amount)
    }
    static func string(_ amount: Double, symbol: String) -> String {
        string(Decimal(amount), symbol: symbol)
    }
}

extension Transaction {
    var orbDisplayAmount: String {
        OrbCurrency.string(amount, symbol: currencyRecord?.displaySymbol ?? currency.symbol)
    }
}
