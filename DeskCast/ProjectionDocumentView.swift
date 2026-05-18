import PDFKit
import QuickLookUI
import SwiftUI

struct ProjectionDocumentView: NSViewRepresentable {
    let url: URL?

    nonisolated static func usesSpreadsheetQuickLookLayout(for url: URL) -> Bool {
        ["csv", "numbers", "tsv", "xls", "xlsm", "xlsx"].contains(url.pathExtension.lowercased())
    }

    func makeNSView(context: Context) -> DocumentPreviewHostView {
        DocumentPreviewHostView()
    }

    func updateNSView(_ nsView: DocumentPreviewHostView, context: Context) {
        nsView.update(url: url)
    }
}

final class DocumentPreviewHostView: NSView {
    private var embeddedView: NSView?
    private var currentURL: URL?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(url: URL?) {
        guard currentURL != url else { return }
        currentURL = url

        embeddedView?.removeFromSuperview()
        embeddedView = nil

        guard let url else { return }

        let previewView = makePreviewView(for: url)
        previewView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(previewView)
        NSLayoutConstraint.activate([
            previewView.leadingAnchor.constraint(equalTo: leadingAnchor),
            previewView.trailingAnchor.constraint(equalTo: trailingAnchor),
            previewView.topAnchor.constraint(equalTo: topAnchor),
            previewView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        embeddedView = previewView
    }

    private func makePreviewView(for url: URL) -> NSView {
        if url.pathExtension.lowercased() == "pdf", let pdfDocument = PDFDocument(url: url) {
            let pdfView = PDFView()
            pdfView.autoScales = true
            pdfView.displayMode = .singlePageContinuous
            pdfView.displaysPageBreaks = false
            pdfView.backgroundColor = .clear
            pdfView.document = pdfDocument
            return pdfView
        }

        if ProjectionDocumentView.usesSpreadsheetQuickLookLayout(for: url) {
            return FittingQuickLookPreviewView(url: url)
        }

        return makeQuickLookPreviewView(for: url)
    }

    private func makeQuickLookPreviewView(for url: URL) -> NSView {
        guard let quickLookView = QLPreviewView(frame: .zero, style: .normal) else {
            let fallbackLabel = NSTextField(labelWithString: "系统无法为这个文件创建 Quick Look 预览。")
            fallbackLabel.alignment = .center
            fallbackLabel.font = .systemFont(ofSize: 18, weight: .medium)
            fallbackLabel.textColor = .secondaryLabelColor
            return fallbackLabel
        }

        quickLookView.previewItem = url as NSURL
        quickLookView.autostarts = true
        return quickLookView
    }
}

extension Notification.Name {
    static let quickLookPreferredSizeDidChange = Notification.Name("quickLookPreferredSizeDidChange")
}

enum QuickLookPreferredHeightNotificationKey {
    static let url = "url"
    static let size = "size"
}

@MainActor
private final class FittingQuickLookPreviewView: NSView {
    private let url: URL
    private var quickLookView: QLPreviewView?
    private var reportedSize: CGSize?
    private var measuredContentSize: CGSize?
    private var measurementWorkItems: [DispatchWorkItem] = []
    private var renderWidth: CGFloat = 0

    init(url: URL) {
        self.url = url
        super.init(frame: .zero)

        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.masksToBounds = true

        guard let quickLookView = QLPreviewView(frame: .zero, style: .normal) else {
            let fallbackLabel = NSTextField(labelWithString: "系统无法为这个文件创建 Quick Look 预览。")
            fallbackLabel.alignment = .center
            fallbackLabel.font = .systemFont(ofSize: 18, weight: .medium)
            fallbackLabel.textColor = .secondaryLabelColor
            fallbackLabel.translatesAutoresizingMaskIntoConstraints = false
            addSubview(fallbackLabel)
            NSLayoutConstraint.activate([
                fallbackLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
                fallbackLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
                fallbackLabel.topAnchor.constraint(equalTo: topAnchor),
                fallbackLabel.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
            return
        }

        self.quickLookView = quickLookView
        quickLookView.previewItem = url as NSURL
        quickLookView.autostarts = true
        addSubview(quickLookView)
        scheduleMeasurements()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        updateQuickLookFrame()
        scheduleMeasurements()
    }

    private func updateQuickLookFrame() {
        guard let quickLookView else { return }
        renderWidth = max(renderWidth, bounds.width, measuredContentSize?.width ?? 0, Self.minimumMeasurementWidth)
        guard renderWidth > 0, bounds.height > 0 else { return }

        let naturalSize = measuredContentSize ?? CGSize(width: renderWidth, height: bounds.height)
        let scale = min(
            1,
            bounds.width / max(naturalSize.width, 1),
            bounds.height / max(naturalSize.height, 1)
        )
        let contentWidth = max(renderWidth, naturalSize.width)
        let contentHeight = max(naturalSize.height, bounds.height / max(scale, 0.01))

        quickLookView.wantsLayer = true
        quickLookView.layer?.anchorPoint = CGPoint(x: 0, y: 0)
        quickLookView.layer?.setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))
        quickLookView.frame = CGRect(x: 0, y: 0, width: contentWidth, height: contentHeight)
    }

    private static var minimumMeasurementWidth: CGFloat {
        max(1_000, NSScreen.screens.map(\.frame.width).max() ?? 0)
    }

    private func scheduleMeasurements() {
        measurementWorkItems.forEach { $0.cancel() }
        measurementWorkItems = [0.8, 1.8, 3.0].map { delay in
            let workItem = DispatchWorkItem { [weak self] in
                self?.measureAndReport()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
            return workItem
        }
    }

    private func measureAndReport() {
        updateQuickLookFrame()
        guard let quickLookView,
              bounds.width > 20, bounds.height > 20,
              let size = QuickLookContentMeasurer.preferredSize(for: quickLookView)
        else { return }

        let roundedSize = CGSize(width: ceil(size.width), height: ceil(size.height))
        measuredContentSize = roundedSize
        updateQuickLookFrame()

        if let reportedSize,
           abs(reportedSize.width - roundedSize.width) < 2,
           abs(reportedSize.height - roundedSize.height) < 2 {
            return
        }

        reportedSize = roundedSize
        NotificationCenter.default.post(
            name: .quickLookPreferredSizeDidChange,
            object: self,
            userInfo: [
                QuickLookPreferredHeightNotificationKey.url: url,
                QuickLookPreferredHeightNotificationKey.size: roundedSize
            ]
        )
    }
}

@MainActor
private enum QuickLookContentMeasurer {
    static func preferredSize(for view: NSView) -> CGSize? {
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
        view.cacheDisplay(in: view.bounds, to: bitmap)

        let width = bitmap.pixelsWide
        let height = bitmap.pixelsHigh
        guard width > 0, height > 0 else { return nil }

        let activeRows = activeRowRatios(in: bitmap, width: width, height: height)
        let threshold = max(0.003, 4 / Double(width))
        guard let firstActive = activeRows.firstIndex(where: { $0 > threshold }),
              let lastActive = activeRows.lastIndex(where: { $0 > threshold })
        else { return nil }

        let bottomClusterStart = findBottomClusterStart(in: activeRows, threshold: threshold, lastActive: lastActive)
        let contentBottom = findContentBottom(
            in: activeRows,
            threshold: threshold,
            firstActive: firstActive,
            before: bottomClusterStart
        )
        let contentWidth = findContentWidth(
            in: bitmap,
            width: width,
            from: firstActive,
            to: max(firstActive, contentBottom - 1)
        )

        let footerHeight = height - bottomClusterStart
        let fittedPixelHeight = min(height, contentBottom + footerHeight + 8)
        let scale = CGFloat(bitmap.pixelsHigh) / max(view.bounds.height, 1)
        return CGSize(
            width: CGFloat(min(width, contentWidth + 10)) / max(scale, 1),
            height: CGFloat(fittedPixelHeight) / max(scale, 1)
        )
    }

    private static func activeRowRatios(in bitmap: NSBitmapImageRep, width: Int, height: Int) -> [Double] {
        (0..<height).map { y in
            var activePixels = 0
            var x = 0
            while x < width {
                if let color = bitmap.colorAt(x: x, y: y), isActive(color) {
                    activePixels += 1
                }
                x += 3
            }
            return Double(activePixels * 3) / Double(width)
        }
    }

    private static func isActive(_ color: NSColor) -> Bool {
        guard let color = color.usingColorSpace(.deviceRGB),
              color.alphaComponent > 0.05
        else { return false }
        let red = color.redComponent
        let green = color.greenComponent
        let blue = color.blueComponent
        return red < 0.94 || green < 0.94 || blue < 0.94
    }

    private static func findBottomClusterStart(
        in rows: [Double],
        threshold: Double,
        lastActive: Int
    ) -> Int {
        var start = lastActive
        while start > 0 {
            let rangeStart = max(0, start - 8)
            let hasGap = rows[rangeStart...start].allSatisfy { $0 <= threshold }
            if hasGap {
                return min(lastActive, start + 1)
            }
            start -= 1
        }
        return lastActive
    }

    private static func findContentBottom(
        in rows: [Double],
        threshold: Double,
        firstActive: Int,
        before footerStart: Int
    ) -> Int {
        guard footerStart > firstActive else { return footerStart }
        var y = footerStart - 1
        while y > firstActive {
            if rows[y] > threshold {
                return y + 1
            }
            y -= 1
        }
        return footerStart
    }

    private static func findContentWidth(
        in bitmap: NSBitmapImageRep,
        width: Int,
        from firstRow: Int,
        to lastRow: Int
    ) -> Int {
        guard lastRow >= firstRow else { return width }

        var lastActiveColumn = 0
        var x = 0
        while x < width {
            var activePixels = 0
            var y = firstRow
            while y <= lastRow {
                if let color = bitmap.colorAt(x: x, y: y), isActive(color) {
                    activePixels += 1
                }
                y += 3
            }

            let sampledRows = max(1, ((lastRow - firstRow) / 3) + 1)
            if Double(activePixels) / Double(sampledRows) > 0.002 {
                lastActiveColumn = x
            }
            x += 3
        }

        return min(width, lastActiveColumn + 4)
    }
}
