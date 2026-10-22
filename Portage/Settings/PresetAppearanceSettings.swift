import SwiftUI

struct PresetAppearanceSettings: View {
    let preset: Preset
    let monitor: MonitorConfig
    let presetStore: PresetStore
    private let features = FeaturePreferences.shared
    @State private var profiles: [DisplayColorProfile] = []
    private var saved: PresetDisplaySettings {
        preset.displaySettings?.first { $0.id == monitor.id }
            ?? PresetDisplaySettings(monitorEdidUUID: monitor.id, displayName: monitor.displayName)
    }

    private func update(_ change: (inout PresetDisplaySettings) -> Void) {
        var settings = saved
        change(&settings)
        var updated = preset
        var values = updated.displaySettings ?? []
        values.removeAll { $0.id == monitor.id }
        if !settings.isEmpty { values.append(settings) }
        updated.displaySettings = values.isEmpty ? nil : values
        presetStore.updatePreset(updated)
    }

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 16) {
                Text("Enable only the settings this preset should change. Editing these values does not change your display.")
                    .font(.caption).foregroundStyle(.secondary)
                if features.enabled(.monitorColors), let values = monitor.colorPresetValues, !values.isEmpty {
                    Picker("Monitor color preset", selection: Binding(
                        get: { saved.colorPreset ?? 0 },
                        set: { value in update { $0.colorPreset = value == 0 ? nil : value } })) {
                        Text("Leave Unchanged").tag(UInt16(0))
                        ForEach(values, id: \.self) { Text(MonitorColorPreset.label($0)).tag($0) }
                    }
                }
                ForEach(HardwareFeature.allCases.filter { $0.isColor && features.enabled(.monitorColors) }, id: \.rawValue) { feature in
                    if monitor.hardwareLevels?[feature.key] != nil || saved.rgbGains?[feature.key] != nil {
                        level(feature.title, value: saved.rgbGains?[feature.key], current: monitor.hardwareLevels?[feature.key] ?? 0.5) { value in
                            update {
                                var gains = $0.rgbGains ?? [:]
                                gains[feature.key] = value
                                $0.rgbGains = gains.isEmpty ? nil : gains
                            }
                        }
                    }
                }
                if features.enabled(.brightness), monitor.brightnessValue != nil || saved.brightness != nil {
                    level("Brightness", value: saved.brightness, current: monitor.brightnessValue ?? 0.5, minimum: 0.01) {
                        value in update { $0.brightness = value }
                    }
                }
                if features.enabled(.hardware), monitor.hardwareLevels?[HardwareFeature.contrast.key] != nil || saved.contrast != nil {
                    level("Contrast", value: saved.contrast, current: monitor.hardwareLevels?[HardwareFeature.contrast.key] ?? 0.5) {
                        value in update { $0.contrast = value }
                    }
                }
                if features.enabled(.hardware), monitor.hardwareLevels?[HardwareFeature.volume.key] != nil || saved.volume != nil {
                    level("Display volume", value: saved.volume, current: monitor.hardwareLevels?[HardwareFeature.volume.key] ?? 0.5) {
                        value in update { $0.volume = value }
                    }
                }
                if features.enabled(.hardware), monitor.isMuted != nil || saved.muted != nil {
                    Picker("Display audio", selection: Binding(
                        get: { saved.muted.map { $0 ? 1 : 2 } ?? 0 },
                        set: { value in update { $0.muted = value == 0 ? nil : value == 1 } })) {
                        Text("Leave Unchanged").tag(0)
                        Text("Mute").tag(1)
                        Text("Unmute").tag(2)
                    }
                }
                if features.enabled(.profiles), monitor.systemDisplayID != nil {
                    DisclosureGroup("Advanced · macOS Color Profile") {
                        Picker("Color profile", selection: Binding(
                            get: { saved.colorProfilePath ?? "" },
                            set: { path in update {
                                $0.colorProfilePath = path.isEmpty ? nil : path
                                $0.colorProfileName = profiles.first { $0.id == path }?.name
                            } })) {
                            Text("Leave Unchanged").tag("")
                            if let path = saved.colorProfilePath, !profiles.contains(where: { $0.id == path }) {
                                Text("\(saved.colorProfileName ?? "Saved profile") (unavailable)").tag(path)
                            }
                            ForEach(profiles) { Text($0.name).tag($0.id) }
                        }
                        Text("Profiles affect this Mac’s colors. Custom profiles must also be installed on any other Mac using the preset.")
                            .font(.caption).foregroundStyle(.secondary)
                        .task(id: monitor.systemDisplayID) {
                            if let id = monitor.systemDisplayID { profiles = DisplayColorProfiles.available(displayID: id) }
                        }
                    }.disclosureGroupStyle(FullRowDisclosureStyle())
                }
                if !saved.isEmpty {
                    Button("Leave All Appearance Settings Unchanged") {
                        update { $0.colorPreset = nil; $0.rgbGains = nil; $0.brightness = nil; $0.contrast = nil; $0.volume = nil; $0.muted = nil
                            $0.colorProfilePath = nil; $0.colorProfileName = nil }
                    }.buttonStyle(.borderless)
                }
            }.padding(.vertical, 8)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Label(monitor.displayName, systemImage: monitor.isBuiltIn ? "laptopcomputer" : "display")
                Text(saved.isEmpty ? "Leave Unchanged" : saved.summary)
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.disclosureGroupStyle(FullRowDisclosureStyle())
    }

    private func level(_ title: String, value: Double?, current: Double, minimum: Double = 0,
                       set: @escaping (Double?) -> Void) -> some View {
        VStack(spacing: 6) {
            Toggle(isOn: Binding(get: { value != nil }, set: { set($0 ? current : nil) })) {
                HStack {
                    Text(title)
                    Spacer()
                    if let value { Text(value, format: .percent.precision(.fractionLength(0))).monospacedDigit().foregroundStyle(.secondary) }
                }
            }
            .accessibilityLabel(title)
            if let value {
                Slider(value: Binding(get: { value }, set: { set($0) }), in: minimum...1)
                    .accessibilityLabel("\(monitor.displayName) preset \(title.lowercased())")
            }
        }
    }
}
