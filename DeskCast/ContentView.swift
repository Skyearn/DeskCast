import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var state: ProjectionState
    @FocusState private var focusedField: String?

    private let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.minimum = 0
        return formatter
    }()

    private let sliderValueWidth: CGFloat = 54
    private var selectedProjection: ProjectionItem? {
        state.selectedProjection
    }

    private let scaleSnapPoints: [Double] = [0.25, 0.5, 0.75, 1, 1.25, 1.5, 2, 2.5, 3]
    private let transparencySnapPoints: [Double] = [0, 0.25, 0.5, 0.75, 1]

    private var appDisplayName: String {
        Bundle.main.localizedInfoDictionary?["CFBundleDisplayName"] as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? "DeskCast"
    }

    private var selectedProjectionIDBinding: Binding<UUID> {
        Binding(
            get: { state.selectedProjectionID ?? state.projections.first?.id ?? UUID() },
            set: { state.selectProjection($0) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            importSection
            projectionListSection
            editorSection
            footerSection
        }
        .padding(14)
        .frame(width: 388)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(appDisplayName)
                .font(.system(size: 24, weight: .bold, design: .rounded))

            Text("多文档菜单栏桌面投影")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("参数会自动保存，下次打开时继续恢复。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var importSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("添加文档")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.accentColor)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("支持 macOS 可预览的文件")
                            .font(.subheadline.weight(.semibold))

                        Text("可一次选择多个文件导入投影。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Button(action: state.presentOpenPanel) {
                    Label("选择文档", systemImage: "doc.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .glassCard()
        }
    }

    private var projectionListSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("投影列表")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(state.projections.count) 个")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if state.projections.isEmpty {
                Text("还没有投影项。添加文档后，每个文档都会成为一个独立投影，可以同时显示。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard(emphasized: false)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("当前编辑哪个投影", selection: selectedProjectionIDBinding) {
                        ForEach(state.projections) { item in
                            Text(item.fileName).tag(item.id)
                        }
                    }
                    .pickerStyle(.menu)

                    if let projection = selectedProjection {
                        HStack(alignment: .center, spacing: 10) {
                            Circle()
                                .fill(projection.isVisible ? Color.green : Color.secondary.opacity(0.55))
                                .frame(width: 8, height: 8)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(projection.fileName)
                                    .font(.footnote.weight(.semibold))
                                    .lineLimit(1)

                                Text(screenTitle(for: projection.screenID))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Text(projection.isVisible ? "正在投影" : "已暂停")
                                .font(.caption)
                                .foregroundStyle(projection.isVisible ? Color.green : .secondary)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard()
            }
        }
    }

    @ViewBuilder
    private var editorSection: some View {
        if let projection = selectedProjection {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("当前编辑")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(projection.fileName)
                        .font(.system(.headline, design: .rounded, weight: .bold))

                    Text(state.screenSummary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                screenSection(for: projection)
                geometrySection(for: projection)
                placementActionsSection
                scaleSection(for: projection)
                opacitySection(for: projection)
                visibilityActionsSection(for: projection)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
        }
    }

    private func screenSection(for projection: ProjectionItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("投影到哪个屏幕")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("投影到哪个屏幕", selection: Binding(
                get: { projection.screenID },
                set: { state.selectScreenForSelectedProjection($0) }
            )) {
                ForEach(state.availableScreens) { screen in
                    Text(screen.title).tag(screen.id)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private func geometrySection(for projection: ProjectionItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("摆放位置和大小")
                .font(.caption)
                .foregroundStyle(.secondary)

            geometryRow(title: "距左边", value: geometryBinding(\.x), fieldID: "left")
            geometryRow(title: "距下边", value: geometryBinding(\.y), fieldID: "bottom")
            geometryRow(title: "宽度", value: geometryBinding(\.width), fieldID: "width")
            geometryRow(title: "高度", value: geometryBinding(\.height), fieldID: "height")
        }
    }

    private func scaleSection(for projection: ProjectionItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("内容缩放")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                tickedSlider(
                    value: Binding(
                        get: { projection.contentScale },
                        set: { newValue in
                            state.updateSelectedProjection { item in
                                item.contentScale = snapped(newValue, to: scaleSnapPoints, threshold: 0.04)
                            }
                        }
                    ),
                    in: 0.25...3.0,
                    points: scaleSnapPoints,
                    currentValue: projection.contentScale
                )

                Text("\(Int(projection.contentScale * 100))%")
                    .font(.footnote.monospacedDigit())
                    .frame(width: sliderValueWidth, alignment: .trailing)
            }
        }
    }

    private func opacitySection(for projection: ProjectionItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("透明程度")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                tickedSlider(
                    value: Binding(
                        get: { projection.transparency },
                        set: { newValue in
                            state.updateSelectedProjection { item in
                                item.transparency = snapped(newValue, to: transparencySnapPoints, threshold: 0.03)
                            }
                        }
                    ),
                    in: 0...1.0,
                    points: transparencySnapPoints,
                    currentValue: projection.transparency
                )

                Text("\(Int(projection.transparency * 100))%")
                    .font(.footnote.monospacedDigit())
                    .frame(width: sliderValueWidth, alignment: .trailing)
            }
        }
    }

    private var placementActionsSection: some View {
        HStack(spacing: 10) {
            Button("居中摆放") {
                state.centerSelectedProjection()
            }

            Button("铺满整个屏幕") {
                state.fillSelectedProjection()
            }
        }
        .buttonStyle(.bordered)
    }

    private func visibilityActionsSection(for projection: ProjectionItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: state.toggleSelectedProjectionVisibility) {
                Label(projection.isVisible ? "暂停这个投影" : "恢复这个投影", systemImage: projection.isVisible ? "pause.circle" : "play.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button(role: .destructive) {
                state.removeProjection(projection.id)
            } label: {
                Label("删除这个投影", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private var footerSection: some View {
        HStack {
            if let message = state.lastErrorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Spacer()

            Button("退出 \(appDisplayName)") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.borderless)
        }
        .padding(.top, 2)
    }

    private func geometryRow(title: String, value: Binding<Double>, fieldID: String) -> some View {
        HStack {
            Text(title)
                .frame(width: 52, alignment: .leading)

            TextField(title, value: value, formatter: numberFormatter)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .focused($focusedField, equals: fieldID)
                .onSubmit {
                    state.normalizeSelectedProjectionGeometry()
                }
        }
    }

    private func geometryBinding(_ keyPath: WritableKeyPath<ProjectionGeometry, Double>) -> Binding<Double> {
        Binding(
            get: {
                selectedProjection?.geometry[keyPath: keyPath] ?? 0
            },
            set: { newValue in
                state.updateSelectedProjection { item in
                    item.geometry[keyPath: keyPath] = newValue
                }
            }
        )
    }

    private func screenTitle(for screenID: UInt32) -> String {
        state.screen(for: screenID)?.title ?? state.defaultScreen.title
    }

    private func tickedSlider(
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        points: [Double],
        currentValue: Double
    ) -> some View {
        SliderWithTrackTicks(
            value: value,
            tickValues: points,
            currentValue: currentValue
        )
        .frame(height: 24)
    }

    private func snapped(_ value: Double, to points: [Double], threshold: Double) -> Double {
        guard let closest = points.min(by: { abs($0 - value) < abs($1 - value) }) else {
            return value
        }

        return abs(closest - value) <= threshold ? closest : value
    }
}

private struct GlassCardModifier: ViewModifier {
    let emphasized: Bool

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    VisualEffectMaterialView(
                        material: emphasized ? .popover : .sidebar,
                        blendingMode: .withinWindow
                    )

                    LinearGradient(
                        colors: emphasized
                            ? [
                                Color.white.opacity(0.16),
                                Color.white.opacity(0.07),
                                Color.white.opacity(0.03)
                            ]
                            : [
                                Color.white.opacity(0.1),
                                Color.white.opacity(0.045),
                                Color.white.opacity(0.02)
                            ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(emphasized ? 0.26 : 0.18),
                                Color.white.opacity(emphasized ? 0.12 : 0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.9
                    )
            )
            .shadow(color: Color.black.opacity(0.1), radius: 18, y: 8)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private extension View {
    func glassCard(emphasized: Bool = true) -> some View {
        modifier(GlassCardModifier(emphasized: emphasized))
    }
}

private struct VisualEffectMaterialView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.state = .active
        view.material = material
        view.blendingMode = blendingMode
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = .active
        nsView.isEmphasized = true
    }
}

private struct SliderWithTrackTicks: NSViewRepresentable {
    @Binding var value: Double
    let tickValues: [Double]
    let currentValue: Double

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> TrackTickSlider {
        let slider = TrackTickSlider(frame: .zero)
        slider.target = context.coordinator
        slider.action = #selector(Coordinator.valueChanged(_:))
        slider.isContinuous = true
        slider.controlSize = .regular
        configure(slider)
        return slider
    }

    func updateNSView(_ slider: TrackTickSlider, context: Context) {
        context.coordinator.parent = self
        configure(slider)
    }

    private func configure(_ slider: TrackTickSlider) {
        slider.minValue = 0
        slider.maxValue = 1
        slider.tickValues = tickValues
        slider.highlightedTickValue = currentValue
        slider.numberOfSegments = max(tickValues.count - 1, 1)

        let normalizedValue = normalizedPosition(for: value)
        if abs(slider.doubleValue - normalizedValue) > 0.0001 {
            slider.doubleValue = normalizedValue
        }

        slider.needsDisplay = true
    }

    private func normalizedPosition(for actualValue: Double) -> Double {
        guard tickValues.count > 1 else {
            return 0
        }

        let clampedValue = min(max(actualValue, tickValues.first ?? actualValue), tickValues.last ?? actualValue)

        for index in 0..<(tickValues.count - 1) {
            let lower = tickValues[index]
            let upper = tickValues[index + 1]

            if clampedValue <= upper || index == tickValues.count - 2 {
                let span = upper - lower
                let localRatio = span == 0 ? 0 : (clampedValue - lower) / span
                return (Double(index) + localRatio) / Double(tickValues.count - 1)
            }
        }

        return 1
    }

    private func actualValue(for normalizedPosition: Double) -> Double {
        guard tickValues.count > 1 else {
            return tickValues.first ?? normalizedPosition
        }

        let clampedPosition = min(max(normalizedPosition, 0), 1)
        let segmentPosition = clampedPosition * Double(tickValues.count - 1)
        let index = min(Int(segmentPosition.rounded(.down)), tickValues.count - 2)
        let localRatio = segmentPosition - Double(index)
        let lower = tickValues[index]
        let upper = tickValues[index + 1]
        return lower + ((upper - lower) * localRatio)
    }

    final class Coordinator: NSObject {
        var parent: SliderWithTrackTicks

        init(parent: SliderWithTrackTicks) {
            self.parent = parent
        }

        @MainActor
        @objc func valueChanged(_ sender: NSSlider) {
            parent.value = parent.actualValue(for: sender.doubleValue)
        }
    }
}

private final class TrackTickSlider: NSSlider {
    var tickValues: [Double] = []
    var highlightedTickValue: Double = 0
    var numberOfSegments: Int = 1

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard tickValues.count > 2, numberOfSegments > 0 else {
            return
        }

        let interiorPoints = Array(tickValues.dropFirst().dropLast())
        let sliderCell = cell as? NSSliderCell
        let fallbackBarRect = NSRect(x: 10, y: bounds.midY - 2, width: max(bounds.width - 20, 0), height: 4)
        let barRect = sliderCell?.barRect(flipped: isFlipped) ?? fallbackBarRect
        let originalValue = doubleValue

        for (index, point) in interiorPoints.enumerated() {
            doubleValue = Double(index + 1) / Double(numberOfSegments)
            let knobRect = sliderCell?.knobRect(flipped: isFlipped) ?? .zero
            let x = knobRect == .zero
                ? barRect.minX + (barRect.width * CGFloat(index + 1) / CGFloat(numberOfSegments))
                : knobRect.midX
            let isActive = abs(highlightedTickValue - point) < 0.001
            let tickHeight: CGFloat = isActive ? 12 : 8
            let tickRect = NSRect(
                x: x - 1,
                y: barRect.midY - (tickHeight / 2),
                width: 2,
                height: tickHeight
            )

            let color = isActive
                ? NSColor.controlAccentColor.withAlphaComponent(0.95)
                : NSColor.secondaryLabelColor.withAlphaComponent(0.42)

            color.setFill()
            NSBezierPath(roundedRect: tickRect, xRadius: 1, yRadius: 1).fill()
        }

        doubleValue = originalValue
    }
}
