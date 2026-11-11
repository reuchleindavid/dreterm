import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 210, ideal: 260, max: 400)
        } detail: {
            DetailView()
        }
        .inspector(isPresented: $store.showInspector) {
            InspectorView()
                .inspectorColumnWidth(min: 240, ideal: 290, max: 440)
        }
        .overlay {
            if store.showPalette { PaletteView() }
        }
        .navigationTitle(store.selected?.name ?? "DRETerm")
        .navigationSubtitle(store.selected.map { subtitle(for: $0) } ?? "")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { store.showPalette.toggle() } label: {
                    Label("Befehlspalette", systemImage: "command")
                }
                .help("Befehlspalette (⌘P)")
                Button { store.newSession() } label: {
                    Label("Neue Sitzung", systemImage: "plus")
                }
                .help("Neue Sitzung (⌘T)")
                Button { store.showInspector.toggle() } label: {
                    Label("Notizen", systemImage: "sidebar.right")
                }
                .help("Notizen & Details (⌘I)")
            }
        }
        .toolbarBackground(store.theme.bg.opacity(min(1, store.settings.opacity + 0.04)), for: .windowToolbar)
        .toolbarBackground(.visible, for: .windowToolbar)
        .tint(store.theme.accentColor)
        .preferredColorScheme(store.theme.isDark ? .dark : .light)
    }

    private func subtitle(for s: Session) -> String {
        let rt = store.runtime[s.id] ?? SessionRuntime()
        let dir = s.directory.abbreviatingHome
        return rt.isShellIdle ? dir : "\(rt.process) · \(dir)"
    }
}

struct DetailView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        VStack(spacing: 0) {
            TerminalContainer()
                .overlay(alignment: .bottom) {
                    if let id = store.selectedID, store.runtime[id]?.exited == true {
                        ExitedBanner(id: id)
                    }
                }
            if store.settings.showStatusBar { StatusBar() }
        }
        .background(WindowGlass(color: store.theme.nsBackground,
                                opacity: store.settings.opacity,
                                blur: store.settings.blur))
    }
}

struct TerminalContainer: NSViewRepresentable {
    @EnvironmentObject var store: Store

    func makeNSView(context: Context) -> TerminalHostView {
        let host = TerminalHostView(frame: .zero)
        store.host = host
        store.showSelected()
        return host
    }

    func updateNSView(_ host: TerminalHostView, context: Context) {}
}

struct ExitedBanner: View {
    @EnvironmentObject var store: Store
    let id: UUID

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "stop.circle.fill").foregroundStyle(.secondary)
            Text("Prozess beendet").fontWeight(.medium)
            Button("Neu starten") { store.restart(id) }
                .keyboardShortcut(.return, modifiers: [])
            Button("Schließen") { store.close(id) }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.08)))
        .shadow(color: .black.opacity(0.3), radius: 16, y: 6)
        .padding(.bottom, 18)
    }
}

struct StatusBar: View {
    @EnvironmentObject var store: Store

    var body: some View {
        let theme = store.theme
        let s = store.selected
        let rt = s.flatMap { store.runtime[$0.id] } ?? SessionRuntime()
        HStack(spacing: 16) {
            if rt.isShellIdle {
                Label((ProcInfo.userShell as NSString).lastPathComponent, systemImage: "terminal")
            } else {
                Label(rt.process, systemImage: "bolt.fill")
                    .foregroundStyle(theme.accentColor)
            }
            Label(s?.directory.abbreviatingHome ?? "", systemImage: "folder")
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            if rt.cols > 0 { Text("\(rt.cols)×\(rt.rows)") }
            Text(theme.name)
        }
        .font(.system(size: 11, design: .monospaced))
        .foregroundStyle(theme.fg.opacity(0.55))
        .labelStyle(StatusLabelStyle())
        .padding(.horizontal, 14)
        .frame(height: 24)
        .background(Color.black.opacity(theme.isDark ? 0.18 : 0.04))
        .overlay(alignment: .top) { Rectangle().fill(theme.fg.opacity(0.06)).frame(height: 1) }
    }
}

struct StatusLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon.imageScale(.small)
            configuration.title
        }
    }
}
