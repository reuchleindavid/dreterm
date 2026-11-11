import AppKit
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            AppearanceSettings().tabItem { Label("Darstellung", systemImage: "paintpalette") }
            GeneralSettings().tabItem { Label("Allgemein", systemImage: "gearshape") }
            SnippetSettings().tabItem { Label("Snippets", systemImage: "text.badge.plus") }
        }
        .frame(width: 560, height: 460)
    }
}

struct AppearanceSettings: View {
    @EnvironmentObject var store: Store

    static let monoFonts: [String] = {
        let fm = NSFontManager.shared
        let fams = fm.availableFontFamilies.filter { fam in
            guard let f = NSFont(name: fam, size: 12) else {
                return fm.availableMembers(ofFontFamily: fam)?.first.flatMap { m in
                    (m[0] as? String).flatMap { NSFont(name: $0, size: 12)?.isFixedPitch }
                } ?? false
            }
            return f.isFixedPitch
        }
        return ["SF Mono"] + fams.filter { $0 != "SF Mono" }.sorted()
    }()

    var body: some View {
        Form {
            Section("Theme") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ForEach(Theme.all) { t in ThemeCard(theme: t, selected: t.id == store.settings.themeID)
                        .onTapGesture { store.settings.themeID = t.id }
                    }
                }
                .padding(.vertical, 4)
            }
            Section("Schrift") {
                Picker("Schriftart", selection: $store.settings.fontName) {
                    ForEach(Self.monoFonts, id: \.self) { Text($0).tag($0) }
                }
                HStack {
                    Text("Größe")
                    Slider(value: $store.settings.fontSize, in: 9...28, step: 1)
                    Text("\(Int(store.settings.fontSize)) pt").monospacedDigit().frame(width: 44)
                }
            }
            Section("Fenster") {
                HStack {
                    Text("Transparenz")
                    Slider(value: Binding(get: { 1 - store.settings.opacity },
                                          set: { store.settings.opacity = 1 - $0 }),
                           in: 0...0.7)
                    Text("\(Int(((1 - store.settings.opacity) * 100).rounded())) %").monospacedDigit().frame(width: 44)
                }
                Toggle("Hintergrund weichzeichnen", isOn: $store.settings.blur)
                Text("Auch per Tastatur: ⌘⌥+ deckender, ⌘⌥- transparenter.")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("Statusleiste anzeigen", isOn: $store.settings.showStatusBar)
                Toggle("Metal-Renderer (GPU)", isOn: $store.settings.useMetal)
            }
        }
        .formStyle(.grouped)
    }
}

struct ThemeCard: View {
    let theme: Theme
    let selected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 0) {
                    Text("dre").foregroundStyle(Color(nsColor: NSColor(hex: theme.ansi[2])))
                    Text(" ~ ").foregroundStyle(Color(nsColor: NSColor(hex: theme.ansi[4])))
                    Text("$ ls").foregroundStyle(theme.fg)
                }
                HStack(spacing: 4) {
                    ForEach(1..<7) { i in
                        RoundedRectangle(cornerRadius: 2).fill(Color(nsColor: NSColor(hex: theme.ansi[i])))
                            .frame(width: 12, height: 8)
                    }
                }
            }
            .font(.system(size: 11, design: .monospaced))
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.bg, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8)
                .strokeBorder(selected ? theme.accentColor : .secondary.opacity(0.25), lineWidth: selected ? 2 : 1))
            Text(theme.name).font(.system(size: 11, weight: selected ? .semibold : .regular))
        }
        .contentShape(Rectangle())
    }
}

struct GeneralSettings: View {
    @EnvironmentObject var store: Store

    var body: some View {
        Form {
            Section("Shell") {
                TextField("Shell", text: $store.settings.shell, prompt: Text(ProcInfo.userShell))
                Text("Leer lassen für die Standard-Shell des Benutzers. Gilt für neue Sitzungen.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Sitzungen") {
                Toggle("Neue Sitzung im Ordner der aktuellen Sitzung öffnen", isOn: $store.settings.newTabInCurrentDirectory)
                Toggle("Vor dem Schließen laufender Prozesse fragen", isOn: $store.settings.confirmCloseRunning)
            }
            Section("Speicherort") {
                Text("~/Library/Application Support/DRETerm/state.json")
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
        .formStyle(.grouped)
    }
}

struct SnippetSettings: View {
    @EnvironmentObject var store: Store
    @State private var selection: UUID?

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                List(selection: $selection) {
                    ForEach(store.snippets) { sn in
                        Text(sn.name).tag(sn.id)
                    }
                    .onMove { store.snippets.move(fromOffsets: $0, toOffset: $1) }
                }
                HStack(spacing: 0) {
                    Button {
                        let s = Snippet(name: "Neues Snippet", command: "echo hallo")
                        store.snippets.append(s)
                        selection = s.id
                    } label: { Image(systemName: "plus").frame(width: 24, height: 20) }
                    Button {
                        store.snippets.removeAll { $0.id == selection }
                        selection = nil
                    } label: { Image(systemName: "minus").frame(width: 24, height: 20) }
                    .disabled(selection == nil)
                    Spacer()
                }
                .buttonStyle(.borderless)
                .padding(6)
            }
            .frame(width: 190)
            Divider()
            if let id = selection, let i = store.snippets.firstIndex(where: { $0.id == id }) {
                Form {
                    TextField("Name", text: $store.snippets[i].name)
                    TextField("Befehl", text: $store.snippets[i].command, axis: .vertical)
                        .font(.system(size: 12, design: .monospaced))
                        .lineLimit(3...8)
                    Toggle("Sofort ausführen (sonst nur einfügen)", isOn: $store.snippets[i].runImmediately)
                }
                .formStyle(.grouped)
            } else {
                Text("Snippet auswählen oder mit + anlegen")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
