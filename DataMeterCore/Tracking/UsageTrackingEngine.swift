import Foundation

public protocol ProcessSnapshotResolving: Sendable {
    func resolve(_ snapshots: [ProcessSnapshot]) async -> [ProcessSnapshot]
}

public struct PassthroughProcessSnapshotResolver: ProcessSnapshotResolving {
    public init() {}

    public func resolve(_ snapshots: [ProcessSnapshot]) async -> [ProcessSnapshot] {
        snapshots
    }
}

public struct UsageQuery: Sendable {
    public let timeRange: UsageTimeRange
    public let networkName: String?
    public let filterText: String
    public let sessionStartedAt: Date
    public let now: Date

    public init(timeRange: UsageTimeRange, networkName: String?, filterText: String, sessionStartedAt: Date, now: Date = Date()) {
        self.timeRange = timeRange
        self.networkName = networkName
        self.filterText = filterText
        self.sessionStartedAt = sessionStartedAt
        self.now = now
    }
}

public struct UsageTrackingState: Sendable {
    public let records: [UsageRecord]
    public let networks: [String]
    public let currentNetwork: String
    public let processCount: Int
    public let totalDownloaded: UInt64
    public let totalUploaded: UInt64

    public var totalUsage: UInt64 { totalDownloaded + totalUploaded }

    public init(records: [UsageRecord], networks: [String], currentNetwork: String, processCount: Int) {
        self.records = records
        self.networks = networks
        self.currentNetwork = currentNetwork
        self.processCount = processCount
        self.totalDownloaded = records.reduce(0) { $0 + $1.downloaded }
        self.totalUploaded = records.reduce(0) { $0 + $1.uploaded }
    }
}

public actor UsageTrackingEngine {
    private let sampler: UsageSampler
    private let repository: UsageHistoryRepository
    private let networkProvider: NetworkIdentityProviding
    private let processResolver: ProcessSnapshotResolving
    private var accumulator = UsageAccumulator()
    private var currentNetworkSessionID: Int64?
    private var currentNetworkSessionName: String?
    private var cachedNetworks: [String]?
    private var cachedRecordsByQuery: [UsageQueryCacheKey: [UsageRecord]] = [:]
    private var lastMaintenanceAt: Date?

    public init(
        sampler: UsageSampler,
        repository: UsageHistoryRepository,
        networkProvider: NetworkIdentityProviding,
        processResolver: ProcessSnapshotResolving = PassthroughProcessSnapshotResolver()
    ) {
        self.sampler = sampler
        self.repository = repository
        self.networkProvider = networkProvider
        self.processResolver = processResolver
    }

    public func sample(query: UsageQuery) async throws -> UsageTrackingState {
        let startedAt = ContinuousClock.now
        try performMaintenanceIfNeeded(now: query.now)
        let network = await networkProvider.currentNetworkName()
        let networkChanged = currentNetworkSessionName != nil && currentNetworkSessionName != network
        try ensureNetworkSession(for: network)

        if networkChanged {
            accumulator.reset()
            cachedNetworks = nil
        }

        let snapshots = await processResolver.resolve(try await sampler.sample())
        try Task.checkCancellation()
        let deltas = accumulator.apply(snapshots: snapshots, network: network)
            .map { $0.withNetworkSessionID(currentNetworkSessionID) }
        if !deltas.isEmpty {
            try repository.record(deltas)
            cachedRecordsByQuery.removeAll()
        }

        try Task.checkCancellation()
        let state = try state(query: query, currentNetwork: network, processCount: snapshots.count)
        let duration = startedAt.duration(to: .now)
        DataMeterLog.sampling.debug("sample completed processes=\(snapshots.count) deltas=\(deltas.count) duration=\(duration.description, privacy: .public)")
        return state
    }

    public func state(query: UsageQuery, currentNetwork: String? = nil, processCount: Int = 0) throws -> UsageTrackingState {
        let records = try records(for: query)
        return UsageTrackingState(
            records: records,
            networks: try networks(),
            currentNetwork: currentNetwork ?? currentNetworkSessionName ?? "Unknown Network",
            processCount: processCount
        )
    }

    public func reset(query: UsageQuery) throws -> UsageTrackingState {
        let startDate = query.timeRange.startDate(sessionStartedAt: query.sessionStartedAt, now: query.now)
        try repository.reset(networkName: query.networkName, since: startDate)
        accumulator.reset(network: query.networkName)
        cachedNetworks = nil
        cachedRecordsByQuery.removeAll()
        return try state(query: query)
    }

    public func pause() throws {
        guard let currentNetworkSessionID else { return }
        try repository.finishNetworkSession(id: currentNetworkSessionID, endedAt: Date())
        self.currentNetworkSessionID = nil
        currentNetworkSessionName = nil
    }

    public func prepareForSleep() throws {
        try pause()
        accumulator.reset()
    }

    public func finishOpenSessions() throws {
        try repository.finishOpenNetworkSessions(endedAt: Date())
    }

    public func resetAccumulator() {
        accumulator.reset()
    }

    private func performMaintenanceIfNeeded(now: Date) throws {
        if let lastMaintenanceAt, now.timeIntervalSince(lastMaintenanceAt) < 24 * 60 * 60 { return }
        DataMeterLog.storage.debug("running usage maintenance")
        try repository.performMaintenance(now: now)
        lastMaintenanceAt = now
        cachedNetworks = nil
        cachedRecordsByQuery.removeAll()
    }

    private func records(for query: UsageQuery) throws -> [UsageRecord] {
        let key = UsageQueryCacheKey(query: query)
        if let cached = cachedRecordsByQuery[key] { return cached }
        let records = try repository.records(
            timeRange: query.timeRange,
            networkName: query.networkName,
            filterText: query.filterText,
            sessionStartedAt: query.sessionStartedAt,
            now: query.now
        )
        cachedRecordsByQuery[key] = records
        return records
    }

    private func networks() throws -> [String] {
        if let cachedNetworks { return cachedNetworks }
        let networks = try repository.networks()
        cachedNetworks = networks
        return networks
    }

    private func ensureNetworkSession(for network: String) throws {
        guard currentNetworkSessionID == nil || currentNetworkSessionName != network else { return }
        if let currentNetworkSessionID {
            try repository.finishNetworkSession(id: currentNetworkSessionID, endedAt: Date())
        }
        currentNetworkSessionID = try repository.startNetworkSession(networkName: network, startedAt: Date())
        currentNetworkSessionName = network
    }
}

private struct UsageQueryCacheKey: Hashable {
    let timeRange: UsageTimeRange
    let networkName: String?
    let filterText: String
    let sessionStartedAt: Date
    let rangeStartDate: Date?

    init(query: UsageQuery) {
        timeRange = query.timeRange
        networkName = query.networkName
        filterText = query.filterText
        sessionStartedAt = query.sessionStartedAt
        rangeStartDate = query.timeRange.startDate(sessionStartedAt: query.sessionStartedAt, now: query.now)
    }
}
