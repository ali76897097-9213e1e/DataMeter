import AppKit
import DataMeterCore
import Foundation
import IOKit.ps

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
    private var engine: UsageTrackingEngine?
    private var samplingTask: Task<Void, Never>?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var resumeAfterWake = false
    private let sessionStartedAt = Date()
    private let activeSampleInterval: Duration = .seconds(2)
    private let backgroundSampleInterval: Duration = .seconds(8)
    private let energyConstrainedActiveSampleInterval: Duration = .seconds(5)
    private let energyConstrainedBackgroundSampleInterval: Duration = .seconds(15)
    private var visibleSurfaceCount = 0
    private var queryGeneration = 0

    init(
        sampler: UsageSampler = NetTopSampler(),
        repository: UsageHistoryRepository? = nil,
        networkProvider: NetworkIdentityProviding = NetworkIdentityProvider()
    ) {
        self.trackingStartedAt = sessionStartedAt
        do {
            let repository = try repository ?? SQLiteUsageRepository()
            self.engine = UsageTrackingEngine(
                sampler: sampler,
                repository: repository,
                networkProvider: networkProvider,
                processResolver: AppProcessSnapshotResolver()
            )
            Task {
                try? await engine?.finishOpenSessions()
                await refreshState()
            }
            observeSleepWake()
            start()
        } catch {
            self.engine = nil
            isRunning = false
            status = "Storage unavailable: \(error.localizedDescription)"
        }
    }

    func start() {
        guard samplingTask == nil else {
            isRunning = true
            status = "Tracking"
            return
        }

        isRunning = true
        status = "Tracking"
        samplingTask = Task { [weak self] in
            await self?.runSamplingLoop()
        }
    }

    func pause() {
        isRunning = false
        status = "Paused"
        samplingTask?.cancel()
        samplingTask = nil
        Task {
            try? await engine?.pause()
        }
    }

    func resetVisibleTotals() {
        queryGeneration += 1
        let generation = queryGeneration
        let query = makeQuery()
        Task {
            do {
                guard let engine else { return }
                let state = try await engine.reset(query: query)
                guard generation == queryGeneration else { return }
                apply(state: state)
                status = isRunning ? "Tracking" : "Paused"
            } catch {
                guard generation == queryGeneration else { return }
                status = "Reset failed: \(error.localizedDescription)"
            }
        }
    }

    func filtersChanged() {
        queryGeneration += 1
        let generation = queryGeneration
        let query = makeQuery()
        Task { await refreshState(query: query, generation: generation) }
    }

    func surfaceAppeared() {
        visibleSurfaceCount += 1
    }

    func surfaceDisappeared() {
        visibleSurfaceCount = max(0, visibleSurfaceCount - 1)
    }

    func sample() async {
        guard isRunning else { return }
        let generation = queryGeneration
        let query = makeQuery()
        do {
            guard let engine else { return }
            let state = try await engine.sample(query: query)
            guard isRunning, !Task.isCancelled, generation == queryGeneration else { return }
            apply(state: state)
            status = "Tracking • \(state.processCount) processes"
        } catch is CancellationError {
            guard generation == queryGeneration else { return }
            status = "Paused"
        } catch {
            guard generation == queryGeneration else { return }
            status = "Tracking failed: \(error.localizedDescription)"
        }
    }

    private var selectedNetworkName: String? {
        selectedNetwork == allNetworks ? nil : selectedNetwork
    }

    private func runSamplingLoop() async {
        while !Task.isCancelled {
            await sample()
            do {
                try await Task.sleep(for: nextSampleInterval)
            } catch {
                break
            }
        }
    }

    private var nextSampleInterval: Duration {
        if isEnergyConstrained {
            return visibleSurfaceCount > 0 ? energyConstrainedActiveSampleInterval : energyConstrainedBackgroundSampleInterval
        }
        return visibleSurfaceCount > 0 ? activeSampleInterval : backgroundSampleInterval
    }

    private var isEnergyConstrained: Bool {
        ProcessInfo.processInfo.isLowPowerModeEnabled || isRunningOnBatteryPower
    }

    private var isRunningOnBatteryPower: Bool {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return false }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  let state = description[kIOPSPowerSourceStateKey] as? String else { continue }
            if state == kIOPSBatteryPowerValue { return true }
        }
        return false
    }

    private func refreshState() async {
        await refreshState(query: makeQuery(), generation: queryGeneration)
    }

    private func refreshState(query: UsageQuery, generation: Int) async {
        do {
            guard let engine else { return }
            let state = try await engine.state(query: query)
            guard generation == queryGeneration else { return }
            apply(state: state)
        } catch {
            guard generation == queryGeneration else { return }
            status = "Query failed: \(error.localizedDescription)"
        }
    }

    private func makeQuery(now: Date = Date()) -> UsageQuery {
        UsageQuery(
            timeRange: selectedTimeRange,
            networkName: selectedNetworkName,
            filterText: filterText,
            sessionStartedAt: sessionStartedAt,
            now: now
        )
    }

    private func apply(state: UsageTrackingState) {
        if currentNetwork != state.currentNetwork {
            currentNetwork = state.currentNetwork
        }

        let nextNetworks = [allNetworks] + state.networks
        if networks != nextNetworks {
            networks = nextNetworks
        }
        if !networks.contains(selectedNetwork) { selectedNetwork = allNetworks }

        if records != state.records {
            records = state.records
        }
        if totalDownloaded != state.totalDownloaded {
            totalDownloaded = state.totalDownloaded
        }
        if totalUploaded != state.totalUploaded {
            totalUploaded = state.totalUploaded
        }
    }

    private func observeSleepWake() {
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.resumeAfterWake = self.isRunning
                self.samplingTask?.cancel()
                self.samplingTask = nil
                self.isRunning = false
                try? await self.engine?.prepareForSleep()
                self.status = "Paused for sleep"
            }
        })
        workspaceObservers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.engine?.resetAccumulator()
                if self.resumeAfterWake {
                    self.start()
                } else {
                    self.status = "Paused"
                }
            }
        })
        workspaceObservers.append(NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            Task {
                try? await self.engine?.pause()
            }
        })
    }
}
