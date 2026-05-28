import Foundation

public protocol NetworkIdentityProviding: Sendable {
    func currentNetworkName() -> String
}

public struct NetworkIdentityProvider: NetworkIdentityProviding {
    private let shell: ShellClient

    public init(shell: ShellClient = LiveShellClient()) {
        self.shell = shell
    }

    public func currentNetworkName() -> String {
        currentWiFiSSID() ?? defaultInterfaceName() ?? "Unknown Network"
    }

    private func defaultInterfaceName() -> String? {
        guard let route = try? shell.runSync("/sbin/route", args: ["-n", "get", "default"]) else { return nil }
        for line in route.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("interface:") {
                return trimmed.replacingOccurrences(of: "interface:", with: "").trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    private func currentWiFiSSID() -> String? {
        for interface in ["en0", "en1"] {
            guard let output = try? shell.runSync("/usr/sbin/networksetup", args: ["-getairportnetwork", interface]),
                  let range = output.range(of: ": ") else { continue }
            let ssid = String(output[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !ssid.isEmpty, !ssid.contains("not associated") {
                return "Wi‑Fi: \(ssid)"
            }
        }
        return nil
    }
}
