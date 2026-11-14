// Disegna l'icona dell'app (il macropad visto da sopra) in tutte le misure per iconutil
import AppKit

let out = CommandLine.arguments[1]
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

func draw(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px) / 1024
    // sfondo
    let bg = NSBezierPath(roundedRect: NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s), xRadius: 185 * s, yRadius: 185 * s)
    NSGradient(starting: NSColor(red: 0.97, green: 0.96, blue: 0.94, alpha: 1), ending: NSColor(red: 0.84, green: 0.83, blue: 0.81, alpha: 1))!.draw(in: bg, angle: -90)
    // corpo del macropad (72 x 105 mm)
    let k = 6.2 * s, ox = 512 * s - 36 * k, oy = 512 * s - 52.5 * k
    func r(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> NSRect { NSRect(x: ox + x * k, y: oy + y * k, width: w * k, height: h * k) }
    let shadow = NSShadow()
    shadow.shadowColor = NSColor(white: 0, alpha: 0.35)
    shadow.shadowBlurRadius = 24 * s
    shadow.shadowOffset = NSSize(width: 0, height: -10 * s)
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    NSColor(red: 0.12, green: 0.12, blue: 0.13, alpha: 1).setFill()
    NSBezierPath(roundedRect: r(0, 0, 72, 105), xRadius: 9 * k, yRadius: 9 * k).fill()
    NSGraphicsContext.restoreGraphicsState()
    // display
    NSColor.black.setFill()
    NSBezierPath(roundedRect: r(13.4, 77.5, 25.2, 15), xRadius: 1.5 * k, yRadius: 1.5 * k).fill()
    NSColor(white: 1, alpha: 0.12).setStroke()
    NSBezierPath(roundedRect: r(13.4, 77.5, 25.2, 15), xRadius: 1.5 * k, yRadius: 1.5 * k).stroke()
    NSColor(red: 0.45, green: 0.75, blue: 1, alpha: 1).setFill()
    for i in 0..<3 { NSBezierPath(rect: r(15.5, 88.5 - Double(i) * 4, 13 - Double(i) * 3, 1.6)).fill() }
    // manopola
    NSColor(red: 0.96, green: 0.48, blue: 0.12, alpha: 1).setFill()
    NSBezierPath(ovalIn: r(48.5, 75.5, 17, 17)).fill()
    NSColor(red: 0.14, green: 0.08, blue: 0.03, alpha: 1).setFill()
    NSBezierPath(roundedRect: r(56.5, 86, 1.2, 4.5), xRadius: 0.6 * k, yRadius: 0.6 * k).fill()
    // tasti, uno evidenziato
    for i in 0..<9 {
        let x = 36 - 19.05 + Double(i % 3) * 19.05 - 8.5, y = 13 + Double(i / 3) * 19.05 - 8.5
        (i == 7 ? NSColor(red: 1.0, green: 0.62, blue: 0.30, alpha: 1) : NSColor(red: 0.96, green: 0.48, blue: 0.12, alpha: 1)).setFill()
        NSBezierPath(roundedRect: r(x, y, 17, 17), xRadius: 2 * k, yRadius: 2 * k).fill()
        NSColor(white: 1, alpha: 0.18).setStroke()
        let p = NSBezierPath(roundedRect: r(x, y, 17, 17), xRadius: 2 * k, yRadius: 2 * k); p.lineWidth = max(1, 0.3 * k); p.stroke()
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for size in [16, 32, 128, 256, 512] {
    try! draw(size).write(to: URL(fileURLWithPath: "\(out)/icon_\(size)x\(size).png"))
    try! draw(size * 2).write(to: URL(fileURLWithPath: "\(out)/icon_\(size)x\(size)@2x.png"))
}
