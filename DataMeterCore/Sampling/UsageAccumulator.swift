import Foundation

public struct UsageAccumulator: Sendable {
    private var previousSnapshots: [String: ProcessSnapshot]

    public init(previousSnapshots: [String: ProcessSnapshot] = [:]) {
        self.previousSnapshots = previousSnapshots
    }

    @discardableResult
    public mutating func apply(snapshots: [ProcessSnapshot], network: String, at timestamp: Date = Date()) -> [UsageDelta] {
        let networkName = network.isEmpty ? "Unknown Network" : network
        var deltas: [UsageDelta] = []

        for snapshot in snapshots {
            guard let old = previousSnapshots[snapshot.key] else { continue }
            guard snapshot.downloaded >= old.downloaded, snapshot.uploaded >= old.uploaded else { continue }

            let deltaDown = snapshot.downloaded - old.downloaded
            let deltaUp = snapshot.uploaded - old.uploaded
            guard deltaDown > 0 || deltaUp > 0 else { continue }

            deltas.append(UsageDelta(
                appIdentifier: snapshot.appIdentifier,
                appName: snapshot.appName,
                networkName: networkName,
                timestamp: timestamp,
                downloaded: deltaDown,
                uploaded: deltaUp
            ))
        }

        previousSnapshots = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.key, $0) })
        return deltas
    }

    public mutating func reset(network: String? = nil) {
        previousSnapshots = [:]
    }
}
