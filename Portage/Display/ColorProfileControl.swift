import SwiftUI
import ColorSync
import CoreGraphics

struct DisplayColorProfile: Identifiable {
    let url: URL
    let name: String
    var id: String { url.standardizedFileURL.path }
}

enum DisplayColorProfiles {
    static func currentURL(displayID: UInt32) -> URL? {
        guard let profile = ColorSyncProfileCreateWithDisplayID(displayID)?.takeRetainedValue() else { return nil }
        return ColorSyncProfileGetURL(profile, nil)?.takeUnretainedValue() as URL?
    }

    static func available(displayID: UInt32) -> [DisplayColorProfile] {
        let directories = [URL(fileURLWithPath: "/System/Library/ColorSync/Profiles"),
                           URL(fileURLWithPath: "/Library/ColorSync/Profiles"),
                           FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/ColorSync/Profiles")]
        var urls: [URL] = currentURL(displayID: displayID).map { [$0] } ?? []
        for directory in directories {
            if let files = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
                for case let url as URL in files where ["icc", "icm"].contains(url.pathExtension.lowercased()) { urls.append(url) }
            }
        }
        var seen = Set<String>()
        return urls.compactMap { url -> DisplayColorProfile? in
            autoreleasepool {
            guard seen.insert(url.standardizedFileURL.path).inserted,
                  let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
                  size <= 16 * 1024 * 1024,
                  let data = try? Data(contentsOf: url, options: .mappedIfSafe),
                  CGColorSpace(iccData: data as CFData)?.model == .rgb,
                  let profile = ColorSyncProfileCreateWithURL(url as CFURL, nil)?.takeRetainedValue() else { return nil }
            let name = ColorSyncProfileCopyDescriptionString(profile)?.takeRetainedValue() as String? ?? url.deletingPathExtension().lastPathComponent
            return DisplayColorProfile(url: url, name: name)
            }
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func apply(displayID: UInt32, url: URL?) -> Bool {
        guard CGDisplayIsOnline(displayID) != 0,
              let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue() else { return false }
        guard let defaultKey = kColorSyncDeviceDefaultProfileID?.takeUnretainedValue(),
              let deviceClass = kColorSyncDisplayDeviceClass?.takeUnretainedValue() else { return false }
        let info: [String: Any] = [defaultKey as String: url.map { $0 as Any } ?? NSNull()]
        return ColorSyncDeviceSetCustomProfiles(deviceClass, uuid, info as CFDictionary)
    }
}

struct ColorProfileControl: View {
    let displayID: UInt32
    @State private var profiles: [DisplayColorProfile] = []
    @State private var current = ""
    @State private var selection = ""
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if profiles.isEmpty {
                Text("No RGB display profiles are available.").font(.caption).foregroundStyle(.secondary)
            } else {
                Picker("Color profile", selection: $selection) {
                    ForEach(profiles) { profile in Text(profile.name).tag(profile.id) }
                }.labelsHidden().frame(maxWidth: .infinity)
                HStack {
                    Button("Restore Factory") { apply(nil) }.buttonStyle(.borderless)
                    Spacer()
                    Button("Apply") {
                        if let profile = profiles.first(where: { $0.id == selection }) { apply(profile.url) }
                    }.buttonStyle(.glass).disabled(current == selection)
                }
            }
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
        }
        .task(id: displayID) { reload() }
    }

    private func reload() {
        profiles = DisplayColorProfiles.available(displayID: displayID)
        current = DisplayColorProfiles.currentURL(displayID: displayID)?.standardizedFileURL.path ?? ""
        selection = profiles.contains(where: { $0.id == current }) ? current : profiles.first?.id ?? ""
    }

    private func apply(_ url: URL?) {
        guard FeaturePreferences.shared.enabled(.profiles) else { return }
        if DisplayColorProfiles.apply(displayID: displayID, url: url) { error = nil; reload() }
        else { error = "macOS could not apply this color profile." }
    }
}
