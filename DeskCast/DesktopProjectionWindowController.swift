import AppKit
import Combine
import SwiftUI

@MainActor
final class DesktopProjectionWindowController {
    private let state: ProjectionState
    private var cancellables = Set<AnyCancellable>()
    private var windows: [UUID: NSWindow] = [:]

    init(state: ProjectionState) {
        self.state = state
        bindState()
    }

    private func bindState() {
        state.$projections
            .receive(on: RunLoop.main)
            .sink { [weak self] items in
                self?.syncWindows(with: items)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.syncWindows(with: self.state.projections)
            }
            .store(in: &cancellables)
    }

    private func syncWindows(with items: [ProjectionItem]) {
        let activeItems = items.filter(\.isVisible)
        let activeIDs = Set(activeItems.map(\.id))

        for item in activeItems {
            syncWindow(for: item)
        }

        let inactiveIDs = Set(windows.keys).subtracting(activeIDs)
        for id in inactiveIDs {
            windows[id]?.orderOut(nil)
            windows[id]?.close()
            windows.removeValue(forKey: id)
        }
    }

    private func syncWindow(for item: ProjectionItem) {
        let window = windows[item.id] ?? makeWindow(for: item)
        window.contentView = NSHostingView(rootView: ProjectionItemStageView(url: item.fileURL, contentScale: item.contentScale))
        window.alphaValue = 1 - item.transparency
        window.setFrame(frame(for: item), display: true)
        window.orderFrontRegardless()
        windows[item.id] = window
    }

    private func makeWindow(for item: ProjectionItem) -> NSWindow {
        let desktopLevel = Int(CGWindowLevelForKey(.desktopIconWindow)) - 1
        let window = NSWindow(
            contentRect: frame(for: item),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.level = .init(rawValue: desktopLevel)
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        return window
    }

    private func frame(for item: ProjectionItem) -> CGRect {
        let screen = state.effectiveScreen(for: item)
        let rect = state.effectiveGeometry(for: item).rect(in: screen.frame)
        return DocumentPreviewSizing.frameForPreviewing(url: item.fileURL, in: rect)
    }
}

private enum DocumentPreviewSizing {
    private static let spreadsheetExtensions: Set<String> = [
        "csv",
        "numbers",
        "tsv",
        "xls",
        "xlsm",
        "xlsx"
    ]

    static func frameForPreviewing(url: URL, in rect: CGRect) -> CGRect {
        guard spreadsheetExtensions.contains(url.pathExtension.lowercased()),
              ProjectionDocumentView.usesSpreadsheetQuickLookLayout(for: url)
        else {
            return rect
        }

        let aspectRatio = (try? XLSXHTMLRenderer.aspectRatio(url: url)) ?? 3.2
        let fittedHeight = min(rect.height, ceil(rect.width / aspectRatio) + 18)
        return CGRect(
            x: rect.minX,
            y: rect.maxY - fittedHeight,
            width: rect.width,
            height: fittedHeight
        )
    }
}

private struct ProjectionItemStageView: View {
    let url: URL
    let contentScale: Double

    var body: some View {
        GeometryReader { proxy in
            ProjectionDocumentView(url: url)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .scaleEffect(contentScale, anchor: .center)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
    }
}
