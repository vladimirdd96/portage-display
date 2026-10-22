import Testing

@testable import Portage

@Suite("URLRouter")
struct URLRouterTests {
    @Test("Parses activate-preset with name")
    func activatePresetByName() {
        let url = URL(string: "portagedisplay://activate-preset?name=Work")!
        let action = URLRouter.parse(url)
        #expect(action == .activatePreset(name: "Work", id: nil))
    }

    @Test("Parses activate-preset with id")
    func activatePresetByID() {
        let uuid = "550E8400-E29B-41D4-A716-446655440000"
        let url = URL(string: "portagedisplay://activate-preset?id=\(uuid)")!
        let action = URLRouter.parse(url)
        #expect(action == .activatePreset(name: nil, id: uuid))
    }

    @Test("Parses activate-preset with both name and id")
    func activatePresetBothParams() {
        let url = URL(string: "portagedisplay://activate-preset?name=Work&id=some-uuid")!
        let action = URLRouter.parse(url)
        #expect(action == .activatePreset(name: "Work", id: "some-uuid"))
    }

    @Test("Returns nil for activate-preset without name or id")
    func activatePresetMissingParams() {
        let url = URL(string: "portagedisplay://activate-preset")!
        let action = URLRouter.parse(url)
        #expect(action == nil)
    }

    @Test("Parses switch-input with monitor and input")
    func switchInput() {
        let url = URL(string: "portagedisplay://switch-input?monitor=Dell&input=HDMI-1")!
        let action = URLRouter.parse(url)
        #expect(action == .switchInput(monitor: "Dell", input: "HDMI-1"))
    }

    @Test("Returns nil for switch-input missing monitor")
    func switchInputMissingMonitor() {
        let url = URL(string: "portagedisplay://switch-input?input=HDMI-1")!
        let action = URLRouter.parse(url)
        #expect(action == nil)
    }

    @Test("Returns nil for switch-input missing input")
    func switchInputMissingInput() {
        let url = URL(string: "portagedisplay://switch-input?monitor=Dell")!
        let action = URLRouter.parse(url)
        #expect(action == nil)
    }

    @Test("Parses list-monitors")
    func listMonitors() {
        let url = URL(string: "portagedisplay://list-monitors")!
        let action = URLRouter.parse(url)
        #expect(action == .listMonitors)
    }

    @Test("Parses list-presets")
    func listPresets() {
        let url = URL(string: "portagedisplay://list-presets")!
        let action = URLRouter.parse(url)
        #expect(action == .listPresets)
    }

    @Test("Returns unknown for unrecognized path")
    func unknownPath() {
        let url = URL(string: "portagedisplay://unknown-action")!
        let action = URLRouter.parse(url)
        #expect(action == .unknown(path: "unknown-action"))
    }

    @Test("Returns nil for wrong scheme")
    func wrongScheme() {
        let url = URL(string: "https://example.com")!
        let action = URLRouter.parse(url)
        #expect(action == nil)
    }

    @Test("Handles URL-encoded parameter values")
    func urlEncodedParams() {
        let url = URL(string: "portagedisplay://switch-input?monitor=My%20Dell&input=HDMI-1")!
        let action = URLRouter.parse(url)
        #expect(action == .switchInput(monitor: "My Dell", input: "HDMI-1"))
    }

    @Test("Returns nil for bare scheme with no path")
    func bareScheme() {
        let url = URL(string: "portagedisplay://")!
        let action = URLRouter.parse(url)
        #expect(action == nil)
    }

    @Test("Rejects empty string parameter values")
    func emptyParams() {
        let url = URL(string: "portagedisplay://activate-preset?name=")!
        #expect(URLRouter.parse(url) == nil)

        let url2 = URL(string: "portagedisplay://switch-input?monitor=Dell&input=")!
        #expect(URLRouter.parse(url2) == nil)
    }
}
