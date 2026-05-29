import Foundation

public struct UsageRecord: Codable, Identifiable, Hashable, Sendable {
    public var id: String { appIdentifier }
    public let appIdentifier: String
    public let appName: String
    public var downloaded: UInt64
    public var uploaded: UInt64

    public var total: UInt64 { downloaded + uploaded }

    public init(appIdentifier: String? = nil, appName: String, downloaded: UInt64, uploaded: UInt64) {
        self.appIdentifier = appIdentifier ?? appName
        self.appName = appName
        self.downloaded = downloaded
        self.uploaded = uploaded
    }
}
