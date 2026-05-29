import XCTest
@testable import DataMeterCore

final class UsageAccumulatorTests: XCTestCase {
    func testAccumulatesOnlyDeltasAfterFirstSample() {
        var accumulator = UsageAccumulator()
        let firstDeltas = accumulator.apply(snapshots: [snapshot(downloaded: 100, uploaded: 20)], network: "Mobile")
        XCTAssertTrue(firstDeltas.isEmpty)

        let deltas = accumulator.apply(snapshots: [snapshot(downloaded: 175, uploaded: 50)], network: "Mobile")

        XCTAssertEqual(deltas.count, 1)
        XCTAssertEqual(deltas[0].downloaded, 75)
        XCTAssertEqual(deltas[0].uploaded, 30)
        XCTAssertEqual(deltas[0].networkName, "Mobile")
    }

    func testIgnoresCounterResets() {
        var accumulator = UsageAccumulator()
        accumulator.apply(snapshots: [snapshot(downloaded: 100, uploaded: 100)], network: "WiFi")
        let deltas = accumulator.apply(snapshots: [snapshot(downloaded: 50, uploaded: 50)], network: "WiFi")

        XCTAssertTrue(deltas.isEmpty)
    }

    private func snapshot(downloaded: UInt64, uploaded: UInt64) -> ProcessSnapshot {
        ProcessSnapshot(key: "Safari.1", appIdentifier: "com.apple.Safari", appName: "Safari", downloaded: downloaded, uploaded: uploaded)
    }
}
