import SwiftUI

struct MenuBarView: View {
    @Environment(\.dismiss) private var dismiss
    let monitorStore: MonitorStore
    let presetStore: PresetStore

    var body: some View {
        PanelContentView(
            monitorStore: monitorStore,
            presetStore: presetStore,
            toastState: AppEnvironment.shared.toastState,
            onDismiss: { dismiss() }
        )
        .task { await monitorStore.discover() }
    }
}
