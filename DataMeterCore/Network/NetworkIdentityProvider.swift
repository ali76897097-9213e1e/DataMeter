import Foundation

public protocol NetworkIdentityProviding: Sendable {
    func currentNetworkName() async -> String
}

public final class NetworkIdentityProvider: NetworkIdentityProviding, @unchecked Sendable {
    private let shell: ShellClient
    private let cache = NetworkIdentityCache()
    private let cacheTTL: TimeInterval

    public init(shell: ShellClient = LiveShellClient(), cacheTTL: TimeInterval = 30) {
        self.shell = shell
        self.cacheTTL = cacheTTL
    }

    public func currentNetworkName() async -> String {
        await Task.detached(priority: .utility) { [shell, cache, cacheTTL] in
            let hardwarePorts = cache.hardwarePorts(maxAge: cacheTTL) ?? Self.loadHardwarePorts(shell: shell)
            cache.setHardwarePorts(hardwarePorts)

            guard let defaultInterface = Self.defaultInterfaceName(shell: shell) else {
                return "Unknown Network"
            }

            let matchingPort = hardwarePorts.first(where: { $0.device == defaultInterface }) ?? {
                let refreshedPorts = Self.loadHardwarePorts(shell: shell)
                cache.setHardwarePorts(refreshedPorts)
                return refreshedPorts.first(where: { $0.device == defaultInterface })
            }()

            if let matchingPort {
                if matchingPort.isWiFi {
                    if let ssid = Self.currentWiFiSSID(shell: shell, interface: defaultInterface) {
                        return "Wi‑Fi: \(ssid)"
                    }
                    return "Wi‑Fi"
                }

                return "\(matchingPort.name) (\(defaultInterface))"
            }

            return defaultInterface
        }.value
    }

    private static func defaultInterfaceName(shell: ShellClient) -> String? {
        guard let route = try? shell.runSync("/sbin/route", args: ["-n", "get", "default"]) else { return nil }
        for line in route.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("interface:") {
                return trimmed.replacingOccurrences(of: "interface:", with: "").trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    private static func currentWiFiSSID(shell: ShellClient, interface: String) -> String? {
        guard let output = try? shell.runSync("/usr/sbin/networksetup", args: ["-getairportnetwork", interface]),
              let range = output.range(of: ": ") else { return nil }
        let ssid = String(output[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        if !ssid.isEmpty, !ssid.localizedCaseInsensitiveContains("not associated") {
            return ssid
        }
        return nil
    }

    private static func loadHardwarePorts(shell: ShellClient) -> [HardwarePort] {
        guard let output = try? shell.runSync("/usr/sbin/networksetup", args: ["-listallhardwareports"]) else { return [] }
        var ports: [HardwarePort] = []
        var currentName: String?

        for line in output.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            if line.hasPrefix("Hardware Port: ") {
                currentName = String(line.dropFirst("Hardware Port: ".count))
            } else if line.hasPrefix("Device: "), let currentName {
                let device = String(line.dropFirst("Device: ".count))
                ports.append(HardwarePort(name: currentName, device: device))
            }
        }

        return ports
    }
}

private struct HardwarePort: Sendable {
    let name: String
    let device: String

    var isWiFi: Bool {
        let normalized = name.lowercased()
        return normalized == "wi-fi" || normalized == "wifi" || normalized == "airport"
    }
}

private final class NetworkIdentityCache: @unchecked Sendable {
    private let lock = NSLock()
    private var hardwarePortsValue: [HardwarePort]?
    private var hardwarePortsResolvedAt: Date?

    func hardwarePorts(maxAge: TimeInterval) -> [HardwarePort]? {
        lock.lock()
        defer { lock.unlock() }
        guard let hardwarePortsValue, let hardwarePortsResolvedAt else { return nil }
        return Date().timeIntervalSince(hardwarePortsResolvedAt) <= maxAge ? hardwarePortsValue : nil
    }

    func setHardwarePorts(_ ports: [HardwarePort]) {
        lock.lock()
        hardwarePortsValue = ports
        hardwarePortsResolvedAt = Date()
        lock.unlock()
    }
}
