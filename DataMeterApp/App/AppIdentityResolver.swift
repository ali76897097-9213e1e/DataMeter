import AppKit
import DataMeterCore

@MainActor
struct AppIdentityResolver {
    func resolve(_ snapshots: [ProcessSnapshot]) -> [ProcessSnapshot] {
        snapshots.map(resolve)
    }

    func resolve(_ snapshot: ProcessSnapshot) -> ProcessSnapshot {
        if let appName = appNameForRunningApplication(pid: snapshot.pid) {
            return snapshot.withAppName(appName)
        }

        if let groupedName = groupedFallbackName(for: snapshot.processName) {
            return snapshot.withAppName(groupedName)
        }

        return snapshot
    }

    private func appNameForRunningApplication(pid: Int32?) -> String? {
        guard let pid, let app = NSRunningApplication(processIdentifier: pid) else { return nil }
        let appName: String?
        if let localizedName = app.localizedName, !localizedName.isEmpty {
            appName = localizedName
        } else if let bundleName = app.bundleURL?.deletingPathExtension().lastPathComponent, !bundleName.isEmpty {
            appName = bundleName
        } else {
            appName = nil
        }

        if let appName {
            let displayName = groupedFallbackName(for: appName) ?? appName
            AppIconCache.shared.setIcon(for: displayName, bundleURL: app.bundleURL)
            return displayName
        }
        return appName
    }

    private func groupedFallbackName(for processName: String) -> String? {
        let lowercased = processName.lowercased()

        if lowercased == "safari networking" || lowercased.hasPrefix("safari ") {
            return "Safari"
        }

        if lowercased.hasPrefix("com.apple.webkit") || lowercased.contains("webkit") {
            return "Safari/WebKit"
        }

        if lowercased.hasPrefix("google chrome") {
            return "Google Chrome"
        }

        if lowercased.hasPrefix("microsoft edge") {
            return "Microsoft Edge"
        }

        if lowercased.hasPrefix("firefox") {
            return "Firefox"
        }

        if lowercased.hasPrefix("electron") {
            return "Electron"
        }

        return nil
    }
}
