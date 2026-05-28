import XCTest
@testable import DataMeterCore

final class NetTopParserTests: XCTestCase {
    func testParsesNettopCsvRows() {
        let output = """
time,,interface,state,bytes_in,bytes_out,rx_dupe
02:20:48.1,Google Chrome.123,,,1000,250,0
02:20:48.1,node.99,,,42,24,0
"""

        let snapshots = NetTopParser.parse(output)

        XCTAssertEqual(snapshots.count, 2)
        XCTAssertEqual(snapshots[0].key, "Google Chrome.123")
        XCTAssertEqual(snapshots[0].processName, "Google Chrome")
        XCTAssertEqual(snapshots[0].appName, "Google Chrome")
        XCTAssertEqual(snapshots[0].pid, 123)
        XCTAssertEqual(snapshots[0].downloaded, 1000)
        XCTAssertEqual(snapshots[0].uploaded, 250)
    }

    func testParsesProcessIdentity() {
        let identity = NetTopParser.parseProcessIdentity("Google Chrome Helper.123")
        XCTAssertEqual(identity.name, "Google Chrome Helper")
        XCTAssertEqual(identity.pid, 123)

        let processOnly = NetTopParser.parseProcessIdentity("kernel_task")
        XCTAssertEqual(processOnly.name, "kernel_task")
        XCTAssertNil(processOnly.pid)
    }

    func testNormalizesHelperProcesses() {
        XCTAssertEqual(NetTopParser.normalize(processName: "Google Chrome Helper.123"), "Google Chrome")
        XCTAssertEqual(NetTopParser.normalize(processName: "Google Chrome H.123"), "Google Chrome")
        XCTAssertEqual(NetTopParser.normalize(processName: "com.apple.WebKit.Networking.123"), "WebKit")
    }
}
