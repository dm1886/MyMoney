import SwiftUI

@Observable final class ThemeManager {
    static let shared = ThemeManager()
    var themes: [AppTheme] { ThemePresets.all + AppSettings.shared.customThemes }
    var selected: AppTheme { themes.first { $0.id == AppSettings.shared.selectedThemeId } ?? ThemePresets.notte }
    func colors(for scheme: ColorScheme) -> ThemeColors { scheme == .dark ? selected.dark : selected.light }
    func select(_ id: String, animated: Bool = true) {
        guard themes.contains(where: { $0.id == id }) else { return }
        withAnimation(animated ? .easeInOut(duration: 0.6) : nil) { AppSettings.shared.selectedThemeId = id }
        HapticManager.shared.selectionFeedback()
    }
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = ThemePresets.notte.light
}
private struct OrbMotionKey: EnvironmentKey { static let defaultValue = true }
extension EnvironmentValues {
    var theme: ThemeColors {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
    var orbMotionAllowed: Bool {
        get { self[OrbMotionKey.self] }
        set { self[OrbMotionKey.self] = newValue }
    }
}

/// Resolve system appearance inside sheets too; capture the selected theme during
/// body evaluation so Observation invalidates existing screens without resetting them.
extension Color {
    private static func orb(_ key: KeyPath<ThemeColors, String>) -> Color {
        let selected = ThemeManager.shared.selected
        return Color(uiColor: UIColor { traits in
            let p = traits.userInterfaceStyle == .dark ? selected.dark : selected.light
            let c = ThemeFactory.rgb(p[keyPath: key])
            return UIColor(red: c[0], green: c[1], blue: c[2], alpha: 1)
        })
    }
    static var orbBackground: Color { orb(\.bg) }
    static var orbCard: Color { orb(\.card) }
    static var orbCard2: Color { orb(\.card2) }
    static var orbLine: Color { orb(\.line) }
    static var orbText: Color { orb(\.tx) }
    static var orbMuted: Color { orb(\.mu) }
    static var orbAccent: Color { orb(\.a1) }
    static var orbSecondary: Color { orb(\.a2) }
    static var orbPositive: Color { orb(\.pos) }
    static var orbNegative: Color { orb(\.neg) }
    static var orbHighlight: Color { orb(\.hi) }
    static var orbOnAccent: Color { orb(\.on) }
}

struct OrbThemeScope: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    func body(content: Content) -> some View {
        content
            .environment(\.theme, ThemeManager.shared.colors(for: scheme))
            .environment(\.orbMotionAllowed, !reduceMotion && !AppSettings.shared.reduceDecorativeMotion && !lowPower && scenePhase == .active)
            .transaction { transaction in
                if reduceMotion || AppSettings.shared.reduceDecorativeMotion || lowPower { transaction.animation = nil }
            }
            .font(.orbBody)
            .foregroundStyle(Color.orbText)
            .tint(Color.orbHighlight)
            .background(Color.orbBackground.ignoresSafeArea())
            .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
                lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
            }
    }
}
