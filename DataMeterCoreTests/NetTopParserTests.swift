import XCTest
@testable import DataMeterCore

final class NetTopParserTests: XCTestCase {
    func testParsesProcessUsageFromNettopOutput() {
        let output = """
time,,interface,state,bytes_in,bytes_out,rx_dupe
02:20:48.1,Google Chrome.123,,,1000,250,0
02:20:48.1,node.99,,,42,24,0
"""

        let snapshots = NetTopParser.parse(output)

        XCTAssertEqual(snapshots.map(\.appName), ["Google Chrome", "node"])
        XCTAssertEqual(snapshots[0].pid, 123)
        XCTAssertEqual(snapshots[0].downloaded, 1000)
        XCTAssertEqual(snapshots[0].uploaded, 250)
        XCTAssertEqual(snapshots[1].downloaded, 42)
        XCTAssertEqual(snapshots[1].uploaded, 24)
    }

    func testParsesQuotedProcessNamesAndFindsByteColumnsByHeader() {
        let output = """
time,process,interface,bytes_out,state,bytes_in
02:20:48.1,"Example, App.456",,25,,100
"""

        let snapshots = NetTopParser.parse(output)

        XCTAssertEqual(snapshots.count, 1)
        XCTAssertEqual(snapshots[0].appName, "Example, App")
        XCTAssertEqual(snapshots[0].pid, 456)
        XCTAssertEqual(snapshots[0].downloaded, 100)
        XCTAssertEqual(snapshots[0].uploaded, 25)
    }

    func testGroupsCommonHelperProcessesIntoReadableAppNames() {
        let output = """
time,,interface,state,bytes_in,bytes_out
02:20:48.1,Google Chrome Helper.123,,,1000,250
02:20:48.1,com.apple.WebKit.Networking.456,,,300,100
"""

        let snapshots = NetTopParser.parse(output)

        XCTAssertEqual(snapshots.map(\.appName), ["Google Chrome", "WebKit"])
    }
}
