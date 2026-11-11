import AppKit
import SwiftUI
import SwiftTerm

/// Terminal-View mit Hooks für Aktivität und Glocke.
final class DRETerminalView: LocalProcessTerminalView {
    let sessionID: UUID
    var onActivity: (() -> Void)?
    var onBell: (() -> Void)?
    var startedAt = Date()

    init(sessionID: UUID) {
        self.sessionID = sessionID
        super.init(frame: NSRect(x: 0, y: 0, width: 800, height: 500))
    }

    required init?(coder: NSCoder) { fatalError("not supported") }

    override func dataReceived(slice: ArraySlice<UInt8>) {
        super.dataReceived(slice: slice)
        onActivity?()
    }

    override func bell(source: Terminal) {
        super.bell(source: source)
        onBell?()
    }
}

/// Container für die aktive Terminal-View mit Innenabstand. Selbst transparent:
/// Glas und Tönung liegen dahinter (WindowGlass), damit Terminal und Statusleiste gleich aussehen.
final class TerminalHostView: NSView {
    private(set) var current: DRETerminalView?
    var inset = NSSize(width: 10, height: 8)

    func show(_ view: DRETerminalView?) {
        guard current !== view else { return }
        current?.removeFromSuperview()
        current = view
        guard let view else { return }
        view.autoresizingMask = [.width, .height]
        view.frame = bounds.insetBy(dx: inset.width, dy: inset.height)
        addSubview(view)
    }

    func focus() {
        guard let current, let window else { return }
        window.makeFirstResponder(current)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Echte Transparenz: Fenster selbst nicht deckend zeichnen
        window?.isOpaque = false
        window?.backgroundColor = .clear
    }

    override func layout() {
        super.layout()
        current?.frame = bounds.insetBy(dx: inset.width, dy: inset.height)
    }
}

/// Hintergrund des Terminal-Bereichs: optional weichgezeichnetes Glas + Theme-Farbe mit Deckkraft.
struct WindowGlass: NSViewRepresentable {
    var color: NSColor
    var opacity: Double
    var blur: Bool

    func makeNSView(context: Context) -> NSView {
        let root = NSView()
        let effect = NSVisualEffectView()
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.autoresizingMask = [.width, .height]
        root.addSubview(effect)
        let tint = NSView()
        tint.wantsLayer = true
        tint.autoresizingMask = [.width, .height]
        root.addSubview(tint)
        update(root)
        return root
    }

    func updateNSView(_ root: NSView, context: Context) { update(root) }

    private func update(_ root: NSView) {
        guard root.subviews.count == 2 else { return }
        root.subviews.forEach { $0.frame = root.bounds }
        root.subviews[0].isHidden = !blur || opacity >= 0.999
        root.subviews[1].layer?.backgroundColor = color.withAlphaComponent(opacity).cgColor
    }
}
