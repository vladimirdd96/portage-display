import SwiftUI
import CoreGraphics

struct DisplayModeControl: View {
    let displayID: UInt32
    @State private var modes: [CGDisplayMode] = []
    @State private var selection: Int32 = 0
    @State private var current: Int32 = 0
    @State private var previous: CGDisplayMode?
    @State private var reverting: Task<Void, Never>?
    @State private var confirming = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if modes.isEmpty {
                Text("No configurable display modes reported by macOS.").foregroundStyle(.secondary)
            } else {
                Picker("Resolution & refresh rate", selection: $selection) {
                    ForEach(refreshGroups, id: \.title) { group in
                        Section(group.title) {
                            ForEach(group.modes, id: \.ioDisplayModeID) { mode in
                                Text(Self.label(mode)).tag(mode.ioDisplayModeID)
                            }
                        }
                    }
                }.labelsHidden().frame(maxWidth: .infinity)
                HStack {
                    Text("Changes revert after 15 seconds unless you keep them.")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Apply") { apply() }
                        .buttonStyle(.glass).disabled(selection == current || confirming)
                }
            }
            if let error { Text(error).foregroundStyle(.red).font(.caption) }
        }
        .task(id: displayID) { reload() }
        .alert("Keep this display mode?", isPresented: $confirming) {
            Button("Keep Changes") {
                reverting?.cancel()
                previous = nil
                reload()
            }
            Button("Revert", role: .cancel) { revert() }
        } message: {
            Text("The previous mode will be restored automatically after 15 seconds.")
        }
        .onDisappear { if previous != nil { revert() } }
    }

    private var refreshGroups: [(title: String, modes: [CGDisplayMode])] {
        let groups = Dictionary(grouping: modes, by: { Self.refreshLabel($0.refreshRate) })
        return groups.map { (title: $0.key, modes: $0.value.sorted {
            if $0.width != $1.width { return $0.width > $1.width }
            if $0.height != $1.height { return $0.height > $1.height }
            return $0.pixelWidth > $1.pixelWidth
        }) }.sorted {
            let first = $0.modes.first?.refreshRate ?? 0
            let second = $1.modes.first?.refreshRate ?? 0
            return first > second
        }
    }

    private static func refreshLabel(_ rate: Double) -> String {
        guard rate.isFinite, rate > 0 else { return "System-Managed Refresh" }
        // Preserve fractional rates such as 59.94 and 119.88 instead of merging them with 60/120.
        let hundredths = (rate * 100).rounded() / 100
        return hundredths.formatted(.number.precision(.fractionLength(0...2))) + " Hz"
    }

    private static func label(_ mode: CGDisplayMode) -> String {
        "\(mode.width) × \(mode.height) · " + refreshLabel(mode.refreshRate) + (mode.pixelWidth > mode.width ? " · HiDPI" : "")
    }

    private func reload() {
        let available = CGDisplayCopyAllDisplayModes(displayID, nil) as? [CGDisplayMode] ?? []
        var seen = Set<String>()
        modes = available.filter { seen.insert(Self.label($0)).inserted }.sorted {
            if $0.width != $1.width { return $0.width > $1.width }
            if $0.height != $1.height { return $0.height > $1.height }
            return $0.refreshRate > $1.refreshRate
        }
        if let mode = CGDisplayCopyDisplayMode(displayID) {
            if !modes.contains(where: { $0.ioDisplayModeID == mode.ioDisplayModeID }) { modes.insert(mode, at: 0) }
            current = mode.ioDisplayModeID
            selection = current
        }
    }

    private func apply() {
        guard FeaturePreferences.shared.enabled(.modes) else { return }
        guard let mode = modes.first(where: { $0.ioDisplayModeID == selection }),
              let old = CGDisplayCopyDisplayMode(displayID) else { return }
        let result = CGDisplaySetDisplayMode(displayID, mode, nil)
        guard result == .success else { error = "macOS could not apply this mode (\(result.rawValue))."; return }
        error = nil
        previous = old
        confirming = true
        reverting?.cancel()
        reverting = Task { @MainActor in
            do { try await Task.sleep(for: .seconds(15)) } catch { return }
            revert()
            confirming = false
        }
    }

    private func revert() {
        reverting?.cancel()
        if let previous {
            let result = CGDisplaySetDisplayMode(displayID, previous, nil)
            if result != .success { error = "macOS could not restore the previous mode (\(result.rawValue))." }
        }
        previous = nil
        reload()
    }
}
