// Erzeugt das AppIcon aus Davids Plugin-Logo (Resources/dre-logo.png) im macOS-Format
import AppKit

let src = NSImage(contentsOfFile: CommandLine.arguments[1])!

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    ctx.imageInterpolation = .high
    NSGraphicsContext.current = ctx
    let s = CGFloat(px)
    let inset = s * 0.098
    let rect = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let path = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.225, yRadius: rect.width * 0.225)
    ctx.saveGraphicsState()
    let sh = NSShadow()
    sh.shadowColor = .black.withAlphaComponent(0.3)
    sh.shadowBlurRadius = s * 0.02
    sh.shadowOffset = NSSize(width: 0, height: -s * 0.01)
    sh.set()
    NSColor(srgbRed: 0.18, green: 0.12, blue: 0.3, alpha: 1).setFill()
    path.fill()
    ctx.restoreGraphicsState()
    ctx.saveGraphicsState()
    path.addClip()
    src.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
    ctx.restoreGraphicsState()
    NSColor.white.withAlphaComponent(0.12).setStroke()
    path.lineWidth = max(1, s * 0.004)
    path.stroke()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let out = CommandLine.arguments[2]
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
for (name, px) in [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128),
                   ("128x128@2x", 256), ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024)] {
    try! render(px).write(to: URL(fileURLWithPath: "\(out)/icon_\(name).png"))
}
