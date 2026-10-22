import Foundation

enum MenuDisplayScope: String, CaseIterable, Identifiable {
    case all, external, builtIn, custom
    var id: Self { self }
    var title: String {
        switch self {
        case .all: "All Displays"
        case .external: "External Only"
        case .builtIn: "Built-in Only"
        case .custom: "Custom"
        }
    }

    func includes(_ monitor: MonitorConfig, hiddenIDs: Set<String>) -> Bool {
        switch self {
        case .all: true
        case .external: !monitor.isBuiltIn
        case .builtIn: monitor.isBuiltIn
        case .custom: !hiddenIDs.contains(monitor.id)
        }
    }
}
