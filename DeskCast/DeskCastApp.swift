import AppKit
import SwiftUI

@main
struct DeskCastApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private var appDisplayName: String {
        Bundle.main.localizedInfoDictionary?["CFBundleDisplayName"] as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? "DeskCast"
    }

    private var menuBarIcon: NSImage {
        MenuBarIcon.makeTemplateImage(size: 19)
    }

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(appDelegate.state)
        } label: {
            Image(nsImage: menuBarIcon)
                .renderingMode(.template)
                .accessibilityLabel(Text(appDisplayName))
        }
        .menuBarExtraStyle(.window)

        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let state = ProjectionState()
    private var projectionController: DesktopProjectionWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        projectionController = DesktopProjectionWindowController(state: state)
    }
}

private enum MenuBarIcon {
    static func makeTemplateImage(size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            draw(in: rect)
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func draw(in rect: NSRect) {
        let size = min(rect.width, rect.height)
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.minY + size)
        context.scaleBy(x: 1, y: -1)

        let subjectBounds = CGRect(x: 241, y: 262, width: 542, height: 499)
        let paddedBounds = subjectBounds.insetBy(
            dx: -subjectBounds.width * 0.1,
            dy: -subjectBounds.height * 0.1
        )
        let scale = min(size / paddedBounds.width, size / paddedBounds.height)
        let offsetX = (size / 2) - (paddedBounds.midX * scale)
        let offsetY = (size / 2) - (paddedBounds.midY * scale)

        func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
            NSPoint(x: offsetX + x * scale, y: offsetY + y * scale)
        }

        func svgRect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> NSRect {
            NSRect(
                x: offsetX + x * scale,
                y: offsetY + y * scale,
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

        NSColor.labelColor.withAlphaComponent(0.18).setFill()
        projectionPath.fill()

        context.saveGState()
        projectionPath.addClip()
        let projectionGradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                NSColor.labelColor.withAlphaComponent(0.78).cgColor,
                NSColor.labelColor.withAlphaComponent(0.08).cgColor
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
        NSColor.labelColor.setFill()
        documentPath.fill()

        let standPath = NSBezierPath()
        standPath.move(to: point(374, 601))
        standPath.line(to: point(374, 727))
        NSColor.labelColor.setStroke()
        standPath.lineWidth = 30 * scale
        standPath.lineCapStyle = .round
        standPath.stroke()

        let basePath = NSBezierPath(
            roundedRect: svgRect(289, 723, 170, 38),
            xRadius: 19 * scale,
            yRadius: 19 * scale
        )
        NSColor.labelColor.setFill()
        basePath.fill()

        context.restoreGState()
    }
}
