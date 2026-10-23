import CoreGraphics
import SwiftUI

struct MonitorRow: View {
    let monitor: MonitorConfig
    let monitorStore: MonitorStore
    let expanded: Bool
    let onToggle: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("menu.sectionStates") private var sectionData = Data()
    @AppStorage("menu.showDisplayInfo") private var showDisplayInfo = false
    @AppStorage("menu.brightnessAlwaysVisible") private var brightnessAlwaysVisible = true
    @AppStorage("menu.inputsAlwaysVisible") private var inputsAlwaysVisible = true
    @AppStorage("menu.singleExpandedFeature") private var singleFeature = false
    private let preferences = FeaturePreferences.shared
    private var sections: [String: MenuSectionState] {
        (try? JSONDecoder().decode([String: MenuSectionState].self, from: sectionData)) ?? [:]
    }
    private var state: MenuSectionState { sections[monitor.id] ?? MenuSectionState() }
    private func changeState(_ change: (inout MenuSectionState) -> Void) {
        var values = sections
        var updated = state
        change(&updated)
        values[monitor.id] = updated
        sectionData = (try? JSONEncoder().encode(values)) ?? Data()
    }
    private func isOpen(_ feature: Feature) -> Bool { state.expandedFeatures.contains(feature.rawValue) }

    private enum Feature: String { case input, mode, profiles, hardware, colors, details }
    private var hasHardwareControls: Bool { HardwareFeature.allCases.filter { !$0.isColor }.contains { monitor.hardwareLevels?[$0.key] != nil } || monitor.isMuted != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                if NSEvent.modifierFlags.contains(.option), let id = monitor.systemDisplayID {
                    DisplayIdentifier.shared.show(displayID: id, name: monitor.displayName)
                } else {
                    onToggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: monitor.isBuiltIn ? "laptopcomputer" : "display")
                        .font(.title3).foregroundStyle(.tint).frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(monitor.displayName).font(.headline).lineLimit(1)
                        Text(
                            monitor.isBuiltIn
                                ? "Built-in Retina display"
                                : (monitorStore.currentInputLabel(for: monitor) ?? "External display")
                        )
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    if !expanded, !brightnessAlwaysVisible, preferences.shown(.brightness), let value = monitor.brightnessValue {
                        Text(value, format: .percent.precision(.fractionLength(0)))
                            .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.down").rotationEffect(.degrees(expanded ? 0 : -90))
                        .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }.contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(monitor.displayName), \(expanded ? "collapse" : "expand") controls")

            if preferences.shown(.brightness), expanded || (brightnessAlwaysVisible && monitor.brightnessValue != nil) {
                BrightnessControl(monitor: monitor, monitorStore: monitorStore)
            }
            if expanded {
                if preferences.shown(.inputs), !monitor.isBuiltIn, !monitor.inputMappings.isEmpty {
                    featureRow(
                        .input, title: "Input Source", symbol: "rectangle.connected.to.line.below",
                        value: monitorStore.currentInputLabel(for: monitor)
                    ) {
                        InputSourceControls(monitor: monitor, monitorStore: monitorStore)
                    }
                }
                if preferences.shown(.modes) { displayModeSection }
                if preferences.shown(.profiles) { profilesSection }
                if preferences.shown(.monitorColors), !monitor.isBuiltIn, monitor.hasMonitorColorControls {
                    featureRow(.colors, title: "Monitor Colors", symbol: "slider.horizontal.3") {
                        MonitorColorControls(monitor: monitor, monitorStore: monitorStore)
                    }
                }
                if preferences.shown(.hardware), hasHardwareControls {
                    featureRow(.hardware, title: "Device Control", symbol: "slider.horizontal.3") {
                        HardwareControls(monitor: monitor, monitorStore: monitorStore)
                    }
                }
                if showDisplayInfo {
                    featureRow(.details, title: "Display Info", symbol: "info.circle") {
                        VStack(alignment: .leading, spacing: 6) {
                            LabeledContent("Connection", value: monitor.isBuiltIn ? "Built-in" : "External")
                            LabeledContent("Manufacturer", value: monitor.manufacturer)
                            if !monitor.alphanumericSerial.isEmpty {
                                LabeledContent("Serial", value: monitor.alphanumericSerial)
                            }
                            if let id = monitor.systemDisplayID {
                                let size = CGDisplayScreenSize(id)
                                if size.width > 0 {
                                    LabeledContent(
                                        "Physical size", value: "\(Int(size.width)) × \(Int(size.height)) mm")
                                }
                                LabeledContent("Main display", value: CGDisplayIsMain(id) != 0 ? "Yes" : "No")
                                Button("Identify This Display") {
                                    DisplayIdentifier.shared.show(displayID: id, name: monitor.displayName)
                                }
                                .buttonStyle(.glass)
                            }
                        }.font(.caption).textSelection(.enabled)
                    }
                }

            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.35), in: .rect(cornerRadius: 18))

    }

    @ViewBuilder private var displayModeSection: some View {
        if let id = monitor.systemDisplayID {
            featureRow(.mode, title: "Display Mode", symbol: "rectangle.expand.vertical") {
                DisplayModeControl(displayID: id)
            }
        }
    }

    @ViewBuilder private var profilesSection: some View {
        if let id = monitor.systemDisplayID {
            featureRow(.profiles, title: "macOS Color Profile", symbol: "paintpalette") { ColorProfileControl(displayID: id) }
        }
    }

    private func featureRow<Content: View>(
        _ item: Feature, title: String, symbol: String, value: String? = nil, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if item == .input && inputsAlwaysVisible {
                Text(title).font(.caption).foregroundStyle(.secondary)
                content()
            } else {
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                        changeState { value in
                            if value.expandedFeatures.contains(item.rawValue) {
                                value.expandedFeatures.remove(item.rawValue)
                            } else {
                                if singleFeature { value.expandedFeatures = [] }
                                value.expandedFeatures.insert(item.rawValue)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: symbol).frame(width: 20).foregroundStyle(.secondary)
                        Text(title)
                        Spacer(minLength: 4)
                        if let value { Text(value).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
                        Image(systemName: isOpen(item) ? "chevron.down" : "chevron.right").font(
                            .caption2.weight(.semibold)
                        ).foregroundStyle(.tertiary)
                    }.contentShape(Rectangle()).padding(.vertical, 3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(title), \(isOpen(item) ? "collapse" : "expand")")
                if isOpen(item) { content().padding(.top, 2) }
            }
        }
    }
}

struct BrightnessControl: View {
    let monitor: MonitorConfig
    let monitorStore: MonitorStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Brightness").foregroundStyle(.secondary)
                Spacer()
                if let value = monitor.brightnessValue {
                    Text(value, format: .percent.precision(.fractionLength(0))).monospacedDigit().foregroundStyle(
                        .secondary)
                }
            }.font(.caption)
            if let value = monitor.brightnessValue {
                HStack(spacing: 8) {
                    Image(systemName: "sun.min").foregroundStyle(.secondary)
                    Slider(
                        value: Binding(
                            get: {
                                monitorStore.monitors.first(where: { $0.id == monitor.id })?.brightnessValue ?? value
                            }, set: { monitorStore.setBrightness(monitorID: monitor.id, value: $0) }), in: 0.01...1
                    )
                    .accessibilityLabel("\(monitor.displayName) brightness")
                    Image(systemName: "sun.max.fill").foregroundStyle(.secondary)
                }
            } else {
                Text("Brightness is unavailable in this display mode.").font(.caption).foregroundStyle(.secondary)
            }
            if let error = monitorStore.brightnessError { Text(error).font(.caption).foregroundStyle(.red) }
        }
    }
}
