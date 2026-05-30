import XCTest
@testable import DataMeterCore

final class UsageTrackingEngineTests: XCTestCase {
    func testSamplesBecomeVisibleUsageTotalsAfterBaseline() async throws {
        let sampler = SequenceSampler(samples: [
            [ProcessSnapshot(key: "Safari.100", appIdentifier: "com.apple.Safari", appName: "Safari", pid: 100, downloaded: 100, uploaded: 50)],
            [ProcessSnapshot(key: "Safari.100", appIdentifier: "com.apple.Safari", appName: "Safari", pid: 100, downloaded: 350, uploaded: 125)]
        ])
        let repository = try SQLiteUsageRepository(url: temporaryDatabaseURL())
        let engine = UsageTrackingEngine(
            sampler: sampler,
            repository: repository,
            networkProvider: SequenceNetworkProvider(networks: ["Wi‑Fi: Home", "Wi‑Fi: Home"])
        )
        let query = UsageQuery(timeRange: .allTime, networkName: nil, filterText: "", sessionStartedAt: Date(timeIntervalSince1970: 0))

        _ = try await engine.sample(query: query)
        let state = try await engine.sample(query: query)

        XCTAssertEqual(state.records.count, 1)
        XCTAssertEqual(state.records[0].appIdentifier, "com.apple.Safari")
        XCTAssertEqual(state.records[0].appName, "Safari")
        XCTAssertEqual(state.records[0].downloaded, 250)
        XCTAssertEqual(state.records[0].uploaded, 75)
        XCTAssertEqual(state.totalDownloaded, 250)
        XCTAssertEqual(state.totalUploaded, 75)
    }

    func testNetworkSwitchDoesNotPolluteTheNewNetworkWithPreviousUsage() async throws {
        let sampler = SequenceSampler(samples: [
            [ProcessSnapshot(key: "Safari.100", appName: "Safari", pid: 100, downloaded: 100, uploaded: 50)],
            [ProcessSnapshot(key: "Safari.100", appName: "Safari", pid: 100, downloaded: 300, uploaded: 150)],
            [ProcessSnapshot(key: "Safari.100", appName: "Safari", pid: 100, downloaded: 500, uploaded: 250)]
        ])
        let repository = try SQLiteUsageRepository(url: temporaryDatabaseURL())
        let engine = UsageTrackingEngine(
            sampler: sampler,
            repository: repository,
            networkProvider: SequenceNetworkProvider(networks: ["Wi‑Fi: Home", "Wi‑Fi: Office", "Wi‑Fi: Office"])
        )
        let sessionStartedAt = Date(timeIntervalSince1970: 0)
        let query = UsageQuery(timeRange: .allTime, networkName: nil, filterText: "", sessionStartedAt: sessionStartedAt)

        _ = try await engine.sample(query: query)
        _ = try await engine.sample(query: query)
        let allNetworks = try await engine.sample(query: query)

        XCTAssertEqual(allNetworks.records.first?.downloaded, 200)
        XCTAssertEqual(allNetworks.records.first?.uploaded, 100)

        let office = try repository.records(timeRange: .allTime, networkName: "Wi‑Fi: Office", filterText: "", sessionStartedAt: sessionStartedAt, now: Date())
        let home = try repository.records(timeRange: .allTime, networkName: "Wi‑Fi: Home", filterText: "", sessionStartedAt: sessionStartedAt, now: Date())
        XCTAssertEqual(office.first?.downloaded, 200)
        XCTAssertEqual(office.first?.uploaded, 100)
        XCTAssertTrue(home.isEmpty)
    }

    func testProcessCounterResetDoesNotCreateVisibleUsage() async throws {
        let sampler = SequenceSampler(samples: [
            [ProcessSnapshot(key: "curl.42", appName: "curl", pid: 42, downloaded: 1_000, uploaded: 500)],
            [ProcessSnapshot(key: "curl.42", appName: "curl", pid: 42, downloaded: 10, uploaded: 5)]
        ])
        let repository = try SQLiteUsageRepository(url: temporaryDatabaseURL())
        let engine = UsageTrackingEngine(
            sampler: sampler,
            repository: repository,
            networkProvider: SequenceNetworkProvider(networks: ["en0", "en0"])
        )
        let query = UsageQuery(timeRange: .allTime, networkName: nil, filterText: "", sessionStartedAt: Date(timeIntervalSince1970: 0))

        _ = try await engine.sample(query: query)
        let state = try await engine.sample(query: query)

        XCTAssertTrue(state.records.isEmpty)
        XCTAssertEqual(state.totalDownloaded, 0)
        XCTAssertEqual(state.totalUploaded, 0)
    }

    func testPauseDoesNotRecordTrafficThatHappenedWhilePaused() async throws {
        let sampler = SequenceSampler(samples: [
            [ProcessSnapshot(key: "curl.42", appName: "curl", pid: 42, downloaded: 100, uploaded: 50)],
            [ProcessSnapshot(key: "curl.42", appName: "curl", pid: 42, downloaded: 300, uploaded: 150)],
            [ProcessSnapshot(key: "curl.42", appName: "curl", pid: 42, downloaded: 360, uploaded: 180)]
        ])
        let repository = try SQLiteUsageRepository(url: temporaryDatabaseURL())
        let engine = UsageTrackingEngine(
            sampler: sampler,
            repository: repository,
            networkProvider: SequenceNetworkProvider(networks: ["Wi‑Fi", "Wi‑Fi", "Wi‑Fi"])
        )
        let query = UsageQuery(timeRange: .allTime, networkName: nil, filterText: "", sessionStartedAt: Date(timeIntervalSince1970: 0))

        _ = try await engine.sample(query: query)
        try await engine.pause()
        _ = try await engine.sample(query: query)
        let state = try await engine.sample(query: query)

        XCTAssertEqual(state.records.first?.downloaded, 60)
        XCTAssertEqual(state.records.first?.uploaded, 30)
    }

    private func temporaryDatabaseURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("usage.sqlite")
    }
}

private actor SequenceSampler: UsageSampler {
    private var samples: [[ProcessSnapshot]]

    init(samples: [[ProcessSnapshot]]) {
        self.samples = samples
    }

    func sample() async throws -> [ProcessSnapshot] {
        if samples.isEmpty { return [] }
        return samples.removeFirst()
    }
}

private actor SequenceNetworkProvider: NetworkIdentityProviding {
    private var networks: [String]

    init(networks: [String]) {
        self.networks = networks
    }

    func currentNetworkName() async -> String {
        if networks.isEmpty { return "Unknown Network" }
        return networks.removeFirst()
    }
}
