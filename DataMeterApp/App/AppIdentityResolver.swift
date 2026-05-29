import AppKit
import DataMeterCore

@MainActor
final class AppIdentityResolver {
    static let shared = AppIdentityResolver()

    private var appIdentityByProcessKey: [String: (identifier: String, name: String)] = [:]
    private var unresolvedProcessKeys: Set<String> = []

    private init() {}

    func resolve(_ snapshots: [ProcessSnapshot]) -> [ProcessSnapshot] {
        snapshots.map(resolve)
    }

    func resolve(_ snapshot: ProcessSnapshot) -> ProcessSnapshot {
        if let cachedIdentity = appIdentityByProcessKey[snapshot.key] {
            return snapshot.withAppIdentity(identifier: cachedIdentity.identifier, name: cachedIdentity.name)
        }

        if unresolvedProcessKeys.contains(snapshot.key) {
            return fallbackResolved(snapshot)
        }

        if let appIdentity = appIdentityForRunningApplication(pid: snapshot.pid) {
            appIdentityByProcessKey[snapshot.key] = appIdentity
            return snapshot.withAppIdentity(identifier: appIdentity.identifier, name: appIdentity.name)
        }

        let resolved = fallbackResolved(snapshot)
        if resolved.appName == snapshot.appName {
            unresolvedProcessKeys.insert(snapshot.key)
        } else {
            appIdentityByProcessKey[snapshot.key] = (resolved.appIdentifier, resolved.appName)
        }
        return resolved
    }

    private func fallbackResolved(_ snapshot: ProcessSnapshot) -> ProcessSnapshot {
        if let groupedName = groupedFallbackName(for: snapshot.processName) {
            return snapshot.withAppIdentity(identifier: "group:\(groupedName)", name: groupedName)
        }
        return snapshot.withAppIdentity(identifier: "process:\(snapshot.processName)", name: snapshot.appName)
    }

    private func appIdentityForRunningApplication(pid: Int32?) -> (identifier: String, name: String)? {
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
            let identifier = app.bundleIdentifier
                ?? app.bundleURL?.path
                ?? "process:\(displayName)"
            return (identifier, displayName)
        }
        return nil
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
