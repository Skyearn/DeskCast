import AppKit

private struct Variant {
    let name: String
    let artboardPadding: CGFloat
    let usesSubjectBounds: Bool
}

private let outputDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("Design/IconPreviews/MenuBar")

private let variants: [Variant] = [
    .init(name: "preview-current", artboardPadding: 0.02, usesSubjectBounds: false),
    .init(name: "preview-cropped-balanced", artboardPadding: 0.1, usesSubjectBounds: true),
    .init(name: "preview-cropped-large", artboardPadding: 0.05, usesSubjectBounds: true)
]

private let canvasSize = NSSize(width: 900, height: 220)
private let iconBox = NSRect(x: 84, y: 24, width: 74, height: 74)
private let darkBarRect = NSRect(x: 0, y: 0, width: canvasSize.width, height: canvasSize.height / 2)
private let lightBarRect = NSRect(x: 0, y: canvasSize.height / 2, width: canvasSize.width, height: canvasSize.height / 2)

private let subjectBounds = CGRect(x: 241, y: 262, width: 542, height: 499)
private let fullArtboard = CGRect(x: 0, y: 0, width: 1024, height: 1024)

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

for variant in variants {
    let image = NSImage(size: canvasSize)
    image.lockFocus()

    NSColor.clear.setFill()
    NSBezierPath(rect: NSRect(origin: .zero, size: canvasSize)).fill()

    drawBar(in: lightBarRect, dark: false)
    drawBar(in: darkBarRect, dark: true)

    let lightIconRect = iconBox.offsetBy(dx: 0, dy: lightBarRect.minY + 12)
    let darkIconRect = iconBox.offsetBy(dx: 0, dy: 12)

    drawTemplateIcon(in: lightIconRect, dark: false, variant: variant)
    drawTemplateIcon(in: darkIconRect, dark: true, variant: variant)

    drawLabel("浅色菜单栏", at: NSPoint(x: 186, y: lightBarRect.midY - 8), dark: true)
    drawLabel("深色菜单栏", at: NSPoint(x: 186, y: darkBarRect.midY - 8), dark: false)
    drawLabel(label(for: variant), at: NSPoint(x: 84, y: 18), dark: false)

    image.unlockFocus()

    guard
        let tiff = image.tiffRepresentation,
        let rep = NSBitmapImageRep(data: tiff),
        let png = rep.representation(using: .png, properties: [:])
    else {
        continue
    }

    let outputURL = outputDirectory.appendingPathComponent("\(variant.name).png")
    try png.write(to: outputURL)
    print("Wrote \(outputURL.path)")
}

private func label(for variant: Variant) -> String {
    switch variant.name {
    case "preview-current":
        return "当前实现"
    case "preview-cropped-balanced":
        return "裁掉留白 · 平衡版"
    default:
        return "裁掉留白 · 更大版"
    }
}

private func drawBar(in rect: NSRect, dark: Bool) {
    let gradient = NSGradient(
        colors: dark
            ? [NSColor(calibratedWhite: 0.11, alpha: 1), NSColor(calibratedWhite: 0.07, alpha: 1)]
            : [NSColor(calibratedRed: 0.64, green: 0.8, blue: 0.98, alpha: 1), NSColor(calibratedRed: 0.55, green: 0.74, blue: 0.95, alpha: 1)]
    )!
    gradient.draw(in: rect, angle: 0)
}

private func drawLabel(_ text: String, at point: NSPoint, dark: Bool) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 18, weight: .medium),
        .foregroundColor: dark ? NSColor.black.withAlphaComponent(0.75) : NSColor.white.withAlphaComponent(0.82)
    ]
    NSString(string: text).draw(at: point, withAttributes: attributes)
}

private func drawTemplateIcon(in rect: NSRect, dark: Bool, variant: Variant) {
    let color = dark ? NSColor.white : NSColor.white.withAlphaComponent(0.92)
    color.setFill()
    color.setStroke()

    let drawBounds = variant.usesSubjectBounds ? subjectBounds : fullArtboard
    let paddedBounds = drawBounds.insetBy(
        dx: -drawBounds.width * variant.artboardPadding,
        dy: -drawBounds.height * variant.artboardPadding
    )

    let scale = min(rect.width / paddedBounds.width, rect.height / paddedBounds.height)
    let offsetX = rect.midX - (paddedBounds.midX * scale)
    let offsetY = rect.midY - (paddedBounds.midY * scale)

    guard let context = NSGraphicsContext.current?.cgContext else {
        return
    }

    context.saveGState()
    context.translateBy(x: 0, y: rect.minY + rect.height)
    context.scaleBy(x: 1, y: -1)

    func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
        NSPoint(x: offsetX + x * scale, y: (offsetY - rect.minY) + y * scale)
    }

    func svgRect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> NSRect {
        NSRect(
            x: offsetX + x * scale,
            y: (offsetY - rect.minY) + y * scale,
            width: width * scale,
            height: height * scale
        )
    }

    let projectionPath = NSBezierPath()
    projectionPath.move(to: point(551, 336))
    projectionPath.line(to: point(783, 262))
    projectionPath.line(to: point(783, 654))
    projectionPath.line(to: point(551, 580))
    projectionPath.close()

    color.withAlphaComponent(0.18).setFill()
    projectionPath.fill()

    context.saveGState()
    projectionPath.addClip()
    let projectionGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            color.withAlphaComponent(0.78).cgColor,
            color.withAlphaComponent(0.08).cgColor
        ] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(
        projectionGradient,
        start: CGPoint(x: point(549, 342).x, y: point(549, 342).y),
        end: CGPoint(x: point(771, 622).x, y: point(771, 622).y),
        options: []
    )
    context.restoreGState()

    let documentPath = NSBezierPath(
        roundedRect: svgRect(241, 325, 266, 266),
        xRadius: 74 * scale,
        yRadius: 74 * scale
    )
    documentPath.fill()

    let standPath = NSBezierPath()
    standPath.move(to: point(374, 601))
    standPath.line(to: point(374, 727))
    standPath.lineWidth = 30 * scale
    standPath.lineCapStyle = .round
    standPath.stroke()

    let basePath = NSBezierPath(
        roundedRect: svgRect(289, 723, 170, 38),
        xRadius: 19 * scale,
        yRadius: 19 * scale
    )
    basePath.fill()

    context.restoreGState()
}
