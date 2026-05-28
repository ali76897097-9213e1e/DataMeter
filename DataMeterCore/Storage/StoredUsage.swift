import Foundation

public struct StoredUsage: Codable, Sendable {
    public var totalsByNetwork: [String: [String: UsageRecord]]
    public var updatedAt: Date

    public init(totalsByNetwork: [String: [String: UsageRecord]] = [:], updatedAt: Date = Date()) {
        self.totalsByNetwork = totalsByNetwork
        self.updatedAt = updatedAt
    }
}
