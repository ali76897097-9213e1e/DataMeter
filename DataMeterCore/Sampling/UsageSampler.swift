import Foundation

public protocol UsageSampler: Sendable {
    func sample() async throws -> [ProcessSnapshot]
}
