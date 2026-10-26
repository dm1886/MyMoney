import SwiftUI

extension Font {
    static func orb(_ size: CGFloat, weight: Font.Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Sora-Regular", size: size, relativeTo: style).weight(weight)
    }
    static var orbDisplay: Font { .orb(38, weight: .bold, relativeTo: .largeTitle) }
    static var orbTitle: Font { .orb(26, weight: .bold, relativeTo: .title) }
    static var orbTitle2: Font { .orb(22, weight: .bold, relativeTo: .title2) }
    static var orbTitle3: Font { .orb(19, weight: .semibold, relativeTo: .title3) }
    static var orbHeadline: Font { .orb(16, weight: .semibold, relativeTo: .headline) }
    static var orbBody: Font { .orb(14, relativeTo: .body) }
    static var orbSubheadline: Font { .orb(13, relativeTo: .subheadline) }
    static var orbCaption: Font { .orb(11, relativeTo: .caption) }
    static var orbCaption2: Font { .orb(10, relativeTo: .caption2) }
    static var orbFootnote: Font { .orb(12, relativeTo: .footnote) }
}

private struct BlobShape: Shape {
    var phase: Double
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) * 0.43
        var p = Path()
        for i in 0...120 {
            let angle = Double(i) / 120 * .pi * 2
            let r = radius * (1 + 0.085 * sin(angle * 3 + phase) + 0.045 * cos(angle * 5 - phase * 0.7))
            let point = CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
            if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
        }
        p.closeSubpath()
        return p
    }
}

struct OrbView<Content: View>: View {
    var size: CGFloat = 210
    var primary: Color? = nil
    var secondary: Color? = nil
    var isAnimating = true
    var orbitLabels: [String] = []
    var showsRings = false
    @ViewBuilder var content: Content
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    @Environment(\.orbMotionAllowed) private var motion
    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var visible = false
    private var running: Bool { visible && motion && !reduce && isAnimating }
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !running)) { context in
            let time = running ? context.date.timeIntervalSinceReferenceDate : 0
            ZStack {
                if showsRings && running {
                    ForEach(0..<2, id: \.self) { index in
                        let cycle = (time + Double(index) * 1.2).truncatingRemainder(dividingBy: 2.4) / 2.4
                        Circle().stroke(theme.color(index == 0 ? \.a1 : \.a2).opacity((1 - cycle) * 0.6), lineWidth: 1)
                            .scaleEffect(0.6 + cycle * 1.1)
                    }
                }
                BlobShape(phase: time / 9 * .pi * 2)
                    .fill(primary ?? theme.color(\.a1))
                    .rotationEffect(.degrees(time / 30 * 360))
                BlobShape(phase: -time / 7 * .pi * 2)
                    .fill(secondary ?? theme.color(\.a2)).opacity(0.55)
                    .blendMode(scheme == .dark ? .screen : .multiply)
                    .rotationEffect(.degrees(-time / 24 * 360))
                    .padding(size * 0.06)
                // Keep the numeric content on a stable contrast surface, independent of blending.
                content
                    .foregroundStyle(theme.color(\.on))
                    .padding(10)
                    .scaleEffect(running ? 1.025 + 0.025 * sin(time * .pi / 2) : 1)
                    .padding(size * 0.12)
                if !orbitLabels.isEmpty {
                    Circle().stroke(theme.color(\.line), style: StrokeStyle(lineWidth: 1, dash: [3, 5]))
                        .padding(-size * 0.08)
                        .rotationEffect(.degrees(time / 40 * 360))
                    ForEach(Array(orbitLabels.prefix(4).enumerated()), id: \.offset) { i, label in
                        let angle = Double(i) / Double(min(orbitLabels.count, 4)) * .pi * 2 + time / 40 * .pi * 2
                        Text(label).font(.orbCaption2).foregroundStyle(theme.color(\.mu))
                            .padding(.horizontal, 7).padding(.vertical, 4)
                            .background(theme.color(\.card), in: Capsule())
                            .offset(x: cos(angle) * size * 0.58, y: sin(angle) * size * 0.58)
                    }
                }
            }
            .frame(width: size, height: size)
        }
        .onAppear { visible = true }
        .onDisappear { visible = false }
    }
}

struct OrbCard<Content: View>: View {
    var secondary = false
    var outlined = false
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(secondary ? Color.orbCard2 : Color.orbCard, in: RoundedRectangle(cornerRadius: 20))
            .overlay { if outlined { RoundedRectangle(cornerRadius: 20).stroke(Color.orbLine, style: StrokeStyle(lineWidth: 1, dash: [5, 4])) } }
    }
}
struct StatTile: View {
    var label: String
    var value: String
    var color: Color = .orbText
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.orbCaption).foregroundStyle(Color.orbMuted)
            Text(value).font(.orbHeadline).monospacedDigit().foregroundStyle(color)
                .lineLimit(1).minimumScaleFactor(0.65)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
            .background(Color.orbCard, in: RoundedRectangle(cornerRadius: 16))
    }
}
struct AmountText: View {
    let amount: Decimal
    var symbol = ""
    @Environment(\.orbMotionAllowed) private var motion
    var body: some View {
        OrbAmountLabel(amount: amount) { symbol + FormatterCache.formatCurrencyFixed($0) }
            .foregroundStyle(amount < 0 ? Color.orbNegative : Color.orbText)
            .contentTransition(.numericText(value: NSDecimalNumber(decimal: amount).doubleValue))
            .animation(motion ? .easeOut(duration: 1.8) : nil, value: amount)
    }
}
struct ProgressBarView: View {
    var progress: Double
    var color: Color = .orbAccent
    @Environment(\.orbMotionAllowed) private var motion
    @State private var appeared = false
    var body: some View {
        GeometryReader { g in
            Capsule().fill(Color.orbCard2)
                .overlay(alignment: .leading) {
                    Capsule().fill(progress >= 0.9 ? Color.orbNegative : color)
                        .frame(width: g.size.width * (appeared ? min(max(progress, 0), 1) : 0))
                }
        }.frame(height: 7)
            .onAppear { withAnimation(motion ? .spring(response: 0.8, dampingFraction: 0.8) : nil) { appeared = true } }
            .animation(motion ? .easeOut(duration: 1) : nil, value: progress)
            .accessibilityLabel("Progresso").accessibilityValue("\(Int(progress * 100)) percento")
    }
}
struct ProgressRing: View {
    var progress: Double
    var color: Color = .orbAccent
    @Environment(\.orbMotionAllowed) private var motion
    @State private var appeared = false
    var body: some View {
        ZStack {
            Circle().stroke(Color.orbCard2, lineWidth: 7)
            Circle().trim(from: 0, to: appeared ? min(max(progress, 0), 1) : 0)
                .stroke(progress >= 0.9 ? Color.orbNegative : color, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(progress * 100))%").font(.orbCaption).monospacedDigit()
        }.frame(width: 58, height: 58)
            .onAppear { withAnimation(motion ? .easeOut(duration: 1) : nil) { appeared = true } }
            .animation(motion ? .easeOut(duration: 1) : nil, value: progress)
            .accessibilityElement(children: .ignore).accessibilityLabel("Budget utilizzato").accessibilityValue("\(Int(progress * 100)) percento")
    }
}
struct OrbFAB: View {
    var action: () -> Void
    @Environment(\.orbMotionAllowed) private var motion
    @State private var visible = false
    var body: some View {
        Button(action: action) {
            Image(systemName: "plus").font(.title2.weight(.semibold))
                .frame(width: 56, height: 56).foregroundStyle(Color.orbOnAccent)
                .background(Color.orbAccent, in: Circle())
        }.buttonStyle(OrbPressStyle())
            .background {
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !motion || !visible)) { context in
                    let phase = motion && visible ? context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2) / 2 : 0
                    Circle().stroke(Color.orbAccent.opacity(motion ? (1 - phase) * 0.45 : 0), lineWidth: 2)
                        .scaleEffect(1 + phase * 0.6)
                }
            }
            .accessibilityLabel("Nuova transazione")
            .onAppear { visible = true }.onDisappear { visible = false }
    }
}
struct OrbPressStyle: ButtonStyle {
    @Environment(\.orbMotionAllowed) private var motion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed && motion ? 0.94 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}
struct OrbPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.orbHeadline).frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(Color.orbOnAccent)
            .background(Color.orbAccent, in: Capsule()).opacity(enabled ? 1 : 0.45)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
struct OrbChip: View {
    var title: String
    var selected = false
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.orbSubheadline).padding(.horizontal, 14).frame(minHeight: 44)
                .foregroundStyle(selected ? Color.orbText : Color.orbMuted)
                .background(selected ? Color.orbCard2 : Color.clear, in: Capsule())
                .overlay(Capsule().stroke(selected ? Color.orbHighlight : Color.orbLine, lineWidth: 1))
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }
}
struct OrbSegmented<Value: Hashable>: View {
    let values: [Value]
    @Binding var selection: Value
    var title: (Value) -> String
    @Namespace private var namespace
    @Environment(\.orbMotionAllowed) private var motion
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(values, id: \.self) { value in
                    Button {
                        withAnimation(motion ? .spring(response: 0.35, dampingFraction: 0.8) : nil) { selection = value }
                        HapticManager.shared.selectionFeedback()
                    } label: {
                        Text(title(value)).font(.orbSubheadline).padding(.horizontal, 16).frame(minHeight: 44)
                            .foregroundStyle(selection == value ? Color.orbOnAccent : Color.orbMuted)
                            .background { if selection == value { Capsule().fill(Color.orbAccent).matchedGeometryEffect(id: "selection", in: namespace) } }
                    }.buttonStyle(.plain).accessibilityAddTraits(selection == value ? .isSelected : [])
                }
            }.padding(4).background(Color.orbCard2, in: Capsule())
        }
    }
}
struct OrbListRow: View {
    var icon: String
    var title: String
    var subtitle: String? = nil
    var value: String? = nil
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.body.weight(.semibold)).foregroundStyle(Color.orbHighlight)
                .frame(width: 38, height: 38).background(Color.orbCard2, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.orbHeadline)
                if let subtitle { Text(subtitle).font(.orbCaption).foregroundStyle(Color.orbMuted) }
            }
            Spacer()
            if let value { Text(value).font(.orbHeadline).monospacedDigit() }
        }.padding(.vertical, 4)
    }
}
struct OrbSectionHeader: View {
    var title: String
    var body: some View { Text(title).font(.orbCaption).textCase(.uppercase).tracking(1.5).foregroundStyle(Color.orbMuted) }
}
struct OrbRiseIn: ViewModifier {
    var index: Int
    @State private var appeared = false
    @Environment(\.orbMotionAllowed) private var motion
    func body(content: Content) -> some View {
        content.opacity(appeared ? 1 : 0).offset(y: appeared || !motion ? 0 : 16)
            .onAppear {
                guard !appeared else { return }
                withAnimation(motion ? .easeOut(duration: 0.55).delay(Double(min(index, 6)) * 0.09) : .easeOut(duration: 0.2)) { appeared = true }
            }
    }
}
extension View {
    func orbSurface(radius: CGFloat = 20) -> some View {
        background(Color.orbCard, in: RoundedRectangle(cornerRadius: radius))
    }
    func orbScreen() -> some View {
        scrollContentBackground(.hidden).background(Color.orbBackground)
            .toolbarBackground(Color.orbBackground, for: .navigationBar)
            .listRowBackground(Color.orbCard)
    }
    func riseIn(_ index: Int = 0) -> some View { modifier(OrbRiseIn(index: index)) }
}

#Preview("Orb · preset chiari e scuri") {
    ScrollView {
        ForEach(ThemePresets.all) { theme in
            HStack {
                ForEach([ColorScheme.light, .dark], id: \.self) { scheme in
                    OrbView(size: 130, isAnimating: false) { Text(theme.name).font(.orbHeadline) }
                        .environment(\.theme, scheme == .dark ? theme.dark : theme.light)
                        .environment(\.colorScheme, scheme)
                        .padding().background((scheme == .dark ? theme.dark : theme.light).color(\.bg))
                }
            }
        }
    }
}

extension TransactionType {
    var orbColor: Color {
        switch self {
        case .expense: .orbNegative
        case .income: .orbPositive
        case .transfer: .orbAccent
        case .liabilityPayment: .orbHighlight
        case .adjustment: .orbMuted
        }
    }
}

struct OrbShimmer: ViewModifier {
    @Environment(\.orbMotionAllowed) private var motion
    @State private var visible = false
    func body(content: Content) -> some View {
        content.overlay {
            if motion && visible {
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                    let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.6) / 2.6
                    GeometryReader { g in
                        LinearGradient(colors: [.clear, Color.orbHighlight.opacity(0.12), .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: g.size.width * 0.5)
                            .offset(x: g.size.width * (phase * 1.5 - 0.5))
                    }
                }.clipShape(RoundedRectangle(cornerRadius: 20)).allowsHitTesting(false).accessibilityHidden(true)
            }
        }.onAppear { visible = true }.onDisappear { visible = false }
    }
}

struct OrbTabActivity: ViewModifier {
    var active: Bool
    @Environment(\.orbMotionAllowed) private var allowed
    func body(content: Content) -> some View { content.environment(\.orbMotionAllowed, allowed && active) }
}

struct OrbChartReveal: ViewModifier {
    enum Kind { case bars, pie, line }
    var kind: Kind
    @Environment(\.orbMotionAllowed) private var motion
    @State private var appeared = false
    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .scaleEffect(x: kind == .pie && !appeared && motion ? 0.6 : 1,
                         y: !appeared && motion && kind != .line ? (kind == .pie ? 0.6 : 0.01) : 1,
                         anchor: kind == .bars ? .bottom : .center)
            .rotationEffect(.degrees(kind == .pie && !appeared && motion ? -110 : 0))
            .mask(alignment: .leading) {
                GeometryReader { g in
                    Rectangle().frame(width: g.size.width * (kind == .line && !appeared && motion ? 0 : 1))
                }
            }
            .onAppear {
                guard !appeared else { return }
                withAnimation(motion ? .easeOut(duration: kind == .line ? 1.6 : 1) : .easeOut(duration: 0.2)) { appeared = true }
            }
    }
}

extension Notification.Name { static let orbSaveFeedback = Notification.Name("orbSaveFeedback") }
struct OrbSaveFeedback: ViewModifier {
    @Environment(\.orbMotionAllowed) private var motion
    @State private var saved: UUID?
    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if saved != nil {
                OrbSuccessLabel()
                    .font(.orbHeadline).foregroundStyle(Color.orbOnAccent)
                    .padding(.horizontal, 20).padding(.vertical, 14)
                    .background(Color.orbAccent, in: Capsule()).padding(.top, 10)
                    .transition(motion ? .scale(scale: 0.8).combined(with: .opacity) : .opacity)
                    .allowsHitTesting(false).accessibilityAddTraits(.updatesFrequently)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .orbSaveFeedback)) { _ in
            withAnimation(motion ? .spring(response: 0.35, dampingFraction: 0.7) : nil) { saved = UUID() }
        }
        .task(id: saved) {
            guard saved != nil else { return }
            do { try await Task.sleep(for: .milliseconds(900)) } catch { return }
            withAnimation(.easeOut(duration: 0.2)) { saved = nil }
        }
    }
}

/// Only intermediate frames use Double; the settled label always formats the exact Decimal.
private struct OrbInterpolatedAmount: View, Animatable {
    var value: Double
    var exact: Decimal
    var format: (Decimal) -> String
    var animatableData: Double {
        get { value }
        set { value = newValue }
    }
    var body: some View {
        let target = NSDecimalNumber(decimal: exact).doubleValue
        Text(format(value == target ? exact : Decimal(value))).monospacedDigit()
            .lineLimit(1).minimumScaleFactor(0.1).allowsTightening(true)
    }
}
struct OrbAmountLabel: View {
    var amount: Decimal
    var format: (Decimal) -> String
    @Environment(\.orbMotionAllowed) private var motion
    @State private var appeared = false
    var body: some View {
        OrbInterpolatedAmount(value: appeared || !motion ? NSDecimalNumber(decimal: amount).doubleValue : 0,
                              exact: amount, format: format)
            .animation(motion ? .easeOut(duration: 1.8) : nil, value: amount)
            .onAppear {
                guard !appeared else { return }
                withAnimation(motion ? .easeOut(duration: 1.8) : nil) { appeared = true }
            }
            .accessibilityLabel(format(amount))
    }
}

@MainActor private enum OrbBudgetWarnings { static var shown: Set<UUID> = [] }
struct OrbBudgetWarning: ViewModifier {
    var id: UUID
    var progress: Double
    @Environment(\.orbMotionAllowed) private var motion
    @State private var warning = false
    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: 0.0, trigger: warning) { view, angle in
            view.rotationEffect(.degrees(motion ? angle : 0))
        } keyframes: { _ in
            LinearKeyframe(6, duration: 0.2)
            LinearKeyframe(-6, duration: 0.25)
            LinearKeyframe(6, duration: 0.25)
            LinearKeyframe(0, duration: 0.3)
        }
        .onChange(of: progress >= 0.9, initial: true) { _, exceeded in
            guard exceeded, OrbBudgetWarnings.shown.insert(id).inserted else { return }
            HapticManager.shared.limitReached()
            warning = true
        }
    }
}
struct OrbSyncSymbol: View {
    var systemName: String
    var isActive: Bool
    @Environment(\.orbMotionAllowed) private var motion
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !motion || !isActive)) { context in
            Image(systemName: systemName)
                .rotationEffect(.degrees(motion && isActive ? context.date.timeIntervalSinceReferenceDate / 0.9 * 360 : 0))
        }.accessibilityHidden(true)
    }
}


private struct OrbSuccessLabel: View {
    @Environment(\.orbMotionAllowed) private var motion
    @State private var appeared = false
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .scaleEffect(appeared ? 1 : (motion ? 0.3 : 1))
                .animation(motion ? .spring(response: 0.4, dampingFraction: 0.55) : nil, value: appeared)
                .background {
                    Circle().stroke(Color.orbOnAccent, lineWidth: 1.5)
                        .scaleEffect(appeared && motion ? 2.4 : 1)
                        .opacity(appeared ? 0 : 0.8)
                        .animation(motion ? .easeOut(duration: 0.8) : nil, value: appeared)
                }
            Text("Salvato")
        }.onAppear { appeared = true }
    }
}
