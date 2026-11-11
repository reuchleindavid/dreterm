import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var store: Store
    @AppStorage("snippetsExpanded") private var snippetsExpanded = true

    var body: some View {
        let order = store.orderedSessions
        let pinned = order.filter(\.pinned)
        let normal = order.filter { !$0.pinned }

        List {
            if !pinned.isEmpty {
                Section("Angeheftet") {
                    ForEach(pinned) { s in
                        SessionRow(session: s, index: order.firstIndex(of: s) ?? 99)
                    }
                    .onMove { store.move(pinned: true, from: $0, to: $1) }
                }
            }
            Section("Sitzungen") {
                ForEach(normal) { s in
                    SessionRow(session: s, index: order.firstIndex(of: s) ?? 99)
                }
                .onMove { store.move(pinned: false, from: $0, to: $1) }
            }
            if !store.snippets.isEmpty {
                Section("Snippets", isExpanded: $snippetsExpanded) {
                    ForEach(store.snippets) { sn in
                        SnippetRow(snippet: sn)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(store.theme.bg.opacity(store.settings.opacity * (store.theme.isDark ? 0.82 : 0.45)))
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
    }

    private var footer: some View {
        HStack(spacing: 4) {
            Button { store.newSession() } label: {
                Label("Neue Sitzung", systemImage: "plus.circle.fill")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderless)
            Spacer()
            Button { store.showPalette = true } label: { Image(systemName: "command") }
                .buttonStyle(.borderless)
                .help("Befehlspalette (⌘P)")
            SettingsLink { Image(systemName: "gearshape") }
                .buttonStyle(.borderless)
                .help("Einstellungen (⌘,)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(store.theme.bg.opacity(0.6))
        .overlay(alignment: .top) { Rectangle().fill(store.theme.fg.opacity(0.08)).frame(height: 1) }
    }
}

struct SessionRow: View {
    @EnvironmentObject var store: Store
    let session: Session
    let index: Int
    @State private var draft = ""
    @FocusState private var focused: Bool

    private var rt: SessionRuntime { store.runtime[session.id] ?? SessionRuntime() }
    private var tint: Color { session.color == .none ? store.theme.accentColor : session.color.color }
    private var isRenaming: Bool { store.renamingID == session.id }
    private var isSelected: Bool { store.selectedID == session.id }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(tint.opacity(0.18))
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(tint.opacity(0.35), lineWidth: 0.5)
                Image(systemName: session.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                if isRenaming {
                    TextField("Name", text: $draft)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .semibold))
                        .focused($focused)
                        .onSubmit(commit)
                        .onExitCommand {
                            store.renamingID = nil
                            store.focusTerminal()
                        }
                        .onAppear {
                            draft = session.name
                            DispatchQueue.main.async { focused = true }
                        }
                        .onChange(of: focused) { _, now in if !now { commit() } }
                } else {
                    Text(session.name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                }
                subtitle
            }
            Spacer(minLength: 2)
            badge
            if index < 9 && !isRenaming {
                Text("⌘\(index + 1)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
        .onTapGesture { if store.selectedID != session.id { store.selectedID = session.id } }
        .simultaneousGesture(TapGesture(count: 2).onEnded { store.renamingID = session.id })
        .listRowBackground(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(isSelected ? tint.opacity(0.22) : .clear)
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(isSelected ? tint.opacity(0.35) : .clear, lineWidth: 0.5))
                .padding(.horizontal, 10)
                .padding(.vertical, 1)
        )
        .contextMenu { SessionMenu(id: session.id) }
    }

    @ViewBuilder private var subtitle: some View {
        Group {
            if rt.exited {
                Text("beendet")
            } else if !rt.isShellIdle {
                HStack(spacing: 4) {
                    Text(rt.process).foregroundStyle(tint)
                    Text("·")
                    Text(session.directory.abbreviatingHome).truncationMode(.head)
                }
            } else {
                Text(session.directory.abbreviatingHome).truncationMode(.head)
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }

    @ViewBuilder private var badge: some View {
        if rt.bell {
            Image(systemName: "bell.fill").font(.system(size: 10)).foregroundStyle(.yellow)
        } else if rt.finishedInBackground {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 12)).foregroundStyle(.green)
                .help("Befehl im Hintergrund fertig")
        } else if rt.hasActivity {
            Circle().fill(tint).frame(width: 7, height: 7)
                .help("Neue Ausgabe")
        }
    }

    private func commit() {
        guard store.renamingID == session.id else { return }
        let name = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { store.modify(session.id) { $0.name = name } }
        store.renamingID = nil
        store.focusTerminal()
    }
}

struct SessionMenu: View {
    @EnvironmentObject var store: Store
    let id: UUID

    var body: some View {
        if let s = store.binding(for: id) {
            Button("Umbenennen") {
                store.selectedID = id
                store.renamingID = id
            }
            Picker("Farbe", selection: s.color) {
                ForEach(TabColor.allCases) { c in
                    Label(c.label, systemImage: c == .none ? "circle.dashed" : "circle.fill")
                        .tint(c.color)
                        .tag(c)
                }
            }
            Picker("Symbol", selection: s.icon) {
                ForEach(SessionIcons.all, id: \.self) { name in
                    Label(name, systemImage: name).labelStyle(.iconOnly).tag(name)
                }
            }
            Toggle("Angeheftet", isOn: s.pinned)
            Divider()
            Button("Duplizieren") { store.duplicate(id) }
            Button("Im Finder zeigen") { store.revealInFinder(id) }
            Button("Pfad kopieren") { store.copyPath(id) }
            Divider()
            Button("Schließen", role: .destructive) { store.close(id) }
        }
    }
}

struct SnippetRow: View {
    @EnvironmentObject var store: Store
    let snippet: Snippet
    @State private var hover = false

    var body: some View {
        Button { store.run(snippet) } label: {
            HStack(spacing: 8) {
                Image(systemName: snippet.runImmediately ? "play.fill" : "text.insert")
                    .font(.system(size: 9))
                    .foregroundStyle(store.theme.accentColor)
                    .frame(width: 16)
                Text(snippet.name).font(.system(size: 12))
                Spacer()
                if hover {
                    Text(snippet.command)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help(snippet.command)
    }
}
