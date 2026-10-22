import SwiftUI

/// MCCS controls reported by the display; no vendor database or background worker.
struct MonitorColorControls: View {
    let monitor: MonitorConfig
    let monitorStore: MonitorStore
    @State private var error: String?
    @State private var changingPreset = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let values = monitor.colorPresetValues, !values.isEmpty {
                Picker("Monitor color preset", selection: Binding(
                    get: { monitor.currentColorPreset ?? values[0] },
                    set: { value in
                        changingPreset = true
                        Task {
                            do {
                                try await monitorStore.applyColorPreset(monitorID: monitor.id, value: value)
                                error = nil
                                await monitorStore.discover()
                            } catch { self.error = error.localizedDescription }
                            changingPreset = false
                        }
                    })) {
                    ForEach(values, id: \.self) { Text(MonitorColorPreset.label($0)).tag($0) }
                }.disabled(changingPreset)
            }
            ForEach(HardwareFeature.allCases.filter(\.isColor), id: \.rawValue) { feature in
                if let level = monitor.hardwareLevels?[feature.key] {
                    VStack(spacing: 6) {
                        HStack {
                            Text(feature.title)
                            Spacer()
                            Text(level, format: .percent.precision(.fractionLength(0))).monospacedDigit()
                        }.font(.caption).foregroundStyle(.secondary)
                        Slider(value: Binding(
                            get: { monitorStore.monitors.first { $0.id == monitor.id }?.hardwareLevels?[feature.key] ?? level },
                            set: { monitorStore.setHardwareLevel(monitorID: monitor.id, feature: feature, value: $0) }), in: 0...1)
                            .accessibilityLabel("\(monitor.displayName) \(feature.title)")
                            .disabled(changingPreset)
                    }
                }
            }
            Text(monitor.hasMonitorColorControls
                 ? "These settings change the monitor itself. RGB controls may require a User or Custom mode in its on-screen menu."
                 : "This monitor does not report readable DDC color controls in its current mode. Its on-screen menu may offer additional settings.")
                .font(.caption).foregroundStyle(.secondary)
            if let message = error ?? monitorStore.hardwareErrors[monitor.id] {
                Text(message).font(.caption).foregroundStyle(.red)
            }
        }
    }
}
