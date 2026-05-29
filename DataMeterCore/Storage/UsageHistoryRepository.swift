import Foundation

public protocol UsageHistoryRepository: Sendable {
    func startNetworkSession(networkName: String, startedAt: Date) throws -> Int64
    func finishNetworkSession(id: Int64, endedAt: Date) throws
    func finishOpenNetworkSessions(endedAt: Date) throws
    func record(_ deltas: [UsageDelta]) throws
    func records(timeRange: UsageTimeRange, networkName: String?, filterText: String, sessionStartedAt: Date, now: Date) throws -> [UsageRecord]
    func networks() throws -> [String]
    func reset(networkName: String?, since startDate: Date?) throws
    func performMaintenance(now: Date) throws
}
