import Foundation

public protocol UsageRepository: Sendable {
    func load() throws -> StoredUsage
    func save(_ usage: StoredUsage) throws
}

public struct JSONUsageRepository: UsageRepository {
    private let url: URL

    public init(url: URL? = nil) {
        if let url {
            self.url = url
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let directory = base.appendingPathComponent("DataMeter", isDirectory: true)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            self.url = directory.appendingPathComponent("usage.json")
        }
    }

    public func load() throws -> StoredUsage {
        guard FileManager.default.fileExists(atPath: url.path) else { return StoredUsage() }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(StoredUsage.self, from: data)
    }

    public func save(_ usage: StoredUsage) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(usage)
        try data.write(to: url, options: [.atomic])
    }
}
