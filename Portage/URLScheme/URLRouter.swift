import Foundation

enum URLAction: Sendable, Equatable {
    case activatePreset(name: String?, id: String?)
    case switchInput(monitor: String, input: String)
    case listMonitors
    case listPresets
    case unknown(path: String)
}

enum URLRouter {
    static func parse(_ url: URL) -> URLAction? {
        guard url.scheme == "portagedisplay" else { return nil }

        guard let path = url.host(), !path.isEmpty else { return nil }
        let params = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.reduce(into: [String: String]()) {
                if let value = $1.value, !value.isEmpty { $0[$1.name] = value }
            } ?? [:]

        switch path {
        case "activate-preset":
            guard params["name"] != nil || params["id"] != nil else { return nil }
            return .activatePreset(name: params["name"], id: params["id"])
        case "switch-input":
            guard let monitor = params["monitor"], let input = params["input"] else { return nil }
            return .switchInput(monitor: monitor, input: input)
        case "list-monitors":
            return .listMonitors
        case "list-presets":
            return .listPresets
        default:
            return .unknown(path: path)
        }
    }
}
