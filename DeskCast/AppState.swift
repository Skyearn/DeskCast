import AppKit
import Combine
import Foundation
import SwiftUI

struct ProjectionScreen: Identifiable, Hashable {
    let id: UInt32
    let name: String
    let frame: CGRect

    var title: String {
        "\(name) · \(Int(frame.width)) × \(Int(frame.height))"
    }
}

struct ProjectionGeometry: Codable, Equatable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    static func centered(in screen: CGRect, coverage: CGFloat = 0.72) -> ProjectionGeometry {
        let width = max(240, screen.width * coverage)
        let height = max(180, screen.height * coverage)
        return ProjectionGeometry(
            x: (screen.width - width) / 2,
            y: (screen.height - height) / 2,
            width: width,
            height: height
        )
    }

    func clamped(to screen: CGRect) -> ProjectionGeometry {
        let clampedWidth = min(max(160, width), screen.width)
        let clampedHeight = min(max(120, height), screen.height)
        let maxX = screen.width - clampedWidth
        let maxY = screen.height - clampedHeight

        return ProjectionGeometry(
            x: min(max(0, x), maxX),
            y: min(max(0, y), maxY),
            width: clampedWidth,
            height: clampedHeight
        )
    }

    func rect(in screen: CGRect) -> CGRect {
        let geometry = clamped(to: screen)
        return CGRect(
            x: screen.minX + geometry.x,
            y: screen.minY + geometry.y,
            width: geometry.width,
            height: geometry.height
        )
    }
}

struct ProjectionItem: Identifiable, Codable, Equatable {
    var id: UUID
    var filePath: String
    var screenID: UInt32
    var geometry: ProjectionGeometry
    var transparency: Double
    var contentScale: Double
    var isVisible: Bool

    init(
        id: UUID = UUID(),
        fileURL: URL,
        screenID: UInt32,
        geometry: ProjectionGeometry,
        transparency: Double = 0.25,
        contentScale: Double = 1.0,
        isVisible: Bool = true
    ) {
        self.id = id
        self.filePath = fileURL.path
        self.screenID = screenID
        self.geometry = geometry
        self.transparency = transparency
        self.contentScale = contentScale
        self.isVisible = isVisible
    }

    var fileURL: URL {
        URL(fileURLWithPath: filePath)
    }

    var fileName: String {
        fileURL.lastPathComponent
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case filePath
        case screenID
        case geometry
        case transparency
        case contentScale
        case isVisible
        case opacity
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        filePath = try container.decode(String.self, forKey: .filePath)
        screenID = try container.decode(UInt32.self, forKey: .screenID)
        geometry = try container.decode(ProjectionGeometry.self, forKey: .geometry)
        contentScale = try container.decodeIfPresent(Double.self, forKey: .contentScale) ?? 1.0
        isVisible = try container.decodeIfPresent(Bool.self, forKey: .isVisible) ?? true

        if let transparency = try container.decodeIfPresent(Double.self, forKey: .transparency) {
            self.transparency = transparency
        } else if let legacyOpacity = try container.decodeIfPresent(Double.self, forKey: .opacity) {
            self.transparency = 1 - legacyOpacity
        } else {
            self.transparency = 0.25
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(filePath, forKey: .filePath)
        try container.encode(screenID, forKey: .screenID)
        try container.encode(geometry, forKey: .geometry)
        try container.encode(transparency, forKey: .transparency)
        try container.encode(contentScale, forKey: .contentScale)
        try container.encode(isVisible, forKey: .isVisible)
    }
}

private struct PersistedProjectionState: Codable {
    var projections: [ProjectionItem]
    var selectedProjectionID: UUID?
}

@MainActor
final class ProjectionState: ObservableObject {
    @Published var projections: [ProjectionItem] = []
    @Published var selectedProjectionID: UUID?
    @Published var lastErrorMessage: String?

    private let persistenceKey = "DeskCast.persistedProjectionState"
    private var cancellables = Set<AnyCancellable>()
    private var isRestoringState = false

    init() {
        restoreState()
        configurePersistence()
    }

    var selectedProjection: ProjectionItem? {
        guard let selectedProjectionID else { return nil }
        return projections.first(where: { $0.id == selectedProjectionID })
    }

    var selectedProjectionIndex: Int? {
        guard let selectedProjectionID else { return nil }
        return projections.firstIndex(where: { $0.id == selectedProjectionID })
    }

    var hasSelection: Bool {
        selectedProjection != nil
    }

    var selectedFileName: String {
        selectedProjection?.fileName ?? "尚未选择文档"
    }

    static var screens: [ProjectionScreen] {
        NSScreen.screens.map {
            ProjectionScreen(
                id: $0.displayID,
                name: $0.localizedName,
                frame: $0.frame
            )
        }
        .sorted { lhs, rhs in
            if lhs.frame.minX == rhs.frame.minX {
                return lhs.frame.minY < rhs.frame.minY
            }
            return lhs.frame.minX < rhs.frame.minX
        }
    }

    var availableScreens: [ProjectionScreen] {
        Self.screens
    }

    var defaultScreen: ProjectionScreen {
        availableScreens.first
            ?? ProjectionScreen(id: 0, name: "主屏幕", frame: CGRect(x: 0, y: 0, width: 1440, height: 900))
    }

    func screen(for id: UInt32) -> ProjectionScreen? {
        availableScreens.first(where: { $0.id == id })
    }

    var currentScreen: ProjectionScreen {
        guard let projection = selectedProjection else { return defaultScreen }
        return screen(for: projection.screenID) ?? defaultScreen
    }

    var currentScreenFrame: CGRect {
        currentScreen.frame
    }

    var screenSummary: String {
        let screen = currentScreen
        return "当前屏幕：\(screen.name) · \(Int(screen.frame.width)) × \(Int(screen.frame.height))"
    }

    func presentOpenPanel() {
        let panel = NSOpenPanel()
        if let contentTypes = SupportedDocumentTypes.openPanelContentTypes {
            panel.allowedContentTypes = contentTypes
        }
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "添加投影"
        panel.message = "可一次添加多个系统能预览的文件。"

        guard panel.runModal() == .OK else { return }
        addFiles(panel.urls)
    }

    func addFiles(_ urls: [URL]) {
        guard !urls.isEmpty else { return }

        let supported = urls.filter(SupportedDocumentTypes.isSupported)
        let unsupported = urls.filter { !SupportedDocumentTypes.isSupported($0) }

        var insertedIDs: [UUID] = []
        for (index, url) in supported.enumerated() {
            let item = makeProjectionItem(for: url, offsetIndex: index)
            projections.append(item)
            insertedIDs.append(item.id)
        }

        if let lastID = insertedIDs.last {
            selectedProjectionID = lastID
        }

        if supported.isEmpty {
            lastErrorMessage = "选中的内容里没有可投影的文件。"
        } else if unsupported.isEmpty {
            lastErrorMessage = nil
        } else {
            lastErrorMessage = "已添加 \(supported.count) 个文件，忽略了 \(unsupported.count) 个无法投影的内容。"
        }
    }

    func selectProjection(_ id: UUID) {
        selectedProjectionID = id
        lastErrorMessage = nil
    }

    func removeProjection(_ id: UUID) {
        projections.removeAll { $0.id == id }

        if selectedProjectionID == id {
            selectedProjectionID = projections.last?.id
        }

        if projections.isEmpty {
            lastErrorMessage = nil
        }
    }

    func toggleVisibility(for id: UUID) {
        updateProjection(id) { item in
            item.isVisible.toggle()
        }
    }

    func toggleSelectedProjectionVisibility() {
        guard let selectedProjectionID else {
            lastErrorMessage = "请先选择一个投影项。"
            return
        }

        toggleVisibility(for: selectedProjectionID)
    }

    func updateSelectedProjection(_ mutate: (inout ProjectionItem) -> Void) {
        guard let selectedProjectionID else { return }
        updateProjection(selectedProjectionID, mutate)
    }

    func centerSelectedProjection() {
        updateSelectedProjection { item in
            let screen = screen(for: item.screenID) ?? defaultScreen
            item.geometry = ProjectionGeometry.centered(in: screen.frame)
        }
    }

    func fillSelectedProjection() {
        updateSelectedProjection { item in
            let screen = screen(for: item.screenID) ?? defaultScreen
            item.geometry = ProjectionGeometry(x: 0, y: 0, width: screen.frame.width, height: screen.frame.height)
        }
    }

    func selectScreenForSelectedProjection(_ displayID: UInt32) {
        updateSelectedProjection { item in
            item.screenID = displayID
            let screen = screen(for: displayID) ?? defaultScreen
            item.geometry = item.geometry.clamped(to: screen.frame)
        }
    }

    func normalizeSelectedProjectionGeometry() {
        updateSelectedProjection { item in
            let screen = screen(for: item.screenID) ?? defaultScreen
            item.geometry = item.geometry.clamped(to: screen.frame)
            item.transparency = min(max(item.transparency, 0), 1.0)
            item.contentScale = min(max(item.contentScale, 0.25), 3.0)
        }
    }

    private func updateProjection(_ id: UUID, _ mutate: (inout ProjectionItem) -> Void) {
        guard let index = projections.firstIndex(where: { $0.id == id }) else { return }
        var item = projections[index]
        mutate(&item)
        item = normalizedProjection(item)
        projections[index] = item
        lastErrorMessage = nil
    }

    private func makeProjectionItem(for url: URL, offsetIndex: Int) -> ProjectionItem {
        let preferredScreenID = selectedProjection?.screenID ?? defaultScreen.id
        let screen = screen(for: preferredScreenID) ?? defaultScreen
        var geometry = ProjectionGeometry.centered(in: screen.frame)
        geometry.x += Double(offsetIndex * 28)
        geometry.y = max(0, geometry.y - Double(offsetIndex * 28))
        geometry = geometry.clamped(to: screen.frame)

        return ProjectionItem(
            fileURL: url,
            screenID: screen.id,
            geometry: geometry,
            transparency: selectedProjection?.transparency ?? 0.25,
            contentScale: selectedProjection?.contentScale ?? 1.0,
            isVisible: true
        )
    }

    private func normalizedProjection(_ item: ProjectionItem) -> ProjectionItem {
        var normalized = item
        let screen = screen(for: normalized.screenID) ?? defaultScreen
        normalized.screenID = screen.id
        normalized.geometry = normalized.geometry.clamped(to: screen.frame)
        normalized.transparency = min(max(normalized.transparency, 0), 1.0)
        normalized.contentScale = min(max(normalized.contentScale, 0.25), 3.0)
        return normalized
    }

    private func restoreState() {
        isRestoringState = true
        defer { isRestoringState = false }

        guard
            let data = UserDefaults.standard.data(forKey: persistenceKey),
            let saved = try? JSONDecoder().decode(PersistedProjectionState.self, from: data)
        else {
            selectedProjectionID = nil
            projections = []
            return
        }

        projections = saved.projections.map(normalizedProjection)
        selectedProjectionID = saved.selectedProjectionID

        if selectedProjection == nil {
            selectedProjectionID = projections.first?.id
        }
    }

    private func configurePersistence() {
        Publishers.CombineLatest($projections, $selectedProjectionID)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in
                self?.persistStateIfNeeded()
            }
            .store(in: &cancellables)
    }

    private func persistStateIfNeeded() {
        guard !isRestoringState else { return }

        let state = PersistedProjectionState(
            projections: projections,
            selectedProjectionID: selectedProjectionID
        )

        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: persistenceKey)
    }
}

private extension NSScreen {
    var displayID: UInt32 {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32 ?? 0
    }
}
