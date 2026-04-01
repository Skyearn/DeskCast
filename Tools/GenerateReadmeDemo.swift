import AppKit
import Foundation

let fileManager = FileManager.default
let root = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let outputDirectory = root.appendingPathComponent("Design/Readme", isDirectory: true)
let framesDirectory = outputDirectory.appendingPathComponent("frames", isDirectory: true)
let sourcePanelURL = outputDirectory.appendingPathComponent("source-panel.png")

guard let sourcePanelImage = NSImage(contentsOf: sourcePanelURL) else {
    fatalError("Missing panel source image at \(sourcePanelURL.path)")
}

let sourcePanelAspectRatio: CGFloat = {
    if let bitmap = NSBitmapImageRep(data: sourcePanelImage.tiffRepresentation ?? Data()), bitmap.pixelsWide > 0 {
        return CGFloat(bitmap.pixelsHigh) / CGFloat(bitmap.pixelsWide)
    }
    let size = sourcePanelImage.size
    return size.width > 0 ? size.height / size.width : 1
}()

try fileManager.createDirectory(at: framesDirectory, withIntermediateDirectories: true)

let panelWidth: CGFloat = 388
let panelHeight: CGFloat = round(panelWidth * sourcePanelAspectRatio)
let canvasSize = CGSize(width: 1280, height: max(1040, panelHeight + 78))
let frameCount = 32

for frameIndex in 0..<frameCount {
    let progress = CGFloat(frameIndex) / CGFloat(frameCount - 1)
    try renderFrame(index: frameIndex, progress: progress)
}

func renderFrame(index: Int, progress: CGFloat) throws {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(canvasSize.width),
        pixelsHigh: Int(canvasSize.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = canvasSize

    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = context

    let rect = CGRect(origin: .zero, size: canvasSize)
    drawFrame(in: rect, progress: progress)

    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    let url = framesDirectory.appendingPathComponent(String(format: "frame_%03d.png", index))
    let data = rep.representation(using: .png, properties: [:])!
    try data.write(to: url)
}

func drawFrame(in rect: CGRect, progress: CGFloat) {
    let eased = easeInOut(progress)
    let projectionScale = lerp(0.86, 1.03, eased)
    let projectionAlpha = lerp(0.28, 0.78, eased)
    let panelOffset = lerp(40, 0, eased)
    let panelAlpha = lerp(0.0, 1.0, min(1, max(0, (progress - 0.08) / 0.92)))
    let glowAlpha = lerp(0.06, 0.16, eased)

    drawWallpaper(in: rect)
    let panelRect = CGRect(x: 832, y: 18 + panelOffset, width: panelWidth, height: panelHeight)
    drawMenuBar(in: rect, alignedTo: panelRect, alpha: panelAlpha)

    let projectionRect = CGRect(x: 74, y: 186, width: 700, height: 392)
    drawProjection(
        in: projectionRect,
        scale: projectionScale,
        opacity: projectionAlpha,
        glowAlpha: glowAlpha
    )

    drawPanelScreenshot(in: panelRect, alpha: panelAlpha)

    let caption = "多文档桌面投影 · 菜单栏控制 · 多屏幕布局"
    drawText(
        caption,
        in: CGRect(x: 74, y: 94, width: 680, height: 28),
        font: .systemFont(ofSize: 22, weight: .semibold),
        color: NSColor.white.withAlphaComponent(0.92)
    )
}

func drawWallpaper(in rect: CGRect) {
    let colors = [
        NSColor(calibratedRed: 0.12, green: 0.20, blue: 0.31, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.20, green: 0.28, blue: 0.39, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.07, green: 0.11, blue: 0.17, alpha: 1).cgColor
    ] as CFArray
    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: colors,
        locations: [0, 0.58, 1]
    )!
    let context = NSGraphicsContext.current!.cgContext
    context.saveGState()
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: rect.minX, y: rect.maxY),
        end: CGPoint(x: rect.maxX, y: rect.minY),
        options: []
    )
    context.restoreGState()

    let mountain = NSBezierPath()
    mountain.move(to: CGPoint(x: 0, y: 210))
    mountain.curve(
        to: CGPoint(x: 290, y: 318),
        controlPoint1: CGPoint(x: 70, y: 250),
        controlPoint2: CGPoint(x: 180, y: 332)
    )
    mountain.curve(
        to: CGPoint(x: 620, y: 246),
        controlPoint1: CGPoint(x: 402, y: 314),
        controlPoint2: CGPoint(x: 516, y: 214)
    )
    mountain.curve(
        to: CGPoint(x: 920, y: 332),
        controlPoint1: CGPoint(x: 726, y: 286),
        controlPoint2: CGPoint(x: 804, y: 354)
    )
    mountain.curve(
        to: CGPoint(x: 1280, y: 226),
        controlPoint1: CGPoint(x: 1030, y: 300),
        controlPoint2: CGPoint(x: 1160, y: 194)
    )
    mountain.line(to: CGPoint(x: 1280, y: 0))
    mountain.line(to: CGPoint(x: 0, y: 0))
    mountain.close()
    NSColor(calibratedWhite: 0.05, alpha: 0.34).setFill()
    mountain.fill()
}

func drawMenuBar(in rect: CGRect, alignedTo panelRect: CGRect, alpha: CGFloat) {
    let barRect = CGRect(x: 0, y: rect.height - 44, width: rect.width, height: 44)
    let barPath = NSBezierPath(rect: barRect)
    NSColor(calibratedWhite: 0.95, alpha: 0.18).setFill()
    barPath.fill()

    let iconRect = CGRect(x: panelRect.minX + 4, y: rect.height - 33, width: 20, height: 20)
    drawMiniDeskCastIcon(in: iconRect, alpha: alpha)
}

func drawProjection(in rect: CGRect, scale: CGFloat, opacity: CGFloat, glowAlpha: CGFloat) {
    let context = NSGraphicsContext.current!.cgContext
    let scaledRect = rect.applying(
        CGAffineTransform(translationX: rect.midX, y: rect.midY)
            .scaledBy(x: scale, y: scale)
            .translatedBy(x: -rect.midX, y: -rect.midY)
    )

    let glowRect = scaledRect.insetBy(dx: -20, dy: -20)
    let glowPath = NSBezierPath(roundedRect: glowRect, xRadius: 34, yRadius: 34)
    NSColor(calibratedRed: 0.54, green: 0.76, blue: 1, alpha: glowAlpha).setFill()
    glowPath.fill()

    let shadow = NSShadow()
    shadow.shadowBlurRadius = 26
    shadow.shadowOffset = NSSize(width: 0, height: -8)
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
    shadow.set()

    let projectionPath = NSBezierPath(roundedRect: scaledRect, xRadius: 28, yRadius: 28)
    NSColor.white.withAlphaComponent(opacity).setFill()
    projectionPath.fill()
    NSShadow().set()

    let headerRect = CGRect(x: scaledRect.minX + 26, y: scaledRect.maxY - 62, width: scaledRect.width - 52, height: 34)
    drawText(
        "4月试排 V5.xlsx",
        in: headerRect,
        font: .systemFont(ofSize: 24, weight: .bold),
        color: NSColor(calibratedWhite: 0.08, alpha: min(1, opacity + 0.14))
    )

    let subtitle = "已投影到 U2790B · 1440 × 2560"
    drawText(
        subtitle,
        in: CGRect(x: scaledRect.minX + 26, y: scaledRect.maxY - 92, width: 320, height: 20),
        font: .systemFont(ofSize: 13, weight: .medium),
        color: NSColor(calibratedWhite: 0.34, alpha: min(1, opacity + 0.1))
    )

    let rows = 5
    let columns = 7
    let gridRect = CGRect(x: scaledRect.minX + 26, y: scaledRect.minY + 26, width: scaledRect.width - 52, height: scaledRect.height - 138)
    let cellWidth = gridRect.width / CGFloat(columns)
    let cellHeight = gridRect.height / CGFloat(rows)

    for row in 0..<rows {
        for column in 0..<columns {
            let cell = CGRect(
                x: gridRect.minX + CGFloat(column) * cellWidth + 3,
                y: gridRect.maxY - CGFloat(row + 1) * cellHeight + 3,
                width: cellWidth - 6,
                height: cellHeight - 6
            )
            let path = NSBezierPath(roundedRect: cell, xRadius: 10, yRadius: 10)
            let highlight = (row == 1 && column == 3) || (row == 2 && column == 4)
            let fill = highlight
                ? NSColor(calibratedRed: 1.0, green: 0.89, blue: 0.49, alpha: opacity * 0.86)
                : NSColor(calibratedWhite: 1, alpha: opacity * 0.38)
            fill.setFill()
            path.fill()
        }
    }

    context.saveGState()
    let beamPath = NSBezierPath()
    beamPath.move(to: CGPoint(x: scaledRect.midX + 30, y: scaledRect.maxY - 16))
    beamPath.line(to: CGPoint(x: scaledRect.midX + 190, y: scaledRect.maxY + 70))
    beamPath.line(to: CGPoint(x: scaledRect.midX + 320, y: scaledRect.maxY + 26))
    beamPath.line(to: CGPoint(x: scaledRect.midX + 132, y: scaledRect.maxY - 44))
    beamPath.close()
    beamPath.addClip()
    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            NSColor.white.withAlphaComponent(0.24).cgColor,
            NSColor(calibratedRed: 0.45, green: 0.78, blue: 1, alpha: 0.02).cgColor
        ] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: scaledRect.midX + 40, y: scaledRect.maxY - 12),
        end: CGPoint(x: scaledRect.midX + 280, y: scaledRect.maxY + 64),
        options: []
    )
    context.restoreGState()
}

func drawPanelScreenshot(in rect: CGRect, alpha: CGFloat) {
    let context = NSGraphicsContext.current!.cgContext
    let shadow = NSShadow()
    shadow.shadowBlurRadius = 30
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.shadowColor = NSColor(calibratedWhite: 0.55, alpha: 0.18 * alpha)
    shadow.set()

    let panelPath = NSBezierPath(roundedRect: rect, xRadius: 26, yRadius: 26)
    context.saveGState()
    panelPath.addClip()
    sourcePanelImage.draw(in: rect, from: .zero, operation: .sourceOver, fraction: alpha)
    context.restoreGState()
    NSShadow().set()

    NSColor.white.withAlphaComponent(0.16 * alpha).setStroke()
    panelPath.lineWidth = 1
    panelPath.stroke()
}

func drawSlider(title: String, valueText: String, progress: CGFloat, in rect: CGRect, alpha: CGFloat) {
    drawText(
        title,
        in: CGRect(x: rect.minX, y: rect.maxY - 8, width: 120, height: 16),
        font: .systemFont(ofSize: 13, weight: .semibold),
        color: NSColor(calibratedWhite: 0.48, alpha: 0.94 * alpha)
    )
    drawText(
        valueText,
        in: CGRect(x: rect.maxX - 64, y: rect.maxY - 8, width: 64, height: 16),
        font: .monospacedDigitSystemFont(ofSize: 13, weight: .semibold),
        color: NSColor(calibratedWhite: 0.28, alpha: 0.96 * alpha)
    )

    let trackRect = CGRect(x: rect.minX, y: rect.minY + 10, width: rect.width - 82, height: 8)
    let track = NSBezierPath(roundedRect: trackRect, xRadius: 4, yRadius: 4)
    NSColor(calibratedWhite: 0.83, alpha: 0.92 * alpha).setFill()
    track.fill()

    let activeRect = CGRect(x: trackRect.minX, y: trackRect.minY, width: trackRect.width * progress, height: trackRect.height)
    let active = NSBezierPath(roundedRect: activeRect, xRadius: 4, yRadius: 4)
    NSColor(calibratedRed: 0.11, green: 0.49, blue: 0.97, alpha: alpha).setFill()
    active.fill()

    let tickColor = NSColor(calibratedWhite: 0.35, alpha: 0.58 * alpha)
    for offset in stride(from: 0.16 as CGFloat, through: 0.84 as CGFloat, by: 0.12) {
        let x = trackRect.minX + trackRect.width * offset
        let tick = NSBezierPath()
        tick.move(to: CGPoint(x: x, y: trackRect.minY - 2))
        tick.line(to: CGPoint(x: x, y: trackRect.maxY + 2))
        tick.lineWidth = 1.6
        tick.lineCapStyle = .round
        tickColor.setStroke()
        tick.stroke()
    }

    let knobX = trackRect.minX + trackRect.width * progress
    let knobRect = CGRect(x: knobX - 9, y: trackRect.midY - 9, width: 18, height: 18)
    let knob = NSBezierPath(ovalIn: knobRect)
    NSColor.white.withAlphaComponent(alpha).setFill()
    knob.fill()
    NSColor(calibratedWhite: 0.72, alpha: 0.8 * alpha).setStroke()
    knob.lineWidth = 1
    knob.stroke()
}

func drawMiniDeskCastIcon(in rect: CGRect, alpha: CGFloat) {
    let context = NSGraphicsContext.current!.cgContext
    context.saveGState()

    let documentRect = CGRect(x: rect.minX, y: rect.minY + 1, width: 9.5, height: 12.5)
    let document = NSBezierPath(roundedRect: documentRect, xRadius: 2.8, yRadius: 2.8)
    NSColor.white.withAlphaComponent(0.96 * alpha).setFill()
    document.fill()

    let stand = NSBezierPath()
    stand.move(to: CGPoint(x: rect.minX + 4.7, y: rect.minY + 1))
    stand.line(to: CGPoint(x: rect.minX + 4.7, y: rect.minY - 5))
    stand.lineWidth = 2.2
    stand.lineCapStyle = .round
    NSColor.white.withAlphaComponent(0.96 * alpha).setStroke()
    stand.stroke()

    let base = NSBezierPath(roundedRect: CGRect(x: rect.minX + 0.8, y: rect.minY - 6.3, width: 8, height: 2.6), xRadius: 1.3, yRadius: 1.3)
    NSColor.white.withAlphaComponent(0.96 * alpha).setFill()
    base.fill()

    let projection = NSBezierPath()
    projection.move(to: CGPoint(x: rect.minX + 12.4, y: rect.minY + 12.8))
    projection.line(to: CGPoint(x: rect.maxX, y: rect.minY + 15.8))
    projection.line(to: CGPoint(x: rect.maxX, y: rect.minY + 2.4))
    projection.line(to: CGPoint(x: rect.minX + 12.4, y: rect.minY + 5))
    projection.close()

    NSColor.white.withAlphaComponent(0.14 * alpha).setFill()
    projection.fill()

    context.saveGState()
    projection.addClip()
    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            NSColor.white.withAlphaComponent(0.84).cgColor,
            NSColor.white.withAlphaComponent(0.08 * alpha).cgColor
        ] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: rect.minX + 12.4, y: rect.minY + 12.6),
        end: CGPoint(x: rect.maxX - 0.4, y: rect.minY + 3.4),
        options: []
    )
    context.restoreGState()
    context.restoreGState()
}

func drawText(_ text: String, in rect: CGRect, font: NSFont, color: NSColor, centered: Bool = false) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = centered ? .center : .left
    paragraph.lineBreakMode = .byTruncatingTail

    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph
    ]
    NSString(string: text).draw(in: rect, withAttributes: attributes)
}

func drawImportIcon(in rect: CGRect, alpha: CGFloat) {
    let color = NSColor(calibratedRed: 0.11, green: 0.49, blue: 0.97, alpha: alpha)

    let body = NSBezierPath(roundedRect: CGRect(x: rect.minX, y: rect.minY, width: 22, height: 28), xRadius: 5, yRadius: 5)
    color.setStroke()
    body.lineWidth = 3
    body.stroke()

    let fold = NSBezierPath()
    fold.move(to: CGPoint(x: rect.minX + 12, y: rect.maxY))
    fold.line(to: CGPoint(x: rect.minX + 12, y: rect.maxY - 8))
    fold.line(to: CGPoint(x: rect.maxX - 2, y: rect.maxY - 8))
    fold.lineWidth = 3
    fold.lineCapStyle = .round
    fold.lineJoinStyle = .round
    fold.stroke()
}

func drawStatusDot(at point: CGPoint, color: NSColor) {
    let dot = NSBezierPath(ovalIn: CGRect(x: point.x, y: point.y, width: 8, height: 8))
    color.setFill()
    dot.fill()
}

func drawSoftButton(title: String, in rect: CGRect, alpha: CGFloat) {
    let button = NSBezierPath(roundedRect: rect, xRadius: 12, yRadius: 12)
    NSColor.white.withAlphaComponent(0.42 * alpha).setFill()
    button.fill()
    drawText(
        title,
        in: CGRect(x: rect.minX, y: rect.minY + 8, width: rect.width, height: 18),
        font: .systemFont(ofSize: 15, weight: .bold),
        color: NSColor(calibratedWhite: 0.34, alpha: 0.96 * alpha),
        centered: true
    )
}

func easeInOut(_ value: CGFloat) -> CGFloat {
    value * value * (3 - 2 * value)
}

func lerp(_ from: CGFloat, _ to: CGFloat, _ progress: CGFloat) -> CGFloat {
    from + (to - from) * progress
}
