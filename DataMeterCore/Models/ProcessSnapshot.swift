import Foundation

public struct ProcessSnapshot: Hashable, Sendable {
    public let key: String
    public let processName: String
    public let appIdentifier: String
    public let appName: String
    public let pid: Int32?
    public let downloaded: UInt64
    public let uploaded: UInt64

    public init(key: String, processName: String? = nil, appIdentifier: String? = nil, appName: String, pid: Int32? = nil, downloaded: UInt64, uploaded: UInt64) {
        self.key = key
        self.processName = processName ?? appName
        self.appIdentifier = appIdentifier ?? appName
        self.appName = appName
        self.pid = pid
        self.downloaded = downloaded
        self.uploaded = uploaded
    }

    public func withAppName(_ appName: String) -> ProcessSnapshot {
        ProcessSnapshot(key: key, processName: processName, appIdentifier: appIdentifier, appName: appName, pid: pid, downloaded: downloaded, uploaded: uploaded)
    }

    public func withAppIdentity(identifier: String, name: String) -> ProcessSnapshot {
        ProcessSnapshot(key: key, processName: processName, appIdentifier: identifier, appName: name, pid: pid, downloaded: downloaded, uploaded: uploaded)
    }
}
