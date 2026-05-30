import Foundation

struct AppAttribution: Hashable, Sendable {
    enum Kind: Sendable {
        case bundle
        case syntheticGroup
        case process
    }

    let identifier: String
    let displayName: String
    let kind: Kind
    let iconBundleIdentifier: String?
}

enum AppAttributionCatalog {
    static func attribution(forProcessName processName: String) -> AppAttribution? {
        let lowercased = processName.lowercased()

        if lowercased == "safari networking" || lowercased.hasPrefix("safari ") {
            return knownApp(named: "Safari")
        }

        if lowercased.hasPrefix("com.apple.webkit") || lowercased.contains("webkit") {
            return AppAttribution(
                identifier: "com.apple.WebKit",
                displayName: "Safari/WebKit",
                kind: .syntheticGroup,
                iconBundleIdentifier: "com.apple.Safari"
            )
        }

        if lowercased.hasPrefix("google chrome") {
            return knownApp(named: "Google Chrome")
        }

        if lowercased.hasPrefix("microsoft edge") {
            return knownApp(named: "Microsoft Edge")
        }

        if lowercased.hasPrefix("firefox") {
            return knownApp(named: "Firefox")
        }

        if lowercased.hasPrefix("io.tailscale") || lowercased == "tailscale" || lowercased == "tailscaled" {
            return knownApp(named: "Tailscale")
        }

        if lowercased.hasPrefix("electron") {
            return AppAttribution(
                identifier: "process:Electron",
                displayName: "Electron",
                kind: .process,
                iconBundleIdentifier: nil
            )
        }

        if systemServiceProcessNames.contains(lowercased) {
            return AppAttribution(
                identifier: "com.apple.system-services",
                displayName: "System Services",
                kind: .syntheticGroup,
                iconBundleIdentifier: nil
            )
        }

        return nil
    }

    static func knownApp(named displayName: String) -> AppAttribution? {
        guard let bundleIdentifier = knownBundleIdentifiersByDisplayName[displayName] else { return nil }
        return AppAttribution(
            identifier: bundleIdentifier,
            displayName: displayName,
            kind: .bundle,
            iconBundleIdentifier: bundleIdentifier
        )
    }

    static func iconBundleIdentifier(for identifier: String, displayName: String) -> String? {
        if let known = knownBundleIdentifiersByIdentifier[identifier] { return known }
        if let known = knownBundleIdentifiersByDisplayName[displayName] { return known }
        if identifier.contains(".") && !identifier.hasPrefix("process:") && !identifier.hasPrefix("group:") {
            return identifier
        }
        return nil
    }

    private static let knownBundleIdentifiersByDisplayName: [String: String] = [
        "Google Chrome": "com.google.Chrome",
        "Safari": "com.apple.Safari",
        "Tailscale": "io.tailscale.ipn.macos",
        "Visual Studio Code": "com.microsoft.VSCode",
        "Microsoft Edge": "com.microsoft.edgemac",
        "Firefox": "org.mozilla.firefox"
    ]

    private static let knownBundleIdentifiersByIdentifier: [String: String] = [
        "com.apple.WebKit": "com.apple.Safari"
    ]

    private static let systemServiceProcessNames: Set<String> = [
        "cfnetworkagent",
        "helpd",
        "mdnsresponder",
        "nsurlsessiond",
        "rapportd",
        "secd",
        "syspolicyd",
        "trustd"
    ]
}
