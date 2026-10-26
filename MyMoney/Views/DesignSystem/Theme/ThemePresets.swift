import SwiftUI

/// Presentation-only values. Financial models and CloudKit are deliberately independent.
struct ThemeColors: Codable, Equatable {
    var bg, card, card2, line, tx, mu, a1, a2, pos, neg, hi, on: String

    init(_ values: String) {
        let v = values.split(separator: " ").map(String.init)
        precondition(v.count == 12)
        (bg, card, card2, line, tx, mu, a1, a2, pos, neg, hi, on) =
            (v[0], v[1], v[2], v[3], v[4], v[5], v[6], v[7], v[8], v[9], v[10], v[11])
    }
    var onSecondary: String { ThemeFactory.contrast("#FFFFFF", a2) >= 3 ? "#FFFFFF" : ThemeFactory.foreground(on: a2) }
    func color(_ key: KeyPath<ThemeColors, String>) -> Color {
        Color(hex: self[keyPath: key]) ?? .primary
    }
}

struct AppTheme: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var dark: ThemeColors
    var light: ThemeColors
    var isCustom = false
    var tone: ThemeTone? = nil
}

enum ThemePresets {
    static let notte = AppTheme(id: "notte", name: "Notte",
        dark: ThemeColors("#0C0B1A #17162C #2A2650 #3A3766 #E9E7FF #9D9AC2 #6B4DFF #FF6A8A #7EE2A8 #FF8FA6 #B9A8FF #FFFFFF"),
        light: ThemeColors("#F4F1FF #FFFFFF #ECE7FF #D8D0F5 #1B1640 #615B85 #6B4DFF #FF6A8A #12805C #C2304F #6B4DFF #FFFFFF"))
    static let aurora = AppTheme(id: "aurora", name: "Aurora",
        dark: ThemeColors("#07161A #0F2429 #173A40 #24525A #E3FBF6 #8FB8B1 #0B7A6E #A3E635 #A3E635 #FF9B85 #5EEAD4 #FFFFFF"),
        light: ThemeColors("#EEF8F6 #FFFFFF #DCF1EC #C3E3DC #0B2A26 #4D6E68 #0B7A6E #65A30D #3F7D0A #C2410C #0B7A6E #FFFFFF"))
    static let brace = AppTheme(id: "brace", name: "Brace",
        dark: ThemeColors("#140C08 #24160F #3A2216 #5A3524 #FFF1E8 #C4A493 #C2410C #FFB703 #9BE38A #FF8A7A #FFB98A #FFFFFF"),
        light: ThemeColors("#FBF3EE #FFFFFF #F6E4D8 #ECD2C1 #2A160C #7A5A48 #C2410C #D98E04 #2F7D32 #B42318 #C2410C #FFFFFF"))
    static let oceano = AppTheme(id: "oceano", name: "Oceano",
        dark: ThemeColors("#050B18 #0D1830 #16264A #26406E #E6EFFF #8EA3C8 #2563EB #22D3EE #6EE7B7 #FDA4AF #93C5FD #FFFFFF"),
        light: ThemeColors("#EEF3FC #FFFFFF #DFE8FA #C9D7F2 #0B1A33 #4F6185 #2563EB #0891B2 #047857 #BE123C #2563EB #FFFFFF"))
    static let grafite = AppTheme(id: "grafite", name: "Grafite",
        dark: ThemeColors("#121316 #1D1F24 #2A2D34 #3A3E48 #F1F2F4 #A3A8B3 #D4F25C #5B8CFF #D4F25C #FF9F6B #D4F25C #121316"),
        light: ThemeColors("#F2F3F1 #FFFFFF #E6E8E3 #D4D7D0 #16181C #5D636E #4D7C0F #3B6EF5 #4D7C0F #C2410C #4D7C0F #FFFFFF"))
    static let all = [notte, aurora, brace, oceano, grafite]
}

enum ThemeTone: String, Codable, CaseIterable {
    case neutral = "Neutro", warm = "Caldo", cool = "Freddo"
}

/// Pure palette generation and WCAG relative luminance, shared by migration and editor.
enum ThemeFactory {
    static func rgb(_ hex: String) -> [Double] {
        let number = UInt64(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0
        return [Double((number >> 16) & 255), Double((number >> 8) & 255), Double(number & 255)].map { $0 / 255 }
    }
    static func luminance(_ hex: String) -> Double {
        let c = rgb(hex).map { $0 <= 0.04045 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
        return c[0] * 0.2126 + c[1] * 0.7152 + c[2] * 0.0722
    }
    static func contrast(_ a: String, _ b: String) -> Double {
        let x = luminance(a), y = luminance(b)
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }
    static func mix(_ base: String, _ tint: String, _ fraction: Double) -> String {
        let a = rgb(base), b = rgb(tint)
        let c: [Int] = (0..<3).map { index in
            let channel = a[index] * (1.0 - fraction) + b[index] * fraction
            return Int((channel * 255.0).rounded())
        }
        return String(format: "#%02X%02X%02X", c[0], c[1], c[2])
    }
    static func foreground(on hex: String) -> String {
        contrast("#FFFFFF", hex) >= contrast("#121316", hex) ? "#FFFFFF" : "#121316"
    }
    static func make(id: String = UUID().uuidString, name: String, primary: String, secondary: String, tone: ThemeTone) -> AppTheme {
        var dark = ThemePresets.notte.dark, light = ThemePresets.notte.light
        let darkBase = tone == .warm ? "#17120F" : tone == .cool ? "#0D1520" : "#121316"
        let lightBase = tone == .warm ? "#FAF5F0" : tone == .cool ? "#F1F6FC" : "#F5F5F5"
        dark.bg = mix(darkBase, primary, 0.04)
        dark.card = mix(mix(darkBase, "#FFFFFF", 0.05), primary, 0.06)
        dark.card2 = mix(mix(darkBase, "#FFFFFF", 0.12), primary, 0.08)
        dark.line = mix(darkBase, "#FFFFFF", 0.23)
        light.bg = mix(lightBase, primary, 0.04)
        light.card = "#FFFFFF"
        light.card2 = mix(lightBase, primary, 0.08)
        light.line = mix(lightBase, primary, 0.20)
        dark.tx = "#F2F2F7"; dark.mu = "#A8A8BC"
        light.tx = "#171724"; light.mu = "#626274"
        dark.a1 = primary; light.a1 = primary
        dark.a2 = secondary; light.a2 = secondary
        dark.on = foreground(on: primary); light.on = dark.on
        dark.hi = mix(primary, "#FFFFFF", 0.4)
        light.hi = mix(primary, "#121316", 0.35)
        return AppTheme(id: id, name: name, dark: dark, light: light, isCustom: true, tone: tone)
    }
    static func corrected(_ theme: AppTheme) -> AppTheme {
        var result = theme
        func correct(_ p: ThemeColors) -> ThemeColors {
            var p = p
            let target = luminance(p.bg) < 0.5 ? "#FFFFFF" : "#121316"
            let original = p.a1
            for step in 0...100 {
                p.a1 = mix(original, target, Double(step) / 100)
                if contrast(p.a1, p.bg) >= 3 { break }
            }
            p.on = foreground(on: p.a1)
            p.hi = mix(p.a1, target, 0.35)
            return p
        }
        result.dark = correct(result.dark); result.light = correct(result.light)
        return result
    }
}
