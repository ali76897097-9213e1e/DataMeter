import XCTest
@testable import DataMeterCore

final class NetworkIdentityProviderTests: XCTestCase {
    func testUsesDefaultRouteBeforeWiFiSSID() async {
        let shell = StubShellClient(outputs: [
            "/usr/sbin/networksetup -listallhardwareports": """
            Hardware Port: Ethernet
            Device: en5
            Ethernet Address: 00:00:00:00:00:01

            Hardware Port: Wi-Fi
            Device: en0
            Ethernet Address: 00:00:00:00:00:02
            """,
            "/sbin/route -n get default": """
               route to: default
            destination: default
                   mask: default
                gateway: 192.168.1.1
              interface: en5
            """,
            "/usr/sbin/networksetup -getairportnetwork en0": "Current Wi-Fi Network: Home"
        ])
        let provider = NetworkIdentityProvider(shell: shell, cacheTTL: 0)

        let network = await provider.currentNetworkName()

        XCTAssertEqual(network, "Ethernet (en5)")
    }

    func testShowsSSIDWhenDefaultRouteIsWiFi() async {
        let shell = StubShellClient(outputs: [
            "/usr/sbin/networksetup -listallhardwareports": """
            Hardware Port: Wi-Fi
            Device: en1
            Ethernet Address: 00:00:00:00:00:02
            """,
            "/sbin/route -n get default": """
               route to: default
            destination: default
              interface: en1
            """,
            "/usr/sbin/networksetup -getairportnetwork en1": "Current Wi-Fi Network: Home"
        ])
        let provider = NetworkIdentityProvider(shell: shell, cacheTTL: 0)

        let network = await provider.currentNetworkName()

        XCTAssertEqual(network, "Wi‑Fi: Home")
    }

    func testRouteIsCheckedEveryTimeButHardwarePortInventoryUsesTTL() async throws {
        let shell = SequencedShellClient(outputs: [
            "/usr/sbin/networksetup -listallhardwareports": [
                """
                Hardware Port: Wi-Fi
                Device: en1
                Ethernet Address: 00:00:00:00:00:02
                """,
                """
                Hardware Port: Ethernet
                Device: en5
                Ethernet Address: 00:00:00:00:00:03
                """
            ],
            "/sbin/route -n get default": [
                "interface: en1",
                "interface: en5"
            ],
            "/usr/sbin/networksetup -getairportnetwork en1": [
                "Current Wi-Fi Network: Home"
            ]
        ])
        let provider = NetworkIdentityProvider(shell: shell, cacheTTL: 60)

        let first = await provider.currentNetworkName()
        let second = await provider.currentNetworkName()
        XCTAssertEqual(first, "Wi‑Fi: Home")
        XCTAssertEqual(second, "Ethernet (en5)")
        XCTAssertEqual(shell.callCount(for: "/sbin/route -n get default"), 2)
        XCTAssertEqual(shell.callCount(for: "/usr/sbin/networksetup -listallhardwareports"), 2)

        let expiringProvider = NetworkIdentityProvider(shell: shell, cacheTTL: 0)
        let refreshed = await expiringProvider.currentNetworkName()
        XCTAssertEqual(refreshed, "Ethernet (en5)")
    }
}

private final class SequencedShellClient: ShellClient, @unchecked Sendable {
    private let lock = NSLock()
    private var outputs: [String: [String]]
    private var callCounts: [String: Int] = [:]

    init(outputs: [String: [String]]) {
        self.outputs = outputs
    }

    func run(_ executable: String, args: [String]) async throws -> String {
        try runSync(executable, args: args)
    }

    func runSync(_ executable: String, args: [String]) throws -> String {
        let key = ([executable] + args).joined(separator: " ")
        lock.lock()
        defer { lock.unlock() }
        callCounts[key, default: 0] += 1
        guard var values = outputs[key], let first = values.first else { return "" }
        if values.count > 1 {
            values.removeFirst()
            outputs[key] = values
        }
        return first
    }

    func callCount(for key: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return callCounts[key, default: 0]
    }
}

private struct StubShellClient: ShellClient {
    let outputs: [String: String]

    func run(_ executable: String, args: [String]) async throws -> String {
        try runSync(executable, args: args)
    }

    func runSync(_ executable: String, args: [String]) throws -> String {
        outputs[([executable] + args).joined(separator: " ")] ?? ""
    }
}
