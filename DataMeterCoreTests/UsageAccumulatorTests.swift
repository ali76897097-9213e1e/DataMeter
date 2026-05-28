import XCTest
@testable import DataMeterCore

final class UsageAccumulatorTests: XCTestCase {
    func testAccumulatesOnlyDeltasAfterFirstSample() {
        var accumulator = UsageAccumulator()
        accumulator.apply(snapshots: [snapshot(downloaded: 100, uploaded: 20)], network: "Mobile")
        XCTAssertTrue(accumulator.records(for: "All Networks").isEmpty)

        accumulator.apply(snapshots: [snapshot(downloaded: 175, uploaded: 50)], network: "Mobile")
        let records = accumulator.records(for: "All Networks")

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].downloaded, 75)
        XCTAssertEqual(records[0].uploaded, 30)
    }

    func testIgnoresCounterResets() {
        var accumulator = UsageAccumulator()
        accumulator.apply(snapshots: [snapshot(downloaded: 100, uploaded: 100)], network: "WiFi")
        accumulator.apply(snapshots: [snapshot(downloaded: 50, uploaded: 50)], network: "WiFi")

        XCTAssertTrue(accumulator.records(for: "All Networks").isEmpty)
    }

    private func snapshot(downloaded: UInt64, uploaded: UInt64) -> ProcessSnapshot {
        ProcessSnapshot(key: "Safari.1", appName: "Safari", downloaded: downloaded, uploaded: uploaded)
    }
}
