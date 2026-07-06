// Renders a 1024x1024 app icon PNG: white SF Symbol "link" on a blue rounded-rect.
// Usage: swift scripts/make-app-icon.swift <output.png>
import AppKit

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
let size: CGFloat = 1024

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

// Rounded-rect (squircle-ish) background with a vertical blue gradient.
let rect = NSRect(x: 0, y: 0, width: size, height: size)
let radius = size * 0.2237 // Big Sur icon corner ratio
let clip = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
clip.addClip()
let gradient = NSGradient(colors: [
    NSColor(srgbRed: 0.29, green: 0.56, blue: 0.99, alpha: 1),
    NSColor(srgbRed: 0.11, green: 0.35, blue: 0.90, alpha: 1),
])!
gradient.draw(in: rect, angle: -90)

// White "link" glyph, centered at ~46% of the canvas.
let config = NSImage.SymbolConfiguration(pointSize: size * 0.46, weight: .semibold)
    .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
if let symbol = NSImage(systemSymbolName: "link", accessibilityDescription: nil)?
    .withSymbolConfiguration(config) {
    let s = symbol.size
    let origin = NSPoint(x: (size - s.width) / 2, y: (size - s.height) / 2)
    symbol.draw(at: origin, from: .zero, operation: .sourceOver, fraction: 1)
}

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("Failed to render icon\n".utf8))
    exit(1)
}
try! png.write(to: URL(fileURLWithPath: outPath))
