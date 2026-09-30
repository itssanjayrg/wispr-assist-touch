#!/usr/bin/env swift
// Generates Resources/AppIcon.icns: indigo rounded square with the Globe + Delete glyphs.
// Usage: swift scripts/make_icon.swift   (re-run only when the design changes; the .icns is committed)
import AppKit

func symbol(_ name: String, pointSize: CGFloat) -> NSImage {
    let cfg = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
    let base = NSImage(systemSymbolName: name, accessibilityDescription: nil)!.withSymbolConfiguration(cfg)!
    let out = NSImage(size: base.size)
    out.lockFocus()
    base.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1)
    NSColor.white.set()
    NSRect(origin: .zero, size: base.size).fill(using: .sourceIn)
    out.unlockFocus()
    return out
}

func render(pixels s: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: s, pixelsHigh: s, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let canvas = CGFloat(s)
    let side = canvas * 824 / 1024                      // macOS icon grid: 824pt artwork on 1024
    let r = NSRect(x: (canvas - side) / 2, y: (canvas - side) / 2, width: side, height: side)
    let path = NSBezierPath(roundedRect: r, xRadius: side * 0.225, yRadius: side * 0.225)

    NSGraphicsContext.current?.saveGraphicsState()
    path.addClip()
    NSGradient(starting: NSColor(red: 0.42, green: 0.40, blue: 0.98, alpha: 1),
               ending: NSColor(red: 0.20, green: 0.17, blue: 0.68, alpha: 1))!.draw(in: r, angle: -90)
    NSGradient(starting: NSColor(white: 1, alpha: 0.14), ending: NSColor(white: 1, alpha: 0))!
        .draw(in: NSRect(x: r.minX, y: r.midY, width: r.width, height: r.height / 2), angle: -90)
    NSGraphicsContext.current?.restoreGraphicsState()

    let glyphs = [symbol("globe", pointSize: side * 0.29), symbol("delete.left", pointSize: side * 0.29)]
    let gap = side * 0.07
    var x = r.midX - (glyphs.reduce(0) { $0 + $1.size.width } + gap) / 2
    for g in glyphs {
        g.draw(at: NSPoint(x: x, y: r.midY - g.size.height / 2), from: .zero, operation: .sourceOver, fraction: 1)
        x += g.size.width + gap
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let fm = FileManager.default
let root = URL(fileURLWithPath: fm.currentDirectoryPath)
let iconset = fm.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? fm.removeItem(at: iconset)
try fm.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try render(pixels: base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try render(pixels: base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
let out = root.appendingPathComponent("Resources/AppIcon.icns")
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", out.path]
try p.run(); p.waitUntilExit()
print(p.terminationStatus == 0 ? "Wrote \(out.path)" : "iconutil failed")
