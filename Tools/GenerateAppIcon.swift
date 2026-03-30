import AppKit
import Foundation

let fileManager = FileManager.default
let outputDirectory = URL(fileURLWithPath: fileManager.currentDirectoryPath)
    .appendingPathComponent("DeskCast/Assets.xcassets/AppIcon.appiconset", isDirectory: true)

let iconFiles: [(filename: String, size: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true, attributes: nil)

for icon in iconFiles {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: icon.size,
        pixelsHigh: icon.size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    rep.size = NSSize(width: icon.size, height: icon.size)

    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = context

    let canvas = NSRect(x: 0, y: 0, width: icon.size, height: icon.size)
    NSColor.clear.setFill()
    canvas.fill()

    drawIcon(in: canvas)

    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    let destination = outputDirectory.appendingPathComponent(icon.filename)
    if let pngData = rep.representation(using: .png, properties: [:]) {
        try pngData.write(to: destination)
    }
}

func drawIcon(in rect: NSRect) {
    let size = min(rect.width, rect.height)
    NSGraphicsContext.current?.saveGraphicsState()
    let context = NSGraphicsContext.current!.cgContext
    context.translateBy(x: rect.minX, y: rect.minY + size)
    context.scaleBy(x: 1, y: -1)

    let scale = size / 1024

    func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
        NSPoint(x: x * scale, y: y * scale)
    }

    func svgRect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> NSRect {
        NSRect(
            x: x * scale,
            y: y * scale,
            width: width * scale,
            height: height * scale
        )
    }

    let backgroundRect = svgRect(0, 0, 1024, 1024)
    let backgroundPath = NSBezierPath(
        roundedRect: backgroundRect,
        xRadius: 245 * scale,
        yRadius: 245 * scale
    )
    NSColor(calibratedRed: 0.06, green: 0.15, blue: 0.28, alpha: 1).setFill()
    backgroundPath.fill()

    let projectionPath = NSBezierPath()
    projectionPath.move(to: point(551, 336))
    projectionPath.line(to: point(783, 262))
    projectionPath.line(to: point(783, 654))
    projectionPath.line(to: point(551, 580))
    projectionPath.close()

    NSColor(calibratedRed: 0.43, green: 0.62, blue: 0.8, alpha: 0.18).setFill()
    projectionPath.fill()

    context.saveGState()
    projectionPath.addClip()
    let projectionColors = [
        NSColor(calibratedWhite: 1, alpha: 0.78).cgColor,
        NSColor(calibratedRed: 0.49, green: 0.83, blue: 0.99, alpha: 0.08).cgColor
    ] as CFArray
    let projectionGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: projectionColors,
        locations: [0, 1]
    )!
    context.drawLinearGradient(
        projectionGradient,
        start: CGPoint(x: 549 * scale, y: 342 * scale),
        end: CGPoint(x: 771 * scale, y: 622 * scale),
        options: []
    )
    context.restoreGState()

    let documentRect = svgRect(241, 325, 266, 266)
    let documentPath = NSBezierPath(
        roundedRect: documentRect,
        xRadius: 74 * scale,
        yRadius: 74 * scale
    )
    NSColor(calibratedRed: 0.97, green: 0.98, blue: 1, alpha: 1).setFill()
    documentPath.fill()

    let lineColor = NSColor(calibratedRed: 0.61, green: 0.75, blue: 1, alpha: 1)
    let firstLine = NSBezierPath(
        roundedRect: svgRect(303, 439, 156, 24),
        xRadius: 12 * scale,
        yRadius: 12 * scale
    )
    lineColor.setFill()
    firstLine.fill()

    let secondLine = NSBezierPath(
        roundedRect: svgRect(303, 493, 146, 24),
        xRadius: 12 * scale,
        yRadius: 12 * scale
    )
    secondLine.fill()

    let stand = NSBezierPath()
    stand.move(to: point(374, 601))
    stand.line(to: point(374, 727))
    NSColor(calibratedRed: 0.92, green: 0.96, blue: 1, alpha: 1).setStroke()
    stand.lineWidth = 30 * scale
    stand.lineCapStyle = .round
    stand.stroke()

    let base = NSBezierPath(
        roundedRect: svgRect(289, 723, 170, 38),
        xRadius: 19 * scale,
        yRadius: 19 * scale
    )
    NSColor(calibratedRed: 0.92, green: 0.96, blue: 1, alpha: 1).setFill()
    base.fill()

    NSGraphicsContext.current?.restoreGraphicsState()
}
