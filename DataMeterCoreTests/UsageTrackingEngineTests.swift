import XCTest
@testable import DataMeterCore

final class UsageTrackingEngineTests: XCTestCase {
    func testNetworkChangePrimesAccumulatorWithoutAttributingCrossNetworkDelta() async throws {
        let sampler = SequenceSampler(samples: [
            [ProcessSnapshot(key: "Safari.100", appName: "Safari", pid: 100, downloaded: 100, uploaded: 50)],
            [ProcessSnapshot(key: "Safari.100", appName: "Safari", pid: 100, downloaded: 300, uploaded: 150)],
            [ProcessSnapshot(key: "Safari.100", appName: "Safari", pid: 100, downloaded: 500, uploaded: 250)]
        ])
        let networkProvider = SequenceNetworkProvider(networks: ["Wi‑Fi: Home", "Wi‑Fi: Office", "Wi‑Fi: Office"])
        let repository = try SQLiteUsageRepository(url: temporaryDatabaseURL())
        let engine = UsageTrackingEngine(sampler: sampler, repository: repository, networkProvider: networkProvider)
        let query = UsageQuery(timeRange: .allTime, networkName: nil, filterText: "", sessionStartedAt: Date())

        _ = try await engine.sample(query: query)
        _ = try await engine.sample(query: query)
        let state = try await engine.sample(query: query)

        XCTAssertEqual(state.records.first?.downloaded, 200)
        XCTAssertEqual(state.records.first?.uploaded, 100)

        let officeRecords = try repository.records(timeRange: .allTime, networkName: "Wi‑Fi: Office", filterText: "", sessionStartedAt: Date(), now: Date())
        XCTAssertEqual(officeRecords.first?.downloaded, 200)
        XCTAssertEqual(officeRecords.first?.uploaded, 100)

        let homeRecords = try repository.records(timeRange: .allTime, networkName: "Wi‑Fi: Home", filterText: "", sessionStartedAt: Date(), now: Date())
        XCTAssertTrue(homeRecords.isEmpty)
    }

    func testPauseClosesCurrentNetworkSession() async throws {
        let sampler = SequenceSampler(samples: [
            [ProcessSnapshot(key: "Safari.100", appName: "Safari", pid: 100, downloaded: 100, uploaded: 50)]
        ])
        let networkProvider = SequenceNetworkProvider(networks: ["Wi‑Fi: Home"])
        let repository = TestUsageHistoryRepository()
        let engine = UsageTrackingEngine(sampler: sampler, repository: repository, networkProvider: networkProvider)
        let query = UsageQuery(timeRange: .allTime, networkName: nil, filterText: "", sessionStartedAt: Date())

        _ = try await engine.sample(query: query)
        try await engine.pause()

        XCTAssertEqual(repository.startedSessions, ["Wi‑Fi: Home"])
        XCTAssertEqual(repository.finishedSessionIDs, [1])
    }

    func testNoDeltaSampleReusesCachedRecords() async throws {
        let snapshots = [ProcessSnapshot(key: "Safari.100", appName: "Safari", pid: 100, downloaded: 100, uploaded: 50)]
        let sampler = SequenceSampler(samples: [snapshots, snapshots])
        let networkProvider = SequenceNetworkProvider(networks: ["Wi‑Fi: Home", "Wi‑Fi: Home"])
        let repository = TestUsageHistoryRepository(recordsToReturn: [UsageRecord(appName: "Safari", downloaded: 10, uploaded: 5)])
        let engine = UsageTrackingEngine(sampler: sampler, repository: repository, networkProvider: networkProvider)
        let query = UsageQuery(timeRange: .allTime, networkName: nil, filterText: "", sessionStartedAt: Date(timeIntervalSince1970: 0), now: Date(timeIntervalSince1970: 100))

        _ = try await engine.sample(query: query)
        _ = try await engine.sample(query: query)

        XCTAssertEqual(repository.recordsCallCount, 1)
        XCTAssertEqual(repository.recordedDeltaBatches.count, 0)
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

private final class TestUsageHistoryRepository: UsageHistoryRepository, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var startedSessions: [String] = []
    private(set) var finishedSessionIDs: [Int64] = []
    private(set) var recordedDeltaBatches: [[UsageDelta]] = []
    private(set) var recordsCallCount = 0
    private var nextSessionID: Int64 = 1
    private let recordsToReturn: [UsageRecord]

    init(recordsToReturn: [UsageRecord] = []) {
        self.recordsToReturn = recordsToReturn
    }

    func startNetworkSession(networkName: String, startedAt: Date) throws -> Int64 {
        lock.lock()
        defer { lock.unlock() }
        startedSessions.append(networkName)
        defer { nextSessionID += 1 }
        return nextSessionID
    }

    func finishNetworkSession(id: Int64, endedAt: Date) throws {
        lock.lock()
        finishedSessionIDs.append(id)
        lock.unlock()
    }

    func finishOpenNetworkSessions(endedAt: Date) throws {}

    func record(_ deltas: [UsageDelta]) throws {
        lock.lock()
        recordedDeltaBatches.append(deltas)
        lock.unlock()
    }

    func records(timeRange: UsageTimeRange, networkName: String?, filterText: String, sessionStartedAt: Date, now: Date) throws -> [UsageRecord] {
        lock.lock()
        recordsCallCount += 1
        lock.unlock()
        return recordsToReturn
    }

    func networks() throws -> [String] { [] }

    func reset(networkName: String?, since startDate: Date?) throws {}

    func performMaintenance(now: Date) throws {}
}
