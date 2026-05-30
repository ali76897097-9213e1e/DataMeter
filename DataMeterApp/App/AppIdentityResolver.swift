import AppKit
import DataMeterCore

@MainActor
final class AppIdentityResolver {
    static let shared = AppIdentityResolver()

    private var appIdentityByProcessKey: [String: (identifier: String, name: String)] = [:]
    private var unresolvedProcessKeys: Set<String> = []
    private let maximumCachedProcessKeys = 512

    private init() {}

    func resolve(_ snapshots: [ProcessSnapshot]) -> [ProcessSnapshot] {
        pruneCaches(keeping: Set(snapshots.map(\.key)))
        return snapshots.map(resolve)
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
        if let attribution = AppAttributionCatalog.attribution(forProcessName: snapshot.processName) {
            return snapshot.withAppIdentity(identifier: attribution.identifier, name: attribution.displayName)
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
            if let attribution = AppAttributionCatalog.attribution(forProcessName: appName) {
                return (attribution.identifier, attribution.displayName)
            }

            if let bundleIdentifier = app.bundleIdentifier {
                AppIconCache.shared.setIcon(forAppIdentifier: bundleIdentifier, appName: appName, bundleURL: app.bundleURL)
            }
            let identifier = app.bundleIdentifier ?? app.bundleURL?.path ?? "process:\(appName)"
            return (identifier, appName)
        }
        return nil
    }

    private func pruneCaches(keeping activeKeys: Set<String>) {
        guard appIdentityByProcessKey.count + unresolvedProcessKeys.count > maximumCachedProcessKeys else { return }
        appIdentityByProcessKey = appIdentityByProcessKey.filter { activeKeys.contains($0.key) }
        unresolvedProcessKeys = unresolvedProcessKeys.intersection(activeKeys)
    }
}
