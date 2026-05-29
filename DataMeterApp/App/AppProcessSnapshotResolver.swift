import DataMeterCore
import Foundation

struct AppProcessSnapshotResolver: ProcessSnapshotResolving {
    func resolve(_ snapshots: [ProcessSnapshot]) async -> [ProcessSnapshot] {
        await MainActor.run {
            AppIdentityResolver.shared.resolve(snapshots)
        }
    }
}
