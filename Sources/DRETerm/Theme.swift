import AppKit
import SwiftUI
import SwiftTerm

struct Theme: Identifiable, Equatable {
    let id: String
    let name: String
    let isDark: Bool
    let background: String
    let foreground: String
    let cursor: String
    let selection: String
    let accent: String
    /// 16 ANSI-Farben: 0-7 normal, 8-15 hell
    let ansi: [String]

    var nsBackground: NSColor { NSColor(hex: background) }
    var nsForeground: NSColor { NSColor(hex: foreground) }
    var bg: SwiftUI.Color { SwiftUI.Color(nsColor: nsBackground) }
    var fg: SwiftUI.Color { SwiftUI.Color(nsColor: nsForeground) }
    var accentColor: SwiftUI.Color { SwiftUI.Color(nsColor: NSColor(hex: accent)) }

    var terminalColors: [SwiftTerm.Color] {
        ansi.map { hex in
            let c = NSColor(hex: hex).usingColorSpace(.sRGB) ?? .white
            return SwiftTerm.Color(red: UInt16(c.redComponent * 65535),
                                   green: UInt16(c.greenComponent * 65535),
                                   blue: UInt16(c.blueComponent * 65535))
        }
    }

    static let all: [Theme] = [
        // Abgeleitet von david-reuchlein.de (--bg, --primary, --accent, --gold, --success, --text)
        Theme(id: "dre-violett", name: "DRE Violett", isDark: true,
              background: "#0F0A1A", foreground: "#F4F0FF", cursor: "#C084FC", selection: "#2D1B69", accent: "#8B5CF6",
              ansi: ["#1E1433", "#FF6B8B", "#34D399", "#F5E663", "#8B9CFF", "#C084FC", "#67E8F9", "#BCB2DA",
                     "#8579A6", "#FF8FA8", "#6EE7B7", "#FAF089", "#A5B8FF", "#D8B4FE", "#A5F3FC", "#F4F0FF"]),
        Theme(id: "dre-night", name: "DRE Night", isDark: true,
              background: "#0E1016", foreground: "#D6DCE8", cursor: "#7AA2F7", selection: "#2A3350", accent: "#7AA2F7",
              ansi: ["#1B1E28", "#F7768E", "#9ECE6A", "#E0AF68", "#7AA2F7", "#BB9AF7", "#7DCFFF", "#C0CAF5",
                     "#414868", "#FF8FA3", "#B5E48C", "#F5C77E", "#99B8FF", "#CFB2FF", "#A4DEFF", "#E6EBFF"]),
        Theme(id: "graphit", name: "Graphit", isDark: true,
              background: "#1C1C1E", foreground: "#E5E5E7", cursor: "#E5E5E7", selection: "#3A3A3D", accent: "#0A84FF",
              ansi: ["#2C2C2E", "#FF453A", "#32D74B", "#FFD60A", "#0A84FF", "#BF5AF2", "#64D2FF", "#D1D1D6",
                     "#636366", "#FF6961", "#4CE36B", "#FFE066", "#409CFF", "#DA8FFF", "#8AE0FF", "#FFFFFF"]),
        Theme(id: "ozean", name: "Ozean", isDark: true,
              background: "#0B1C2A", foreground: "#CFE3F1", cursor: "#5EEAD4", selection: "#1D3A52", accent: "#5EEAD4",
              ansi: ["#12293B", "#F87171", "#4ADE80", "#FACC15", "#60A5FA", "#C084FC", "#5EEAD4", "#CBD5E1",
                     "#3B5872", "#FCA5A5", "#86EFAC", "#FDE68A", "#93C5FD", "#D8B4FE", "#99F6E4", "#F1F5F9"]),
        Theme(id: "glut", name: "Glut", isDark: true,
              background: "#17120F", foreground: "#EEDFD0", cursor: "#FF9E64", selection: "#3A2A20", accent: "#FF9E64",
              ansi: ["#2A211B", "#EF6B5B", "#A9C46C", "#F2B866", "#7FA6C9", "#C895B8", "#7CC2B4", "#D9C8B4",
                     "#5A4A3E", "#FF8A7A", "#C3DD85", "#FFD08A", "#9DC0E0", "#E0B0D2", "#9ADBCC", "#FFF4E6"]),
        Theme(id: "papier", name: "Papier (hell)", isDark: false,
              background: "#FAF8F4", foreground: "#2B2A28", cursor: "#2563EB", selection: "#D9E4FB", accent: "#2563EB",
              ansi: ["#2B2A28", "#C9302C", "#3D8B37", "#B07D00", "#2563EB", "#8E44AD", "#0E8A8A", "#6B6B6B",
                     "#8A8782", "#E04B47", "#4FA448", "#CC9500", "#4A80F0", "#A85CC8", "#16A5A5", "#3A3936"]),
    ]

    static func byID(_ id: String) -> Theme { all.first { $0.id == id } ?? all[0] }
}

extension NSColor {
    convenience init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        self.init(srgbRed: CGFloat((v >> 16) & 0xFF) / 255,
                  green: CGFloat((v >> 8) & 0xFF) / 255,
                  blue: CGFloat(v & 0xFF) / 255,
                  alpha: 1)
    }
}
