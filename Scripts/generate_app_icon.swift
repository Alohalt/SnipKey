import AppKit
import Foundation

struct IconRenderer {
    private let backgroundTop = NSColor(calibratedRed: 0.11, green: 0.25, blue: 0.57, alpha: 1)
    private let backgroundBottom = NSColor(calibratedRed: 0.09, green: 0.71, blue: 0.74, alpha: 1)
    private let accent = NSColor(calibratedRed: 0.05, green: 0.82, blue: 0.94, alpha: 1)
    private let keyTop = NSColor(calibratedWhite: 0.99, alpha: 1)
    private let keyBottom = NSColor(calibratedWhite: 0.90, alpha: 1)
    private let glyph = NSColor(calibratedRed: 0.10, green: 0.22, blue: 0.45, alpha: 1)

    func render(size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }

        let rect = CGRect(origin: .zero, size: CGSize(width: size, height: size))
        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)
        context.clear(rect)

        drawBackground(in: rect, context: context)
        drawKeycap(in: rect, context: context)
        drawGlyphs(in: rect)

        image.unlockFocus()
        return image
    }

    private func drawBackground(in rect: CGRect, context: CGContext) {
        let outer = NSBezierPath(roundedRect: rect.insetBy(dx: rect.width * 0.055, dy: rect.height * 0.055), xRadius: rect.width * 0.23, yRadius: rect.width * 0.23)

        context.saveGState()
        outer.addClip()

        NSGradient(colors: [backgroundTop, backgroundBottom])?.draw(in: outer, angle: -55)

        let glowRect = CGRect(x: rect.width * 0.40, y: rect.height * 0.50, width: rect.width * 0.52, height: rect.height * 0.42)
        let glowPath = NSBezierPath(ovalIn: glowRect)
        context.setBlendMode(.screen)
        NSColor.white.withAlphaComponent(0.12).setFill()
        glowPath.fill()

        let topSheen = NSBezierPath(roundedRect: CGRect(x: rect.width * 0.14, y: rect.height * 0.60, width: rect.width * 0.72, height: rect.height * 0.20), xRadius: rect.width * 0.10, yRadius: rect.width * 0.10)
        NSColor.white.withAlphaComponent(0.10).setFill()
        topSheen.fill()

        context.restoreGState()

        NSColor.white.withAlphaComponent(0.18).setStroke()
        outer.lineWidth = max(2, rect.width * 0.012)
        outer.stroke()
    }

    private func drawKeycap(in rect: CGRect, context: CGContext) {
        let keyRect = CGRect(x: rect.width * 0.20, y: rect.height * 0.20, width: rect.width * 0.60, height: rect.height * 0.60)
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
        shadow.shadowBlurRadius = rect.width * 0.045
        shadow.shadowOffset = NSSize(width: 0, height: -rect.height * 0.018)

        context.saveGState()
        shadow.set()

        let keycap = NSBezierPath(roundedRect: keyRect, xRadius: rect.width * 0.16, yRadius: rect.width * 0.16)
        NSGradient(colors: [keyTop, keyBottom])?.draw(in: keycap, angle: -90)

        context.restoreGState()

        NSColor.white.withAlphaComponent(0.75).setStroke()
        keycap.lineWidth = max(2, rect.width * 0.010)
        keycap.stroke()

        let innerRim = NSBezierPath(roundedRect: keyRect.insetBy(dx: rect.width * 0.018, dy: rect.height * 0.018), xRadius: rect.width * 0.13, yRadius: rect.width * 0.13)
        NSColor.black.withAlphaComponent(0.06).setStroke()
        innerRim.lineWidth = max(1, rect.width * 0.006)
        innerRim.stroke()
    }

    private func drawGlyphs(in rect: CGRect) {
        let keyRect = CGRect(x: rect.width * 0.20, y: rect.height * 0.20, width: rect.width * 0.60, height: rect.height * 0.60)

        let hashFont = NSFont.monospacedSystemFont(ofSize: rect.width * 0.34, weight: .bold)
        let hashText = NSAttributedString(
            string: "#",
            attributes: [
                .font: hashFont,
                .foregroundColor: glyph
            ]
        )

        let hashSize = hashText.size()
        let hashOrigin = CGPoint(
            x: keyRect.minX + keyRect.width * 0.18,
            y: keyRect.midY - hashSize.height * 0.50 + rect.height * 0.01
        )
        hashText.draw(at: hashOrigin)

        let cursorRect = CGRect(x: keyRect.maxX - keyRect.width * 0.26, y: keyRect.minY + keyRect.height * 0.25, width: rect.width * 0.07, height: keyRect.height * 0.50)
        let cursorPath = NSBezierPath(roundedRect: cursorRect, xRadius: rect.width * 0.03, yRadius: rect.width * 0.03)
        NSGradient(colors: [accent.withAlphaComponent(0.98), backgroundBottom])?.draw(in: cursorPath, angle: -90)

        let sparkPath = NSBezierPath()
        let sparkCenter = CGPoint(x: rect.width * 0.76, y: rect.height * 0.74)
        let sparkRadius = rect.width * 0.045
        sparkPath.move(to: CGPoint(x: sparkCenter.x, y: sparkCenter.y + sparkRadius))
        sparkPath.line(to: CGPoint(x: sparkCenter.x + sparkRadius * 0.34, y: sparkCenter.y + sparkRadius * 0.34))
        sparkPath.line(to: CGPoint(x: sparkCenter.x + sparkRadius, y: sparkCenter.y))
        sparkPath.line(to: CGPoint(x: sparkCenter.x + sparkRadius * 0.34, y: sparkCenter.y - sparkRadius * 0.34))
        sparkPath.line(to: CGPoint(x: sparkCenter.x, y: sparkCenter.y - sparkRadius))
        sparkPath.line(to: CGPoint(x: sparkCenter.x - sparkRadius * 0.34, y: sparkCenter.y - sparkRadius * 0.34))
        sparkPath.line(to: CGPoint(x: sparkCenter.x - sparkRadius, y: sparkCenter.y))
        sparkPath.line(to: CGPoint(x: sparkCenter.x - sparkRadius * 0.34, y: sparkCenter.y + sparkRadius * 0.34))
        sparkPath.close()
        NSColor.white.withAlphaComponent(0.90).setFill()
        sparkPath.fill()
    }
}

let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let outputURL = repoRoot.appendingPathComponent("Resources/AppIcon.icns")
let tempRoot = repoRoot.appendingPathComponent(".build/appicon")
let iconsetURL = tempRoot.appendingPathComponent("AppIcon.iconset")
let previewURL = tempRoot.appendingPathComponent("AppIcon-preview.png")

let variants: [(name: String, size: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

try? FileManager.default.removeItem(at: tempRoot)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let renderer = IconRenderer()
for variant in variants {
    let image = renderer.render(size: CGFloat(variant.size))
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "AppIconGenerator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to render \(variant.name)"])
    }

    let fileURL = iconsetURL.appendingPathComponent(variant.name)
    try png.write(to: fileURL)

    if variant.size == 1024 {
        try png.write(to: previewURL)
    }
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconsetURL.path, "-o", outputURL.path]
try iconutil.run()
iconutil.waitUntilExit()

guard iconutil.terminationStatus == 0 else {
    throw NSError(domain: "AppIconGenerator", code: Int(iconutil.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "iconutil failed with status \(iconutil.terminationStatus)"])
}

print("Generated \(outputURL.path)")
print("Preview available at \(previewURL.path)")