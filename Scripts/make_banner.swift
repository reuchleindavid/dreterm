// README-Banner: Verlauf über die volle Breite, Logo freigestellt in der Mitte.
// Aufruf: swift Scripts/make_banner.swift Resources/dre-logo.png docs/banner.png
import AppKit

func rgbaRep(_ w: Int, _ h: Int) -> NSBitmapImageRep {
    NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8, samplesPerPixel: 4,
                     hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: w * 4, bitsPerPixel: 32)!
}

// Quelle in ein einfaches RGBA-Bitmap umzeichnen (Original kann indiziert sein)
let srcImg = NSImage(contentsOfFile: CommandLine.arguments[1])!
let srcCG = srcImg.cgImage(forProposedRect: nil, context: nil, hints: nil)!
let W = srcCG.width, H = srcCG.height
let srcRep = rgbaRep(W, H)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: srcRep)
NSGraphicsContext.current!.cgContext.draw(srcCG, in: CGRect(x: 0, y: 0, width: W, height: H))
NSGraphicsContext.restoreGraphicsState()
let sp = srcRep.bitmapData!

// y = 0 ist oben
func px(_ x: Int, _ y: Int) -> (Double, Double, Double) {
    let i = (y * W + x) * 4
    return (Double(sp[i]) / 255, Double(sp[i + 1]) / 255, Double(sp[i + 2]) / 255)
}

// Hintergrund je Spalte = oberste Zeile (das Logo berührt den Rand nicht)
let bgCol = (0..<W).map { px($0, 2) }

// Logo freistellen
var minX = W, minY = H, maxX = 0, maxY = 0
var fg = [[(Double, Double, Double, Double)]](repeating: [(Double, Double, Double, Double)](repeating: (0, 0, 0, 0), count: W), count: H)
for y in 0..<H {
    for x in 0..<W {
        let p = px(x, y), b = bgCol[x]
        let d = max(abs(p.0 - b.0), abs(p.1 - b.1), abs(p.2 - b.2))
        let a = min(1, max(0, (d - 0.03) / 0.30))
        if a > 0.02 {
            minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
            let f = { (pc: Double, bc: Double) in min(1, max(0, bc + (pc - bc) / a)) }
            fg[y][x] = (f(p.0, b.0), f(p.1, b.1), f(p.2, b.2), a)
        }
    }
}
let lw = maxX - minX + 1, lh = maxY - minY + 1
let logo = rgbaRep(lw, lh)
let lp = logo.bitmapData!
for y in 0..<lh {
    for x in 0..<lw {
        let v = fg[y + minY][x + minX]
        let i = (y * lw + x) * 4 // vormultipliziertes Alpha
        lp[i] = UInt8(v.0 * v.3 * 255); lp[i + 1] = UInt8(v.1 * v.3 * 255); lp[i + 2] = UInt8(v.2 * v.3 * 255); lp[i + 3] = UInt8(v.3 * 255)
    }
}
let logoImg = NSImage(size: NSSize(width: lw, height: lh)); logoImg.addRepresentation(logo)

// Banner
let BW = 2400, BH = 600
let rep = rgbaRep(BW, BH)
NSGraphicsContext.saveGraphicsState()
let ctx = NSGraphicsContext(bitmapImageRep: rep)!
ctx.imageInterpolation = .high
NSGraphicsContext.current = ctx
let l = bgCol[0], r = bgCol[W - 1]
NSGradient(starting: NSColor(srgbRed: l.0, green: l.1, blue: l.2, alpha: 1),
           ending: NSColor(srgbRed: r.0, green: r.1, blue: r.2, alpha: 1))!
    .draw(in: NSRect(x: 0, y: 0, width: BW, height: BH), angle: 0)
let targetH = Double(BH) * 0.42
let targetW = targetH * Double(lw) / Double(lh)
logoImg.draw(in: NSRect(x: (Double(BW) - targetW) / 2, y: (Double(BH) - targetH) / 2, width: targetW, height: targetH),
             from: .zero, operation: .sourceOver, fraction: 1)
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
print("Logo \(lw)x\(lh) bei (\(minX),\(minY)) freigestellt")
