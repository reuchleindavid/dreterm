import AppKit
import SwiftUI
import SwiftTerm

@MainActor
final class Store: NSObject, ObservableObject {
    static let shared = Store()

    @Published var sessions: [Session] = [] { didSet { scheduleSave() } }
    @Published var selectedID: UUID? { didSet { selectionChanged(from: oldValue) } }
    @Published var snippets: [Snippet] = [] { didSet { scheduleSave() } }
    @Published var settings = AppSettings() { didSet { settingsChanged(old: oldValue) } }
    @Published var runtime: [UUID: SessionRuntime] = [:]

    @Published var renamingID: UUID?
    @Published var showPalette = false
    @Published var showInspector = false

    private var views: [UUID: DRETerminalView] = [:]
    private var busySince: [UUID: Date] = [:]
    private var saveWork: DispatchWorkItem?
    private var pollTimer: Timer?
    weak var host: TerminalHostView?

    var theme: Theme { Theme.byID(settings.themeID) }
    var selected: Session? { sessions.first { $0.id == selectedID } }
    var selectedView: DRETerminalView? { selectedID.flatMap { views[$0] } }

    // MARK: Start / Persistenz

    private static var stateURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DRETerm", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("state.json")
    }

    override init() {
        super.init()
        if let data = try? Data(contentsOf: Self.stateURL),
           let state = try? JSONDecoder().decode(PersistedState.self, from: data) {
            settings = state.settings
            snippets = state.snippets
            sessions = state.sessions
            selectedID = state.selectedID ?? state.sessions.first?.id
        } else {
            snippets = [
                Snippet(name: "Claude Code", command: "claude"),
                Snippet(name: "Git Status", command: "git status"),
                Snippet(name: "Offene Ports", command: "lsof -iTCP -sTCP:LISTEN -P -n"),
                Snippet(name: "Ordnergrößen", command: "du -sh * | sort -h"),
            ]
        }
        if sessions.isEmpty {
            let s = Session(name: "Sitzung 1", directory: NSHomeDirectory())
            sessions = [s]
            selectedID = s.id
        }
        if selectedID == nil || !sessions.contains(where: { $0.id == selectedID }) {
            selectedID = sessions.first?.id
        }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.saveNow() }
        }
    }

    private func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.saveNow() }
        }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    func saveNow() {
        let state = PersistedState(sessions: sessions, selectedID: selectedID, snippets: snippets, settings: settings)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted]
        if let data = try? enc.encode(state) {
            try? data.write(to: Self.stateURL, options: .atomic)
        }
    }

    // MARK: Terminal-Views

    func terminalView(for id: UUID) -> DRETerminalView? {
        if let v = views[id] { return v }
        guard let session = sessions.first(where: { $0.id == id }) else { return nil }
        let v = DRETerminalView(sessionID: id)
        v.processDelegate = self
        v.optionAsMetaKey = false // deutsche Tastatur: ⌥ für @, [, ], | usw.
        apply(settings: settings, to: v)
        v.onActivity = { [weak self, weak v] in
            guard let self, let v else { return }
            self.markActivity(v)
        }
        v.onBell = { [weak self] in self?.update(id) { $0.bell = true } }
        views[id] = v
        start(v, in: session.directory)
        return v
    }

    private func start(_ v: DRETerminalView, in directory: String) {
        let shell = settings.shell.isEmpty ? ProcInfo.userShell : settings.shell
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["COLORTERM"] = "truecolor"
        env["TERM_PROGRAM"] = "DRETerm"
        env["TERM_PROGRAM_VERSION"] = "1.0"
        if env["LANG"] == nil { env["LANG"] = "de_DE.UTF-8" }
        env["LC_CTYPE"] = env["LC_CTYPE"] ?? "UTF-8"
        let envList = env.map { "\($0.key)=\($0.value)" }
        var isDir: ObjCBool = false
        let dir = FileManager.default.fileExists(atPath: directory, isDirectory: &isDir) && isDir.boolValue
            ? directory : NSHomeDirectory()
        v.startedAt = Date()
        v.startProcess(executable: shell, args: [], environment: envList,
                       execName: "-" + (shell as NSString).lastPathComponent, currentDirectory: dir)
        update(v.sessionID) { $0 = SessionRuntime() }
        if let i = sessions.firstIndex(where: { $0.id == v.sessionID }),
           let cmd = sessions[i].startupCommand, !cmd.isEmpty {
            sessions[i].startupCommand = nil // nur einmal
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak v] in
                v?.send(txt: cmd + "\r")
            }
        }
    }

    func apply(settings s: AppSettings, to v: DRETerminalView) {
        let t = Theme.byID(s.themeID)
        v.installColors(t.terminalColors)
        v.nativeForegroundColor = t.nsForeground
        v.nativeBackgroundColor = t.nsBackground
        v.caretColor = NSColor(hex: t.cursor)
        v.selectedTextBackgroundColor = NSColor(hex: t.selection)
        v.font = Self.font(named: s.fontName, size: s.fontSize)
        v.backgroundOpacity = 0 // Hintergrund malt der Host (Glas + Tönung)
        try? v.setUseMetal(s.useMetal)
    }

    static func font(named name: String, size: Double) -> NSFont {
        if name != "SF Mono", let f = NSFont(name: name, size: size) { return f }
        return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }

    private func settingsChanged(old: AppSettings) {
        scheduleSave()
        let visual = old.themeID != settings.themeID || old.fontName != settings.fontName
            || old.fontSize != settings.fontSize || old.useMetal != settings.useMetal
        if visual { views.values.forEach { apply(settings: settings, to: $0) } }
    }

    // MARK: Laufzeit-Status

    private func update(_ id: UUID, _ change: (inout SessionRuntime) -> Void) {
        var r = runtime[id] ?? SessionRuntime()
        let before = r
        change(&r)
        if r != before { runtime[id] = r }
    }

    private func markActivity(_ v: DRETerminalView) {
        guard v.sessionID != selectedID, Date().timeIntervalSince(v.startedAt) > 2 else { return }
        if runtime[v.sessionID]?.hasActivity != true {
            update(v.sessionID) { $0.hasActivity = true }
        }
    }

    private func poll() {
        for (id, v) in views {
            guard v.process.running else { continue }
            let shellPid = v.process.shellPid
            var dir: String?
            var procName = ""
            var idle = true
            if let fg = ProcInfo.foregroundGroup(fd: v.process.childfd), fg != shellPid {
                idle = false
                procName = ProcInfo.name(of: fg)
            }
            dir = ProcInfo.cwd(of: shellPid)

            let wasIdle = runtime[id]?.isShellIdle ?? true
            if wasIdle && !idle { busySince[id] = Date() }
            let finished = !wasIdle && idle && id != selectedID
                && Date().timeIntervalSince(busySince[id] ?? Date()) >= 5

            update(id) {
                $0.process = procName
                $0.isShellIdle = idle
                $0.cols = v.terminal.cols
                $0.rows = v.terminal.rows
                if finished { $0.finishedInBackground = true }
            }
            if let dir, let i = sessions.firstIndex(where: { $0.id == id }), sessions[i].directory != dir {
                sessions[i].directory = dir
            }
        }
    }

    private func selectionChanged(from old: UUID?) {
        guard old != selectedID else { return }
        scheduleSave()
        if let id = selectedID {
            update(id) { $0.hasActivity = false; $0.finishedInBackground = false; $0.bell = false }
        }
        if renamingID != nil && renamingID != selectedID { renamingID = nil }
        showSelected()
    }

    func showSelected() {
        guard let host else { return }
        host.show(selectedID.flatMap { terminalView(for: $0) })
        DispatchQueue.main.async { [weak self] in
            if self?.renamingID == nil && self?.showPalette == false { self?.host?.focus() }
        }
    }

    func focusTerminal() {
        DispatchQueue.main.async { [weak self] in self?.host?.focus() }
    }

    // MARK: Aktionen

    func newSession(directory: String? = nil, name: String? = nil, select: Bool = true) {
        let live = selectedView.flatMap { ProcInfo.cwd(of: $0.process.shellPid) }
        let dir = directory
            ?? (settings.newTabInCurrentDirectory ? (live ?? selected?.directory) : nil)
            ?? NSHomeDirectory()
        let s = Session(name: name ?? nextName(), directory: dir)
        if let sel = selectedID, let i = sessions.firstIndex(where: { $0.id == sel }), !sessions[i].pinned {
            sessions.insert(s, at: i + 1)
        } else {
            sessions.append(s)
        }
        if select { selectedID = s.id }
    }

    private func nextName() -> String {
        var n = sessions.count + 1
        while sessions.contains(where: { $0.name == "Sitzung \(n)" }) { n += 1 }
        return "Sitzung \(n)"
    }

    func duplicate(_ id: UUID) {
        guard let s = sessions.first(where: { $0.id == id }) else { return }
        newSession(directory: s.directory, name: s.name + " Kopie")
        if let new = selectedID, let i = sessions.firstIndex(where: { $0.id == new }) {
            sessions[i].color = s.color
            sessions[i].icon = s.icon
        }
    }

    func close(_ id: UUID?) {
        guard let id, let idx = sessions.firstIndex(where: { $0.id == id }) else { return }
        if settings.confirmCloseRunning, let r = runtime[id], !r.isShellIdle, !r.exited {
            let alert = NSAlert()
            alert.messageText = "„\(sessions[idx].name)“ schließen?"
            alert.informativeText = "In dieser Sitzung läuft noch „\(r.process)“. Der Prozess wird beendet."
            alert.addButton(withTitle: "Schließen")
            alert.addButton(withTitle: "Abbrechen")
            alert.alertStyle = .warning
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        if let v = views.removeValue(forKey: id) {
            v.processDelegate = nil
            v.onActivity = nil
            if v.process.running { v.terminate() }
            v.removeFromSuperview()
        }
        runtime[id] = nil
        busySince[id] = nil
        let wasSelected = selectedID == id
        sessions.remove(at: idx)
        if sessions.isEmpty {
            newSession(directory: NSHomeDirectory())
        } else if wasSelected {
            selectedID = sessions[min(idx, sessions.count - 1)].id
        }
    }

    func restart(_ id: UUID) {
        guard let v = views[id], let s = sessions.first(where: { $0.id == id }) else { return }
        v.terminal.resetToInitialState()
        start(v, in: s.directory)
        focusTerminal()
    }

    func select(offset: Int) {
        let order = orderedSessions
        guard !order.isEmpty else { return }
        let i = order.firstIndex { $0.id == selectedID } ?? 0
        selectedID = order[(i + offset + order.count) % order.count].id
    }

    func select(index: Int) {
        let order = orderedSessions
        guard index < order.count else { return }
        selectedID = order[index].id
    }

    /// Reihenfolge wie in der Sidebar: angeheftete zuerst.
    var orderedSessions: [Session] { sessions.filter(\.pinned) + sessions.filter { !$0.pinned } }

    func binding(for id: UUID) -> Binding<Session>? {
        guard sessions.contains(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { self.sessions.first { $0.id == id } ?? Session(name: "", directory: "") },
            set: { new in
                if let i = self.sessions.firstIndex(where: { $0.id == id }) { self.sessions[i] = new }
            })
    }

    func modify(_ id: UUID, _ change: (inout Session) -> Void) {
        guard let i = sessions.firstIndex(where: { $0.id == id }) else { return }
        change(&sessions[i])
    }

    func move(pinned: Bool, from: IndexSet, to: Int) {
        var group = sessions.filter { $0.pinned == pinned }
        group.move(fromOffsets: from, toOffset: to)
        let other = sessions.filter { $0.pinned != pinned }
        sessions = pinned ? group + other : other + group
    }

    func run(_ snippet: Snippet, in id: UUID? = nil) {
        guard let target = id ?? selectedID, let v = terminalView(for: target) else { return }
        if target != selectedID { selectedID = target }
        v.send(txt: snippet.command + (snippet.runImmediately ? "\r" : ""))
        focusTerminal()
    }

    func clearScreen() {
        guard let v = selectedView else { return }
        v.terminal.resetToInitialState()
        v.send(txt: "\u{0C}") // Ctrl-L: Shell zeichnet den Prompt neu
    }

    func find() {
        guard let v = selectedView else { return }
        let item = NSMenuItem()
        item.tag = NSTextFinder.Action.showFindInterface.rawValue
        v.performTextFinderAction(item)
    }

    func revealInFinder(_ id: UUID?) {
        guard let s = sessions.first(where: { $0.id == id }) else { return }
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: s.directory)
    }

    func copyPath(_ id: UUID?) {
        guard let s = sessions.first(where: { $0.id == id }) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s.directory, forType: .string)
    }

    /// Deckkraft in 5-%-Schritten, 30 % bis 100 %
    func changeOpacity(_ delta: Double) {
        let v = ((settings.opacity + delta) * 20).rounded() / 20
        settings.opacity = min(1, max(0.3, v))
    }

    func changeFontSize(_ delta: Double) {
        settings.fontSize = delta == 0 ? 13 : min(36, max(8, settings.fontSize + delta))
    }
}

extension Store: LocalProcessTerminalViewDelegate {
    nonisolated func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {
        MainActor.assumeIsolated {
            guard let v = source as? DRETerminalView else { return }
            update(v.sessionID) { $0.cols = newCols; $0.rows = newRows }
        }
    }

    nonisolated func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        MainActor.assumeIsolated {
            guard let v = source as? DRETerminalView else { return }
            update(v.sessionID) { $0.title = title }
        }
    }

    nonisolated func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

    nonisolated func processTerminated(source: TerminalView, exitCode: Int32?) {
        MainActor.assumeIsolated {
            guard let v = source as? DRETerminalView else { return }
            update(v.sessionID) { $0.exited = true; $0.isShellIdle = true; $0.process = "" }
        }
    }
}
