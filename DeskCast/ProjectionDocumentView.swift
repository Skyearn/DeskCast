import PDFKit
import QuickLookUI
import SwiftUI
import WebKit

struct ProjectionDocumentView: NSViewRepresentable {
    let url: URL?

    nonisolated static func usesSpreadsheetQuickLookLayout(for url: URL) -> Bool {
        SpreadsheetHTMLPreviewView.canPreview(url: url)
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

        if SpreadsheetHTMLPreviewView.canPreview(url: url) {
            return SpreadsheetHTMLPreviewView(url: url) ?? makeQuickLookPreviewView(for: url)
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

final class SpreadsheetHTMLPreviewView: WKWebView {
    nonisolated static func canPreview(url: URL) -> Bool {
        ["xlsx"].contains(url.pathExtension.lowercased())
    }

    init?(url: URL) {
        guard let html = try? XLSXHTMLRenderer.render(url: url) else { return nil }

        let configuration = WKWebViewConfiguration()
        configuration.suppressesIncrementalRendering = true
        super.init(frame: .zero, configuration: configuration)
        setValue(false, forKey: "drawsBackground")
        loadHTMLString(html, baseURL: url.deletingLastPathComponent())
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
