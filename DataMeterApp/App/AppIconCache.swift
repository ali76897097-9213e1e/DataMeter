import AppKit

@MainActor
final class AppIconCache {
    static let shared = AppIconCache()

    private var iconsByAppName: [String: NSImage] = [:]
    private let genericIcon = NSWorkspace.shared.icon(for: .application)

    private init() {}

    func icon(for appName: String) -> NSImage {
        iconsByAppName[appName] ?? genericIcon
    }

    func setIcon(for appName: String, bundleURL: URL?) {
        guard let bundleURL else { return }
        let icon = NSWorkspace.shared.icon(forFile: bundleURL.path)
        icon.size = NSSize(width: 18, height: 18)
        iconsByAppName[appName] = icon
    }
}
