// Renders the 1024×1024 app icon PNG: Ankani's mark, 蟹 (kani, "crab"), on a violet rounded square.
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
NSColor(red: 0.63, green: 0.0, blue: 0.94, alpha: 1).setFill()
NSBezierPath(roundedRect: canvas.insetBy(dx: 100, dy: 100), xRadius: 185, yRadius: 185).fill()
let glyph = NSAttributedString(string: "蟹", attributes: [
    .font: NSFont.systemFont(ofSize: 500, weight: .bold),
    .foregroundColor: NSColor.white,
])
let glyphSize = glyph.size()
glyph.draw(at: NSPoint(x: (CGFloat(size) - glyphSize.width) / 2, y: (CGFloat(size) - glyphSize.height) / 2))
NSGraphicsContext.restoreGraphicsState()
try rep.representation(using: .png, properties: [:])!.write(to: output)
