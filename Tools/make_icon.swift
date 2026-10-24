// Renders the app icon on the Mac in the app's own display face (the system font,
// black weight, condensed width — the style used for template names): white "SL"
// on a black macOS-style rounded square.
//
// Usage: swift Tools/make_icon.swift Assets/AppIcon.iconset
//        iconutil -c icns Assets/AppIcon.iconset -o Assets/AppIcon.icns
// (build.sh runs both.)
import AppKit

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Assets/AppIcon.iconset"
try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func render(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let s = CGFloat(pixels)
    let k = s / 1024                       // design is laid out on a 1024 grid

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high

    // macOS icon grid: 824-point body centred on the 1024 canvas.
    let body = NSBezierPath(roundedRect: NSRect(x: 100 * k, y: 100 * k, width: 824 * k, height: 824 * k),
                            xRadius: 185 * k, yRadius: 185 * k)
    NSColor.black.setFill()
    body.fill()
    NSColor(white: 0.25, alpha: 1).setStroke()
    body.lineWidth = max(1, 6 * k)
    body.stroke()

    let size = 560 * k
    let font = NSFont.systemFont(ofSize: size, weight: .black, width: .condensed)
    let text = NSAttributedString(string: "SL", attributes: [
        .font: font,
        .foregroundColor: NSColor.white,
        .kern: 4 * k,
    ])
    // Centre on the capitals rather than the line box.
    let width = text.size().width
    let baseline = (s - font.capHeight) / 2
    let x = (s - width) / 2
    text.draw(at: NSPoint(x: x, y: baseline + font.descender))

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

// Every size the .iconset format expects.
let entries: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, pixels) in entries {
    try render(pixels: pixels).write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
}
print("Wrote \(entries.count) icon images to \(outDir)")
