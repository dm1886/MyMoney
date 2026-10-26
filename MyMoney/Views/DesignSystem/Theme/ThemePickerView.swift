import SwiftUI

struct ThemePickerView: View {
    @Environment(\.appSettings) private var settings
    @Environment(\.orbMotionAllowed) private var motion
    @Environment(\.colorScheme) private var scheme
    @State private var editing: AppTheme?
    @State private var creating = false
    var body: some View {
        List {
            Section {
                ForEach(ThemeManager.shared.themes) { theme in
                    Button { ThemeManager.shared.select(theme.id, animated: motion) } label: {
                        HStack(spacing: 14) {
                            ThemeSwatch(theme: theme, selected: settings.selectedThemeId == theme.id)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(theme.name).font(.orbHeadline).foregroundStyle(Color.orbText)
                                Text(theme.isCustom ? "Personalizzato" : "Chiaro e scuro").font(.orbCaption).foregroundStyle(Color.orbMuted)
                            }
                            Spacer()
                            if settings.selectedThemeId == theme.id {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.orbHighlight)
                            }
                        }
                    }
                    .contextMenu {
                        Button("Duplica", systemImage: "plus.square.on.square") {
                            var copy = theme; copy.id = UUID().uuidString; copy.name += " · copia"; copy.isCustom = true
                            settings.customThemes.append(copy)
                            editing = copy
                        }
                        if theme.isCustom {
                            Button("Modifica", systemImage: "pencil") { editing = theme }
                            Button("Elimina", systemImage: "trash", role: .destructive) {
                                if settings.selectedThemeId == theme.id { ThemeManager.shared.select("notte", animated: motion) }
                                settings.customThemes.removeAll { $0.id == theme.id }
                            }
                        }
                    }
                    .accessibilityAddTraits(settings.selectedThemeId == theme.id ? .isSelected : [])
                    .listRowBackground(Color.orbCard)
                }
            } header: { Text("Tema colori") }
            Section {
                Button("Crea tema…", systemImage: "paintpalette") { creating = true }
            }.listRowBackground(Color.orbCard)
        }
        .orbScreen()
        .navigationTitle("Tema colori")
        .sheet(isPresented: $creating) { ThemeEditorView() }
        .sheet(item: $editing) { ThemeEditorView(existing: $0) }
    }
}

struct ThemeSwatch: View {
    @Environment(\.orbMotionAllowed) private var motion
    @State private var visible = false
    var theme: AppTheme
    var selected: Bool
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let palette = scheme == .dark ? theme.dark : theme.light
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !selected || !motion || !visible)) { context in
        ZStack {
            Circle().fill(palette.color(\.a1))
            Ellipse().fill(palette.color(\.a2)).opacity(0.7).rotationEffect(.degrees(-35)).padding(8)
        }.rotationEffect(.degrees(selected && motion && visible ? context.date.timeIntervalSinceReferenceDate / 30 * 360 : 0)).frame(width: 42, height: 42)
            .padding(4)
            .overlay(Circle().stroke(selected ? palette.color(\.hi) : Color.clear, lineWidth: 2))
            .accessibilityHidden(true)
        }.onAppear { visible = true }.onDisappear { visible = false }
    }
}

struct ThemeStrip: View {
    @Environment(\.appSettings) private var settings
    @Environment(\.orbMotionAllowed) private var motion
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(ThemeManager.shared.themes) { theme in
                    Button { ThemeManager.shared.select(theme.id, animated: motion) } label: {
                        VStack(spacing: 6) {
                            ThemeSwatch(theme: theme, selected: settings.selectedThemeId == theme.id)
                            Text(theme.name).font(.orbCaption).foregroundStyle(Color.orbMuted).lineLimit(1)
                        }.frame(minWidth: 54)
                    }.buttonStyle(.plain)
                        .accessibilityLabel("Tema \(theme.name)")
                        .accessibilityAddTraits(settings.selectedThemeId == theme.id ? .isSelected : [])
                }
            }.padding(.vertical, 5)
        }
    }
}

struct ThemeEditorView: View {
    var existing: AppTheme? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appSettings) private var settings
    @Environment(\.orbMotionAllowed) private var motion
    @State private var name = ""
    @State private var primary = Color(hex: "#6B4DFF")!
    @State private var secondary = Color(hex: "#FF6A8A")!
    @State private var tone: ThemeTone = .neutral
    @State private var corrected = false
    @State private var editedColors = false
    init(existing: AppTheme? = nil) {
        self.existing = existing
        _name = State(initialValue: existing?.name ?? "")
        _primary = State(initialValue: existing?.dark.color(\.a1) ?? Color(hex: "#6B4DFF")!)
        _secondary = State(initialValue: existing?.dark.color(\.a2) ?? Color(hex: "#FF6A8A")!)
        _tone = State(initialValue: existing?.tone ?? .neutral)
    }
    private var generated: AppTheme {
        // Preserve an existing hand-tuned palette when only renaming it.
        if let existing, !editedColors {
            var theme = existing; theme.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            return theme
        }
        return ThemeFactory.make(id: existing?.id ?? "preview", name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                 primary: primary.toHex() ?? "#6B4DFF", secondary: secondary.toHex() ?? "#FF6A8A", tone: tone)
    }
    private var preview: AppTheme { corrected ? ThemeFactory.corrected(generated) : generated }
    private var needsCorrection: Bool {
        [preview.dark, preview.light].contains { ThemeFactory.contrast($0.a1, $0.bg) < 3 || ThemeFactory.contrast($0.on, $0.a1) < 4.5 }
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Il tuo tema") {
                    TextField("Nome", text: $name)
                    ColorPicker("Primario", selection: $primary, supportsOpacity: false)
                        .onChange(of: primary) { editedColors = true; corrected = false }
                    ColorPicker("Secondario", selection: $secondary, supportsOpacity: false)
                        .onChange(of: secondary) { editedColors = true; corrected = false }
                    Picker("Tono dello sfondo", selection: $tone) {
                        ForEach(ThemeTone.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }.onChange(of: tone) { editedColors = true; corrected = false }
                }.listRowBackground(Color.orbCard)
                Section("Anteprima") {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) { previewTile(.light); previewTile(.dark) }
                        VStack(spacing: 8) { previewTile(.light); previewTile(.dark) }
                    }.listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                }
                if needsCorrection {
                    Section {
                        Label("Il primario ha poco contrasto sullo sfondo. Puoi correggerlo per entrambe le modalità.", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(Color.orbNegative)
                        Button("Correggi automaticamente") { corrected = true }
                    }.listRowBackground(Color.orbCard)
                }
            }.orbScreen()
                .navigationTitle(existing == nil ? "Crea tema" : "Modifica tema")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Salva") {
                            var result = preview
                            if existing == nil { result.id = UUID().uuidString }
                            result.isCustom = true
                            var themes = settings.customThemes
                            if let index = themes.firstIndex(where: { $0.id == result.id }) { themes[index] = result }
                            else { themes.append(result) }
                            settings.customThemes = themes
                            ThemeManager.shared.select(result.id, animated: motion)
                            dismiss()
                        }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

        }
    }
    private func previewTile(_ scheme: ColorScheme) -> some View {
        let p = scheme == .dark ? preview.dark : preview.light
        return VStack(spacing: 12) {
            Text(scheme == .dark ? "Scuro" : "Chiaro").font(.orbCaption).foregroundStyle(p.color(\.mu))
            OrbView(size: 115, isAnimating: scheme == .dark) {
                VStack(spacing: 4) {
                    Text("Saldo totale").font(.orbCaption2)
                    Text("1.234,56").font(.orbHeadline).monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
                }
            }
            HStack {
                Text("+ Nuova").font(.orbCaption).foregroundStyle(p.color(\.on))
            }.frame(maxWidth: .infinity).padding(10).background(p.color(\.a1), in: Capsule())
        }.padding(14).frame(minWidth: 135, maxWidth: .infinity)
            .background(p.color(\.bg), in: RoundedRectangle(cornerRadius: 20))
            .environment(\.theme, p).environment(\.colorScheme, scheme)
    }
}
