import KeyboardShortcuts
import SwiftUI

struct InputSourceControls: View {
    let monitor: MonitorConfig
    let monitorStore: MonitorStore
    @State private var error: String?
    @State private var switching = false
    @State private var hoveredInput: UInt16?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if monitor.orderedCycleInputs.count >= 2 {
                Button {
                    perform { try await monitorStore.cycleInput(monitorID: monitor.id) }
                } label: {
                    HStack {
                        Label("Cycle Inputs", systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
                        Spacer()
                        shortcut(.cycleInputs(monitor.id))
                    }.frame(minHeight: 28).contentShape(Rectangle())
                }.buttonStyle(.borderless)
                    .help(monitor.orderedCycleInputs.map(\.label).joined(separator: " → "))
                Divider().padding(.vertical, 4)
            }
            ForEach(monitor.inputMappings) { input in
                Button {
                    perform { try await monitorStore.switchInput(monitorID: monitor.id, to: input.ddcValue) }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: monitor.currentInputValue == input.ddcValue ? "checkmark" : "cable.connector")
                            .foregroundStyle(
                                monitor.currentInputValue == input.ddcValue ? Color.accentColor : Color.secondary
                            )
                            .frame(width: 20)
                        Text(input.label).lineLimit(1)
                        Spacer(minLength: 8)
                        shortcut(.inputSource(monitor.id, input.ddcValue))
                    }.padding(.horizontal, 8).frame(minHeight: 32).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(
                    hoveredInput == input.ddcValue ? Color.primary.opacity(0.06) : .clear, in: .rect(cornerRadius: 6)
                )
                .onHover { hoveredInput = $0 ? input.ddcValue : nil }
                .accessibilityLabel("Switch \(monitor.displayName) to \(input.label)")
                .accessibilityValue(monitor.currentInputValue == input.ddcValue ? "Selected" : "")
            }
            if let error { Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled) }
            if switching {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Switching input…").font(.caption).foregroundStyle(.secondary)
                }
                .padding(.top, 4).accessibilityElement(children: .combine)
            }
        }.disabled(switching)
    }

    @ViewBuilder private func shortcut(_ name: KeyboardShortcuts.Name) -> some View {
        if let shortcut = KeyboardShortcuts.getShortcut(for: name) {
            Text(shortcut.description).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func perform(_ action: @escaping @MainActor () async throws -> Void) {
        guard !switching else { return }
        error = nil
        switching = true
        Task { @MainActor in
            defer { switching = false }
            do { try await action() } catch { self.error = error.localizedDescription }
        }
    }
}
