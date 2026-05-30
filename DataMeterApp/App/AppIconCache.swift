import AppKit
import DataMeterCore

@MainActor
final class AppIconCache {
    static let shared = AppIconCache()

    private var iconsByIdentityKey: [String: NSImage] = [:]
    private let maximumCachedIcons = 128
    private let genericIcon = NSImage(named: NSImage.applicationIconName) ?? NSWorkspace.shared.icon(for: .application)

    private init() {}

    func icon(for record: UsageRecord) -> NSImage {
        icon(forAppIdentifier: record.appIdentifier, appName: record.appName)
    }

    func icon(forAppIdentifier appIdentifier: String, appName: String) -> NSImage {
        let cacheKey = iconCacheKey(appIdentifier: appIdentifier, appName: appName)
        if let icon = iconsByIdentityKey[cacheKey] {
            return icon
        }

        if let bundleURL = bundleURL(appIdentifier: appIdentifier, appName: appName) {
            storeIcon(forKey: cacheKey, bundleURL: bundleURL)
            return iconsByIdentityKey[cacheKey] ?? genericIcon
        }

        return genericIcon
    }

    func setIcon(forAppIdentifier appIdentifier: String, appName: String, bundleURL: URL?) {
        guard let bundleURL, bundleURL.pathExtension == "app" else { return }
        storeIcon(forKey: iconCacheKey(appIdentifier: appIdentifier, appName: appName), bundleURL: bundleURL)
    }

    private func storeIcon(forKey cacheKey: String, bundleURL: URL) {
        let icon = NSWorkspace.shared.icon(forFile: bundleURL.path)
        icon.size = NSSize(width: 18, height: 18)
        if iconsByIdentityKey.count >= maximumCachedIcons {
            iconsByIdentityKey.removeAll(keepingCapacity: true)
        }
        iconsByIdentityKey[cacheKey] = icon
    }

    private func bundleURL(appIdentifier: String, appName: String) -> URL? {
        if let iconBundleIdentifier = AppAttributionCatalog.iconBundleIdentifier(for: appIdentifier, displayName: appName),
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: iconBundleIdentifier) {
            return url
        }

        if appIdentifier.contains("."),
           !appIdentifier.hasPrefix("process:"),
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: appIdentifier) {
            return url
        }

        return applicationURL(named: appName, in: "/Applications")
            ?? applicationURL(named: appName, in: "/System/Applications")
    }

    private func applicationURL(named appName: String, in directory: String) -> URL? {
        let url = URL(fileURLWithPath: directory).appendingPathComponent("\(appName).app")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private func iconCacheKey(appIdentifier: String, appName: String) -> String {
        "\(appIdentifier)|\(appName)"
    }
}
