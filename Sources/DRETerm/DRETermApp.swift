import AppKit
import SwiftUI

@main
struct DRETermApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var store = Store.shared

    var body: some Scene {
        Window("DRETerm", id: "main") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 720, minHeight: 420)
        }
        .defaultSize(width: 1180, height: 760)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands { AppCommands(store: store) }

        Settings {
            SettingsView().environmentObject(store)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        MainActor.assumeIsolated {
            let store = Store.shared
            let busy = store.sessions.filter { s in
                if let r = store.runtime[s.id] { return !r.isShellIdle && !r.exited }
                return false
            }
            guard store.settings.confirmCloseRunning, !busy.isEmpty else { return .terminateNow }
            let alert = NSAlert()
            alert.messageText = "DRETerm beenden?"
            alert.informativeText = "In \(busy.count == 1 ? "einer Sitzung läuft" : "\(busy.count) Sitzungen laufen") noch ein Prozess: "
                + busy.map { "\($0.name) (\(store.runtime[$0.id]?.process ?? ""))" }.joined(separator: ", ")
            alert.addButton(withTitle: "Beenden")
            alert.addButton(withTitle: "Abbrechen")
            alert.alertStyle = .warning
            return alert.runModal() == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
        }
    }
}

struct AppCommands: Commands {
    @ObservedObject var store: Store

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Neue Sitzung") { store.newSession() }
                .keyboardShortcut("t")
            Button("Neue Sitzung im Home-Ordner") { store.newSession(directory: NSHomeDirectory()) }
                .keyboardShortcut("n")
            Button("Sitzung duplizieren") { if let id = store.selectedID { store.duplicate(id) } }
                .keyboardShortcut("d", modifiers: [.command, .shift])
        }
        CommandGroup(replacing: .saveItem) {
            Button("Sitzung schließen") { store.close(store.selectedID) }
                .keyboardShortcut("w")
        }
        CommandGroup(replacing: .printItem) {}
        CommandGroup(after: .textEditing) {
            Divider()
            Button("Suchen …") { store.find() }
                .keyboardShortcut("f")
            Button("Bildschirm leeren") { store.clearScreen() }
                .keyboardShortcut("k")
        }
        CommandMenu("Sitzung") {
            Button("Befehlspalette") { store.showPalette.toggle() }
                .keyboardShortcut("p")
            Divider()
            Button("Umbenennen") { store.renamingID = store.selectedID }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            Button("Anheften / Lösen") { if let id = store.selectedID { store.modify(id) { $0.pinned.toggle() } } }
            Button("Notizen & Details") { store.showInspector.toggle() }
                .keyboardShortcut("i")
            Divider()
            Button("Vorherige Sitzung") { store.select(offset: -1) }
                .keyboardShortcut(.upArrow, modifiers: [.command, .option])
            Button("Nächste Sitzung") { store.select(offset: 1) }
                .keyboardShortcut(.downArrow, modifiers: [.command, .option])
            ForEach(1..<10) { i in
                Button("Sitzung \(i)") { store.select(index: i - 1) }
                    .keyboardShortcut(KeyEquivalent(Character("\(i)")))
            }
            Divider()
            Button("Im Finder zeigen") { store.revealInFinder(store.selectedID) }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            Button("Pfad kopieren") { store.copyPath(store.selectedID) }
                .keyboardShortcut("c", modifiers: [.command, .shift])
        }
        CommandGroup(after: .toolbar) {
            Button("Schrift größer") { store.changeFontSize(1) }
                .keyboardShortcut("+")
            Button("Schrift kleiner") { store.changeFontSize(-1) }
                .keyboardShortcut("-")
            Button("Standardgröße") { store.changeFontSize(0) }
                .keyboardShortcut("0")
            Divider()
            Button("Weniger transparent") { store.changeOpacity(0.05) }
                .keyboardShortcut("+", modifiers: [.command, .option])
            Button("Transparenter") { store.changeOpacity(-0.05) }
                .keyboardShortcut("-", modifiers: [.command, .option])
            Toggle("Hintergrund weichzeichnen", isOn: $store.settings.blur)
            Divider()
            Button("Statusleiste ein/aus") { store.settings.showStatusBar.toggle() }
            Menu("Theme") {
                ForEach(Theme.all) { t in
                    Button((t.id == store.settings.themeID ? "✓ " : "") + t.name) { store.settings.themeID = t.id }
                }
            }
            Divider()
        }
    }
}
