import KeyboardShortcuts
import SwiftUI

struct CycleInputSettings: View {
    let monitor: MonitorConfig
    let monitorStore: MonitorStore
    let presetStore: PresetStore

    private var selected: [UInt16] { monitor.orderedCycleInputs.map(\.ddcValue) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Cycle Inputs", systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
                Spacer()
                ShortcutRecorder(for: .cycleInputs(monitor.id)) { shortcut in
                    ShortcutAssignment.move(
                        shortcut, to: .cycleInputs(monitor.id),
                        among: ShortcutAssignment.names(monitors: monitorStore, presets: presetStore))
                }
            }
            DisclosureGroup("Included Inputs & Order") {
                Text(
                    "Each press advances to the next selected input and wraps around. Select at least two; use the arrows to reorder."
                )
                .font(.caption).foregroundStyle(.secondary)
                ForEach(monitor.orderedCycleInputs) { input in
                    HStack {
                        Toggle(input.label, isOn: included(input.ddcValue))
                        Spacer()
                        Button {
                            move(input.ddcValue, by: -1)
                        } label: {
                            Image(systemName: "arrow.up")
                        }
                        .disabled(selected.first == input.ddcValue)
                        .accessibilityLabel("Move \(input.label) earlier")
                        Button {
                            move(input.ddcValue, by: 1)
                        } label: {
                            Image(systemName: "arrow.down")
                        }
                        .disabled(selected.last == input.ddcValue)
                        .accessibilityLabel("Move \(input.label) later")
                    }
                }
                ForEach(monitor.inputMappings.filter { !selected.contains($0.ddcValue) }) { input in
                    Toggle(input.label, isOn: included(input.ddcValue))
                }
                Button("Use All Inputs in Default Order") {
                    monitorStore.updateCycleInputs(monitorID: monitor.id, values: nil)
                }.buttonStyle(.borderless)
                if selected.count < 2 {
                    Text("Cycling is unavailable until at least two inputs are selected.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text(
                    "A monitor may stop accepting commands after switching away from the Mac. Cycling back depends on the monitor and connection."
                )
                .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func included(_ value: UInt16) -> Binding<Bool> {
        Binding(
            get: { selected.contains(value) },
            set: { enabled in
                var values = selected.filter { $0 != value }
                if enabled { values.append(value) }
                monitorStore.updateCycleInputs(monitorID: monitor.id, values: values)
            })
    }

    private func move(_ value: UInt16, by offset: Int) {
        var values = selected
        guard let index = values.firstIndex(of: value), values.indices.contains(index + offset) else { return }
        values.swapAt(index, index + offset)
        monitorStore.updateCycleInputs(monitorID: monitor.id, values: values)
    }
}
