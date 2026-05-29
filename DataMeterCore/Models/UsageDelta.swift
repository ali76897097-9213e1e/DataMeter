import Foundation

public struct UsageDelta: Codable, Hashable, Sendable {
    public let appIdentifier: String
    public let appName: String
    public let networkName: String
    public let networkSessionID: Int64?
    public let timestamp: Date
    public let downloaded: UInt64
    public let uploaded: UInt64

    public var total: UInt64 { downloaded + uploaded }

    public init(appIdentifier: String? = nil, appName: String, networkName: String, networkSessionID: Int64? = nil, timestamp: Date, downloaded: UInt64, uploaded: UInt64) {
        self.appIdentifier = appIdentifier ?? appName
        self.appName = appName
        self.networkName = networkName
        self.networkSessionID = networkSessionID
        self.timestamp = timestamp
        self.downloaded = downloaded
        self.uploaded = uploaded
    }

    public func withNetworkSessionID(_ networkSessionID: Int64?) -> UsageDelta {
        UsageDelta(appIdentifier: appIdentifier, appName: appName, networkName: networkName, networkSessionID: networkSessionID, timestamp: timestamp, downloaded: downloaded, uploaded: uploaded)
    }
}
