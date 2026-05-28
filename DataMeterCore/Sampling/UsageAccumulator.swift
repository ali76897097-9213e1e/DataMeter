import Foundation

public struct UsageAccumulator: Sendable {
    public private(set) var stored: StoredUsage
    private var previousSnapshots: [String: ProcessSnapshot]

    public init(stored: StoredUsage = StoredUsage(), previousSnapshots: [String: ProcessSnapshot] = [:]) {
        self.stored = stored
        self.previousSnapshots = previousSnapshots
    }

    @discardableResult
    public mutating func apply(snapshots: [ProcessSnapshot], network: String, at timestamp: Date = Date()) -> [UsageDelta] {
        let networkName = network.isEmpty ? "Unknown Network" : network
        if stored.totalsByNetwork[networkName] == nil { stored.totalsByNetwork[networkName] = [:] }
        var deltas: [UsageDelta] = []

        for snapshot in snapshots {
            guard let old = previousSnapshots[snapshot.key] else { continue }
            guard snapshot.downloaded >= old.downloaded, snapshot.uploaded >= old.uploaded else { continue }

            let deltaDown = snapshot.downloaded - old.downloaded
            let deltaUp = snapshot.uploaded - old.uploaded
            guard deltaDown > 0 || deltaUp > 0 else { continue }

            var record = stored.totalsByNetwork[networkName]?[snapshot.appName] ?? UsageRecord(appName: snapshot.appName, downloaded: 0, uploaded: 0)
            record.downloaded += deltaDown
            record.uploaded += deltaUp
            stored.totalsByNetwork[networkName]?[snapshot.appName] = record
            deltas.append(UsageDelta(appName: snapshot.appName, networkName: networkName, timestamp: timestamp, downloaded: deltaDown, uploaded: deltaUp))
        }

        previousSnapshots = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.key, $0) })
        stored.updatedAt = timestamp
        return deltas
    }

    public mutating func reset(network: String? = nil) {
        if let network {
            stored.totalsByNetwork[network] = [:]
        } else {
            stored.totalsByNetwork = [:]
        }
        previousSnapshots = [:]
        stored.updatedAt = Date()
    }

    public func records(for selectedNetwork: String, allNetworksLabel: String = "All Networks") -> [UsageRecord] {
        if selectedNetwork != allNetworksLabel {
            return Array(stored.totalsByNetwork[selectedNetwork]?.values ?? [:].values)
        }

        var merged: [String: UsageRecord] = [:]
        for networkTotals in stored.totalsByNetwork.values {
            for record in networkTotals.values {
                var existing = merged[record.appName] ?? UsageRecord(appName: record.appName, downloaded: 0, uploaded: 0)
                existing.downloaded += record.downloaded
                existing.uploaded += record.uploaded
                merged[record.appName] = existing
            }
        }
        return Array(merged.values)
    }
}
