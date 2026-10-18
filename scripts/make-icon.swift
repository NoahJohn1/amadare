// Renders the 1024×1024 app icon PNG: Amadare's mark, 雫 (a drop), on rain-dark indigo glass with beads of water.
// Usage: swift scripts/make-icon.swift <output.png>
import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1])
let size = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let canvas = NSRect(x: 0, y: 0, width: size, height: size)
let tile = NSBezierPath(roundedRect: canvas.insetBy(dx: 100, dy: 100), xRadius: 185, yRadius: 185)

// Indigo (藍) at the top deepening to night-rain navy.
NSGradient(starting: NSColor(red: 0.20, green: 0.48, blue: 0.70, alpha: 1),
           ending: NSColor(red: 0.04, green: 0.10, blue: 0.17, alpha: 1))!.draw(in: tile, angle: -90)

let glyph = NSAttributedString(string: "雫", attributes: [
    .font: NSFont.systemFont(ofSize: 480, weight: .bold),
    .foregroundColor: NSColor.white,
])
let glyphSize = glyph.size()
glyph.draw(at: NSPoint(x: (CGFloat(size) - glyphSize.width) / 2, y: (CGFloat(size) - glyphSize.height) / 2 - 10))

// A few beads of water on the glass: shadow, body, highlight (AppKit's y axis points up).
NSGraphicsContext.current?.saveGraphicsState()
tile.addClip()
for (x, y, r) in [(250.0, 760.0, 26.0), (780.0, 690.0, 18.0), (705.0, 260.0, 30.0), (300.0, 300.0, 14.0), (830.0, 420.0, 11.0)] {
    NSColor(white: 0, alpha: 0.25).setFill()
    NSBezierPath(ovalIn: NSRect(x: x - r, y: y - r * 1.25, width: 2 * r, height: 2 * r)).fill()
    NSGradient(starting: NSColor(white: 1, alpha: 0.35), ending: NSColor(white: 1, alpha: 0.06))!
        .draw(in: NSBezierPath(ovalIn: NSRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)), angle: 90)
    NSColor(white: 1, alpha: 0.8).setFill()
    NSBezierPath(ovalIn: NSRect(x: x - r * 0.45, y: y + r * 0.3, width: r * 0.4, height: r * 0.3)).fill()
}
NSGraphicsContext.current?.restoreGraphicsState()
NSGraphicsContext.restoreGraphicsState()
try rep.representation(using: .png, properties: [:])!.write(to: output)
