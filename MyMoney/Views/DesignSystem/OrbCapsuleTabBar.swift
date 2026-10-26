import SwiftUI

extension Notification.Name {
    static let orbReselectTab = Notification.Name("orbReselectTab")
    static let orbAddTransaction = Notification.Name("orbAddTransaction")
    static let orbShowDate = Notification.Name("orbShowDate")
}

struct OrbCapsuleTabBar: View {
    @Binding var selection: Int
    var onAdd: () -> Void
    @Namespace private var namespace
    @Environment(\.orbMotionAllowed) private var motion
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.theme) private var theme
    @State private var visible = false
    @State private var start = Date()
    private let items = [("Home", "house.fill"), ("Bilancio", "chart.bar.fill"), ("Oggi", "calendar"), ("Resoconto", "chart.bar.doc.horizontal"), ("More", "ellipsis")]
    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 0) {
                ForEach(items.indices, id: \.self) { i in
                    Button {
                        if selection == i {
                            NotificationCenter.default.post(name: .orbReselectTab, object: i)
                        } else {
                            HapticManager.shared.selectionFeedback()
                            withAnimation(motion ? .spring(response: 0.45, dampingFraction: 0.72) : .easeOut(duration: 0.2)) { selection = i }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: items[i].1).font(.system(size: 20, weight: .semibold))
                                .symbolEffect(.bounce, options: .nonRepeating, value: motion && selection == i)
                            if selection == i && !typeSize.isAccessibilitySize {
                                Text(items[i].0).font(.orb(11, weight: .semibold)).lineLimit(1).fixedSize(horizontal: true, vertical: false)
                                    .transition(motion ? .opacity.combined(with: .move(edge: .leading)) : .opacity)
                            }
                        }
                        .foregroundStyle(selection == i ? Color.orbOnAccent : Color.orbMuted)
                        .padding(.horizontal, selection == i && !typeSize.isAccessibilitySize ? 8 : 0)
                        .frame(minWidth: 40, minHeight: 48)
                        .background {
                            if selection == i {
                                Capsule().fill(Color.orbAccent).matchedGeometryEffect(id: "pill", in: namespace)
                            }
                        }
                        .frame(minHeight: 60).contentShape(Rectangle())
                    }
                    .buttonStyle(OrbPressStyle())
                    .accessibilityLabel(items[i].0)
                    .accessibilityAddTraits(selection == i ? .isSelected : [])
                    .accessibilityShowsLargeContentViewer { Label(items[i].0, systemImage: items[i].1) }
                    if i < items.count - 1 { Spacer(minLength: 0) }
                }
            }
            .padding(.horizontal, 6).frame(height: 60)
            .background(Color.orbCard, in: Capsule())
            .overlay(Capsule().stroke(Color.orbLine, lineWidth: 1))
            Button(action: onAdd) {
                Image(systemName: "plus").font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color(hex: theme.onSecondary) ?? .orbText)
                    .frame(width: 60, height: 60)
                    .background(Color.orbSecondary, in: Circle())
                    .background {
                        TimelineView(.animation(minimumInterval: 1 / 30, paused: !motion || !visible)) { context in
                            let elapsed = max(0, context.date.timeIntervalSince(start) - 1.2)
                            let phase = elapsed.truncatingRemainder(dividingBy: 2) / 2
                            Circle().stroke(Color.orbSecondary.opacity(motion && visible && elapsed > 0 ? (1 - phase) * 0.5 : 0), lineWidth: 2)
                                .padding(-18 * phase)
                        }
                    }
            }.buttonStyle(OrbPressStyle()).accessibilityLabel("Nuova transazione")
        }
        .frame(maxWidth: 480)
        .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background(alignment: .bottom) {
            LinearGradient(colors: [.clear, Color.orbBackground.opacity(0.45)], startPoint: .top, endPoint: .bottom)
                .frame(height: 120).ignoresSafeArea(edges: .bottom).allowsHitTesting(false)
        }
        .accessibilityElement(children: .contain).accessibilityLabel("Barra delle sezioni")
        .onAppear { visible = true; start = Date() }.onDisappear { visible = false }
    }
}

/// Bridges re-selection to the existing native stacks, including destination-based
/// NavigationLinks, without replacing any root view or resetting its @State.
struct OrbTabReselect: UIViewControllerRepresentable {
    let tab: Int
    func makeUIViewController(context: Context) -> Controller { Controller(tab: tab) }
    func updateUIViewController(_ controller: Controller, context: Context) {}
    final class Controller: UIViewController {
        let tabIndex: Int
        var observer: NSObjectProtocol?
        init(tab: Int) { self.tabIndex = tab; super.init(nibName: nil, bundle: nil) }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override func viewDidLoad() {
            super.viewDidLoad()
            view.isUserInteractionEnabled = false
            observer = NotificationCenter.default.addObserver(forName: .orbReselectTab, object: nil, queue: .main) { [weak self] note in
                guard let self, note.object as? Int == self.tabIndex else { return }
                MainActor.assumeIsolated { self.reselect() }
            }
        }
        deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }
        private func reselect() {
            var ancestor: UIViewController? = self
            while let current = ancestor {
                if let nav = current.navigationController {
                    if nav.viewControllers.count > 1 { nav.popToRootViewController(animated: !UIAccessibility.isReduceMotionEnabled) }
                    else if let root = nav.viewControllers.first { scrollTop(root.view) }
                    return
                }
                ancestor = current.parent
            }
        }
        private func scrollTop(_ view: UIView) {
            if let scroll = view as? UIScrollView, scroll.contentSize.height > scroll.bounds.height {
                scroll.setContentOffset(CGPoint(x: -scroll.adjustedContentInset.left, y: -scroll.adjustedContentInset.top), animated: !UIAccessibility.isReduceMotionEnabled)
                return
            }
            for child in view.subviews { scrollTop(child) }
        }
    }
}
