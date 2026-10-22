import SwiftUI

private struct MenuContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

struct PanelContentView: View {
    let monitorStore: MonitorStore
    let presetStore: PresetStore
    let toastState: ToastState
    let onDismiss: () -> Void
    var onSizeChange: ((CGSize) -> Void)? = nil
    @AppStorage("menu.displayScope") private var displayScope = MenuDisplayScope.all.rawValue
    @AppStorage("menu.hiddenDisplayIDs") private var hiddenDisplayData = Data()
    @State private var contentHeight: CGFloat = 160
    @AppStorage("menu.presetsExpanded") private var presetsExpanded = false
    @AppStorage("menu.rememberLayout") private var rememberLayout = true
    @AppStorage("menu.sectionStates") private var sectionData = Data()
    private let preferences = FeaturePreferences.shared
    @AppStorage("menu.expandedDisplayIDs") private var expandedData = Data()
    @AppStorage("menu.singleExpandedDisplay") private var singleExpanded = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var visibleMonitors: [MonitorConfig] {
        let scope = MenuDisplayScope(rawValue: displayScope) ?? .all
        let hidden = Set((try? JSONDecoder().decode([String].self, from: hiddenDisplayData)) ?? [])
        return monitorStore.monitors.filter { scope.includes($0, hiddenIDs: hidden) }
    }
    private var visibleExpandedIDs: Set<String> { expandedIDs.intersection(visibleMonitors.map(\.id)) }
    private var displayCountLabel: String {
        let visible = visibleMonitors.count
        let total = monitorStore.monitors.count
        return visible == total ? "\(total) \(total == 1 ? "display" : "displays")" : "\(visible) of \(total) displays"
    }
    private var expandedIDs: Set<String> { Set((try? JSONDecoder().decode([String].self, from: expandedData)) ?? []) }
    private var maximumBodyHeight: CGFloat {
        min(620, (NSScreen.screens.map { $0.visibleFrame.height }.min() ?? 800) - 160)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text("Portage").font(.headline)
                Text(displayCountLabel).font(.caption).foregroundStyle(.secondary)
                Spacer()
                if monitorStore.isDiscovering {
                    ProgressView().controlSize(.small).accessibilityLabel("Refreshing monitors")
                } else {
                    Button {
                        Task { await monitorStore.discover() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless).help("Refresh monitors").accessibilityLabel("Refresh monitors")
                }
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                        setExpanded(visibleExpandedIDs.isEmpty ? Set(visibleMonitors.map(\.id)) : [])
                    }
                } label: {
                    Image(
                        systemName: visibleExpandedIDs.isEmpty
                            ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                }
                .buttonStyle(.borderless).help(
                    visibleExpandedIDs.isEmpty ? "Expand all displays" : "Collapse all displays"
                )
                .accessibilityLabel(visibleExpandedIDs.isEmpty ? "Expand all displays" : "Collapse all displays")
                .disabled(visibleMonitors.isEmpty)
            }.padding(.horizontal, 18).padding(.vertical, 12)
            Divider().padding(.horizontal, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if monitorStore.monitors.isEmpty {
                        ContentUnavailableView(
                            "No displays detected", systemImage: "display",
                            description: Text("Connect a display or refresh to try again."))
                    }
                    if !monitorStore.monitors.isEmpty, visibleMonitors.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "eye.slash").font(.title2).foregroundStyle(.secondary)
                            Text("No displays shown").font(.headline)
                            Text("Choose which displays appear in Settings → Menu Bar.")
                                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        }.frame(maxWidth: .infinity).padding(16)
                    }
                    ForEach(visibleMonitors) { monitor in
                        MonitorRow(
                            monitor: monitor, monitorStore: monitorStore, expanded: expandedIDs.contains(monitor.id)
                        ) {
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                                var ids = expandedIDs
                                if ids.contains(monitor.id) {
                                    ids.remove(monitor.id)
                                } else {
                                    if singleExpanded { ids = [] }
                                    ids.insert(monitor.id)
                                }
                                setExpanded(ids)
                            }
                        }
                    }
                    if preferences.shown(.presets), !presetStore.presets.isEmpty {
                        DisclosureGroup(isExpanded: $presetsExpanded) {
                            ForEach(presetStore.presets) { preset in
                                PresetRow(preset: preset) { Task { await presetStore.activate(preset: preset) } }
                            }
                        } label: {
                            HStack {
                                Label("Presets", systemImage: "rectangle.stack")
                                Spacer()
                                Text("\(presetStore.presets.count)").foregroundStyle(.secondary)
                            }
                        }.padding(12)
                    }
                }
                .padding(10)
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: MenuContentHeightKey.self, value: proxy.size.height)
                    })
            }
            .frame(height: min(max(contentHeight, 72), max(140, maximumBodyHeight)))
            .onPreferenceChange(MenuContentHeightKey.self) { height in
                if abs(contentHeight - height) > 1 { contentHeight = height }
            }
            Divider().padding(.horizontal, 16)
            HStack {
                Button {
                    onDismiss()
                    NotificationCenter.default.post(name: .portageOpenSettings, object: nil)
                } label: {
                    Label("Settings…", systemImage: "gearshape")
                }.buttonStyle(.borderless)
                    .keyboardShortcut(",", modifiers: .command)
                Spacer()
                Text("⌘,").font(.caption).foregroundStyle(.tertiary).accessibilityHidden(true)
            }.padding(.horizontal, 16).padding(.vertical, 10)
        }
        .disclosureGroupStyle(.fullRow)
        .frame(width: 400)
        .fixedSize(horizontal: false, vertical: true)
        .background(reduceTransparency ? Color(nsColor: .windowBackgroundColor) : .clear)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
        .onGeometryChange(for: CGSize.self, of: { $0.size }) { size in
            Task { @MainActor in onSizeChange?(size) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .portageMenuClosed)) { _ in
            if !rememberLayout {
                presetsExpanded = false
                sectionData = Data()
                setExpanded([])
            }
        }
        .onKeyPress(.escape) {
            onDismiss()
            return .handled
        }
        .overlay(alignment: .bottom) {
            if let toast = toastState.currentToast {
                ToastView(message: toast) { toastState.dismiss() }.padding(12).transition(.opacity)
            }
        }
    }

    private func setExpanded(_ ids: Set<String>) {
        expandedData = (try? JSONEncoder().encode(Array(ids).sorted())) ?? Data()
    }
}

extension Notification.Name {
    static let portageOpenSettings = Notification.Name("Portage.openSettings")
    static let portageMenuClosed = Notification.Name("Portage.menuClosed")
}
