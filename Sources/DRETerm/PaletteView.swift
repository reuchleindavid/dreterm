import AppKit
import SwiftUI

struct PaletteItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let color: Color?
    let action: () -> Void
}

struct PaletteView: View {
    @EnvironmentObject var store: Store
    @State private var query = ""
    @State private var index = 0
    @FocusState private var focused: Bool

    private var allItems: [PaletteItem] {
        var items: [PaletteItem] = []
        for s in store.orderedSessions {
            let rt = store.runtime[s.id] ?? SessionRuntime()
            let sub = rt.isShellIdle ? s.directory.abbreviatingHome : "\(rt.process) · \(s.directory.abbreviatingHome)"
            items.append(PaletteItem(id: "s-\(s.id)", title: s.name, subtitle: sub, icon: s.icon,
                                     color: s.color == .none ? nil : s.color.color) { [store] in
                store.selectedID = s.id
            })
        }
        for sn in store.snippets {
            items.append(PaletteItem(id: "n-\(sn.id)", title: sn.name, subtitle: sn.command, icon: "play.fill", color: nil) { [store] in
                store.run(sn)
            })
        }
        let actions: [(String, String, () -> Void)] = [
            ("Neue Sitzung", "plus", { store.newSession() }),
            ("Neue Sitzung im Home-Ordner", "house", { store.newSession(directory: NSHomeDirectory()) }),
            ("Sitzung umbenennen", "pencil", { store.renamingID = store.selectedID }),
            ("Sitzung duplizieren", "plus.square.on.square", { if let id = store.selectedID { store.duplicate(id) } }),
            ("Sitzung anheften / lösen", "pin", { if let id = store.selectedID { store.modify(id) { $0.pinned.toggle() } } }),
            ("Sitzung schließen", "xmark", { store.close(store.selectedID) }),
            ("Notizen ein/aus", "sidebar.right", { store.showInspector.toggle() }),
            ("Im Finder zeigen", "folder", { store.revealInFinder(store.selectedID) }),
            ("Pfad kopieren", "doc.on.doc", { store.copyPath(store.selectedID) }),
            ("Bildschirm leeren", "eraser", { store.clearScreen() }),
            ("Suchen", "magnifyingglass", { store.find() }),
            ("Statusleiste ein/aus", "rectangle.bottomthird.inset.filled", { store.settings.showStatusBar.toggle() }),
            ("Einstellungen", "gearshape", {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }),
        ]
        for (title, icon, action) in actions {
            items.append(PaletteItem(id: "a-\(title)", title: title, subtitle: "Aktion", icon: icon, color: nil, action: action))
        }
        for pct in [0, 10, 20, 30, 40, 50] {
            let isActive = Int(((1 - store.settings.opacity) * 100).rounded()) == pct
            items.append(PaletteItem(id: "o-\(pct)", title: "Transparenz: \(pct) %", subtitle: isActive ? "aktiv" : "Darstellung",
                                     icon: "circle.lefthalf.filled", color: nil) { [store] in
                store.settings.opacity = 1 - Double(pct) / 100
            })
        }
        items.append(PaletteItem(id: "o-blur", title: "Weichzeichnen ein/aus", subtitle: store.settings.blur ? "an" : "aus",
                                 icon: "drop", color: nil) { [store] in store.settings.blur.toggle() })
        for t in Theme.all {
            items.append(PaletteItem(id: "t-\(t.id)", title: "Theme: \(t.name)", subtitle: t.id == store.settings.themeID ? "aktiv" : "Darstellung",
                                     icon: "paintpalette", color: t.accentColor) { [store] in
                store.settings.themeID = t.id
            })
        }
        return items
    }

    private var items: [PaletteItem] {
        let words = query.lowercased().split(separator: " ").map(String.init)
        guard !words.isEmpty else { return allItems }
        return allItems.filter { item in
            let hay = (item.title + " " + item.subtitle).lowercased()
            return words.allSatisfy { hay.contains($0) }
        }
    }

    var body: some View {
        let list = items
        ZStack(alignment: .top) {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture { close() }

            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextField("Sitzung, Snippet oder Aktion …", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 17))
                        .focused($focused)
                        .onSubmit { if index < list.count { execute(list[index]) } }
                        .onKeyPress(.downArrow) { index = min(index + 1, max(list.count - 1, 0)); return .handled }
                        .onKeyPress(.upArrow) { index = max(index - 1, 0); return .handled }
                        .onExitCommand { close() }
                        .onChange(of: query) { _, _ in index = 0 }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                Divider()

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(list.enumerated()), id: \.element.id) { i, item in
                                row(item, selected: i == index)
                                    .id(i)
                                    .onTapGesture { execute(item) }
                                    .onHover { if $0 { index = i } }
                            }
                            if list.isEmpty {
                                Text("Nichts gefunden").foregroundStyle(.secondary).padding(20)
                            }
                        }
                        .padding(6)
                    }
                    .frame(maxHeight: 380)
                    .onChange(of: index) { _, new in proxy.scrollTo(new) }
                }
            }
            .frame(width: 580)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.1)))
            .shadow(color: .black.opacity(0.45), radius: 40, y: 18)
            .padding(.top, 60)
        }
        .onAppear { focused = true }
    }

    private func row(_ item: PaletteItem, selected: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(item.color ?? store.theme.accentColor)
                .frame(width: 26, height: 26)
                .background((item.color ?? store.theme.accentColor).opacity(0.15),
                            in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title).font(.system(size: 13, weight: .medium))
                Text(item.subtitle).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if selected { Image(systemName: "return").font(.system(size: 11)).foregroundStyle(.secondary) }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(selected ? store.theme.accentColor.opacity(0.22) : .clear,
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .contentShape(Rectangle())
    }

    private func execute(_ item: PaletteItem) {
        store.showPalette = false
        item.action()
        if store.renamingID == nil { store.focusTerminal() }
    }

    private func close() {
        store.showPalette = false
        store.focusTerminal()
    }
}
