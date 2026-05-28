import AppKit
import DataMeterCore
import Foundation

@MainActor
final class UsageViewModel: ObservableObject {
    @Published var records: [UsageRecord] = []
    @Published var filterText = ""
    @Published var selectedNetwork = "All Networks"
    @Published var networks: [String] = ["All Networks"]
    @Published var selectedTimeRange: UsageTimeRange = .today
    @Published var currentNetwork = "Unknown Network"
    @Published var isRunning = true
    @Published var status = "Starting…"
    @Published var totalDownloaded: UInt64 = 0
    @Published var totalUploaded: UInt64 = 0
    @Published var trackingStartedAt = Date()

    var totalUsage: UInt64 { totalDownloaded + totalUploaded }

    private let allNetworks = "All Networks"
    private let sampler: UsageSampler
    private let repository: UsageHistoryRepository
    private let networkProvider: NetworkIdentityProviding
    private let appIdentityResolver = AppIdentityResolver()
    private var accumulator = UsageAccumulator()
    private var timer: Timer?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var resumeAfterWake = false
    private var currentNetworkSessionID: Int64?
    private var currentNetworkSessionName: String?
    private let sessionStartedAt = Date()

    init(
        sampler: UsageSampler = NetTopSampler(),
        repository: UsageHistoryRepository? = nil,
        networkProvider: NetworkIdentityProviding = NetworkIdentityProvider()
    ) {
        self.sampler = sampler
        self.trackingStartedAt = sessionStartedAt
        self.repository = repository ?? (try! SQLiteUsageRepository())
        self.networkProvider = networkProvider
        try? self.repository.finishOpenNetworkSessions(endedAt: Date())
        refreshNetwork()
        recomputeNetworks()
        recomputeRecords()
        observeSleepWake()
        start()
    }


    func start() {
        isRunning = true
        status = "Tracking"
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.sample() }
        }
        Task { await sample() }
    }

    func pause() {
        isRunning = false
        status = "Paused"
        timer?.invalidate()
        timer = nil
    }

    func resetVisibleTotals() {
        do {
            try repository.reset(networkName: selectedNetworkName, since: selectedTimeRange.startDate(sessionStartedAt: sessionStartedAt))
            accumulator.reset(network: selectedNetworkName)
            recomputeNetworks()
            recomputeRecords()
        } catch {
            status = "Reset failed: \(error.localizedDescription)"
        }
    }

    func filtersChanged() {
        recomputeRecords()
    }

    func sample() async {
        guard isRunning else { return }
        refreshNetwork()
        do {
            try ensureNetworkSession()
            let snapshots = appIdentityResolver.resolve(try await sampler.sample())
            let deltas = accumulator.apply(snapshots: snapshots, network: currentNetwork)
                .map { $0.withNetworkSessionID(currentNetworkSessionID) }
            try repository.record(deltas)
            recomputeNetworks()
            recomputeRecords()
            status = "Tracking • \(snapshots.count) processes"
        } catch {
            status = "Tracking failed: \(error.localizedDescription)"
        }
    }

    private var selectedNetworkName: String? {
        selectedNetwork == allNetworks ? nil : selectedNetwork
    }

    private func refreshNetwork() {
        currentNetwork = networkProvider.currentNetworkName()
    }

    private func ensureNetworkSession() throws {
        guard currentNetworkSessionID == nil || currentNetworkSessionName != currentNetwork else { return }
        if let currentNetworkSessionID {
            try repository.finishNetworkSession(id: currentNetworkSessionID, endedAt: Date())
        }
        currentNetworkSessionID = try repository.startNetworkSession(networkName: currentNetwork, startedAt: Date())
        currentNetworkSessionName = currentNetwork
    }

    private func observeSleepWake() {
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.resumeAfterWake = self.isRunning
                if let currentNetworkSessionID = self.currentNetworkSessionID {
                    try? self.repository.finishNetworkSession(id: currentNetworkSessionID, endedAt: Date())
                }
                self.currentNetworkSessionID = nil
                self.currentNetworkSessionName = nil
                self.pause()
                self.accumulator.reset()
                self.status = "Paused for sleep"
            }
        })
        workspaceObservers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.accumulator.reset()
                self.refreshNetwork()
                if self.resumeAfterWake {
                    self.start()
                } else {
                    self.status = "Paused"
                }
            }
        })
        workspaceObservers.append(NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                guard let currentNetworkSessionID = self.currentNetworkSessionID else { return }
                try? self.repository.finishNetworkSession(id: currentNetworkSessionID, endedAt: Date())
            }
        })
    }

    private func recomputeNetworks() {
        do {
            networks = [allNetworks] + (try repository.networks())
            if !networks.contains(selectedNetwork) { selectedNetwork = allNetworks }
        } catch {
            status = "Network list failed: \(error.localizedDescription)"
        }
    }

    private func recomputeRecords() {
        do {
            records = try repository.records(
                timeRange: selectedTimeRange,
                networkName: selectedNetworkName,
                filterText: filterText,
                sessionStartedAt: sessionStartedAt,
                now: Date()
            )
            totalDownloaded = records.reduce(0) { $0 + $1.downloaded }
            totalUploaded = records.reduce(0) { $0 + $1.uploaded }
        } catch {
            status = "Query failed: \(error.localizedDescription)"
        }
    }

}
