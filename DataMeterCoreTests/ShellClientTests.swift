import XCTest
@testable import DataMeterCore

final class ShellClientTests: XCTestCase {
    func testRunReturnsOutput() async throws {
        let shell = LiveShellClient(timeout: 2)
        let output = try await shell.run("/bin/echo", args: ["hello"])
        XCTAssertEqual(output.trimmingCharacters(in: .whitespacesAndNewlines), "hello")
    }

    func testRunTimesOutHungProcess() async {
        let shell = LiveShellClient(timeout: 0.1)
        do {
            _ = try await shell.run("/bin/sh", args: ["-c", "sleep 2"])
            XCTFail("Expected timeout")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("timed out"), error.localizedDescription)
        }
    }

    func testRunDrainsLargeOutputWithoutDeadlocking() async throws {
        let shell = LiveShellClient(timeout: 5)
        let output = try await shell.run("/bin/sh", args: ["-c", "i=0; while [ $i -lt 50000 ]; do echo DataMeter; i=$((i+1)); done"])
        XCTAssertTrue(output.count > 100_000)
    }
}
