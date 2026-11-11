import SwiftUI

enum TabColor: String, Codable, CaseIterable, Identifiable {
    case none, red, orange, yellow, green, mint, teal, blue, indigo, purple, pink, gray
    var id: String { rawValue }

    var color: Color {
        switch self {
        case .none: return .secondary
        case .red: return Color(red: 1.00, green: 0.38, blue: 0.40)
        case .orange: return Color(red: 1.00, green: 0.62, blue: 0.30)
        case .yellow: return Color(red: 0.98, green: 0.82, blue: 0.32)
        case .green: return Color(red: 0.40, green: 0.85, blue: 0.50)
        case .mint: return Color(red: 0.40, green: 0.90, blue: 0.80)
        case .teal: return Color(red: 0.30, green: 0.75, blue: 0.90)
        case .blue: return Color(red: 0.36, green: 0.58, blue: 1.00)
        case .indigo: return Color(red: 0.52, green: 0.48, blue: 1.00)
        case .purple: return Color(red: 0.75, green: 0.48, blue: 1.00)
        case .pink: return Color(red: 1.00, green: 0.45, blue: 0.75)
        case .gray: return Color(white: 0.6)
        }
    }

    var label: String {
        switch self {
        case .none: return "Keine"
        case .red: return "Rot"
        case .orange: return "Orange"
        case .yellow: return "Gelb"
        case .green: return "Grün"
        case .mint: return "Mint"
        case .teal: return "Türkis"
        case .blue: return "Blau"
        case .indigo: return "Indigo"
        case .purple: return "Lila"
        case .pink: return "Pink"
        case .gray: return "Grau"
        }
    }
}

/// Persistierte Daten einer Sitzung.
struct Session: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var color: TabColor = .none
    var icon: String = "terminal"
    var pinned = false
    var directory: String
    var notes: String = ""
    var createdAt = Date()
    /// Einmaliger Befehl, der beim ersten Start der Shell ausgeführt wird (z. B. `claude --resume <id>`).
    var startupCommand: String?
}

/// Live-Zustand einer Sitzung (nicht persistiert).
struct SessionRuntime: Equatable {
    var process: String = ""
    var isShellIdle = true
    var hasActivity = false
    var finishedInBackground = false
    var bell = false
    var exited = false
    var cols = 0
    var rows = 0
    var title = ""
}

struct Snippet: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var command: String
    var runImmediately = true
}

struct AppSettings: Codable, Equatable {
    var themeID = "dre-violett"
    var fontName = "SF Mono"
    var fontSize: Double = 13
    var opacity: Double = 0.94
    var shell = ""
    var newTabInCurrentDirectory = true
    var confirmCloseRunning = true
    var useMetal = false
    var showStatusBar = true
    var blur = true

    init() {}

    // Tolerant laden: fehlende Schlüssel (neue Einstellungen) nehmen den Standardwert,
    // damit ein Update nie die gespeicherten Sitzungen verwirft.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        themeID = try c.decodeIfPresent(String.self, forKey: .themeID) ?? d.themeID
        fontName = try c.decodeIfPresent(String.self, forKey: .fontName) ?? d.fontName
        fontSize = try c.decodeIfPresent(Double.self, forKey: .fontSize) ?? d.fontSize
        opacity = try c.decodeIfPresent(Double.self, forKey: .opacity) ?? d.opacity
        shell = try c.decodeIfPresent(String.self, forKey: .shell) ?? d.shell
        newTabInCurrentDirectory = try c.decodeIfPresent(Bool.self, forKey: .newTabInCurrentDirectory) ?? d.newTabInCurrentDirectory
        confirmCloseRunning = try c.decodeIfPresent(Bool.self, forKey: .confirmCloseRunning) ?? d.confirmCloseRunning
        useMetal = try c.decodeIfPresent(Bool.self, forKey: .useMetal) ?? d.useMetal
        showStatusBar = try c.decodeIfPresent(Bool.self, forKey: .showStatusBar) ?? d.showStatusBar
        blur = try c.decodeIfPresent(Bool.self, forKey: .blur) ?? d.blur
    }
}

struct PersistedState: Codable {
    var sessions: [Session]
    var selectedID: UUID?
    var snippets: [Snippet]
    var settings: AppSettings
}

enum SessionIcons {
    static let all = [
        "terminal", "chevron.left.forwardslash.chevron.right", "server.rack", "globe", "cart",
        "sparkles", "brain", "hammer", "wrench.and.screwdriver", "shippingbox", "doc.text",
        "folder", "network", "lock", "bolt", "flame", "leaf", "star", "music.note", "book",
        "cloud", "cpu", "gearshape", "person", "magnifyingglass", "chart.bar", "paintbrush", "bubble.left",
    ]
}

extension String {
    var abbreviatingHome: String {
        let home = NSHomeDirectory()
        if self == home { return "~" }
        if hasPrefix(home + "/") { return "~" + dropFirst(home.count) }
        return self
    }
}
