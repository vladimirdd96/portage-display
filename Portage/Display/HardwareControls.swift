import SwiftUI

struct HardwareControls: View {
    let monitor: MonitorConfig
    let monitorStore: MonitorStore
    @State private var error: String?

    var body: some View {
        VStack(spacing: 14) {
            ForEach(HardwareFeature.allCases, id: \.rawValue) { feature in
                if let level = monitor.hardwareLevels?[feature.key] {
                    VStack(spacing: 6) {
                        HStack {
                            Label(feature.title, systemImage: feature.symbol)
                            Spacer()
                            Text(level, format: .percent.precision(.fractionLength(0))).monospacedDigit()
                        }.font(.caption).foregroundStyle(.secondary)
                        Slider(value: Binding(get: {
                            monitorStore.monitors.first(where: { $0.id == monitor.id })?.hardwareLevels?[feature.key] ?? level
                        }, set: { monitorStore.setHardwareLevel(monitorID: monitor.id, feature: feature, value: $0) }), in: 0...1)
                            .accessibilityLabel("\(monitor.displayName) \(feature.title.lowercased())")
                    }
                }
            }
            if let muted = monitor.isMuted {
                Toggle("Mute display audio", isOn: Binding(get: { muted }, set: { value in
                    Task {
                        do { try await monitorStore.setMute(monitorID: monitor.id, muted: value); error = nil }
                        catch { self.error = error.localizedDescription }
                    }
                }))
            }
            if let message = error ?? monitorStore.hardwareErrors[monitor.id] {
                Text(message).font(.caption).foregroundStyle(.red)
            }
        }
    }
}
