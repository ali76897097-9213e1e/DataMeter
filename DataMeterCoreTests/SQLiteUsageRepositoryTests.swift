import GRDB
import XCTest
@testable import DataMeterCore

final class SQLiteUsageRepositoryTests: XCTestCase {
    func testRecordsDeltasAndQueriesByTimeRangeNetworkAndFilter() throws {
        let repository = try SQLiteUsageRepository(url: temporaryDatabaseURL())
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let yesterday = now.addingTimeInterval(-90_000)
        let sessionStart = now.addingTimeInterval(-60)

        try repository.record([
            UsageDelta(appName: "Safari", networkName: "Mobile", timestamp: yesterday, downloaded: 1_000, uploaded: 100),
            UsageDelta(appName: "Safari", networkName: "Mobile", timestamp: now, downloaded: 2_000, uploaded: 200),
            UsageDelta(appName: "Chrome", networkName: "Office", timestamp: now, downloaded: 3_000, uploaded: 300)
        ])

        let sessionRecords = try repository.records(timeRange: .session, networkName: nil, filterText: "", sessionStartedAt: sessionStart, now: now)
        XCTAssertEqual(sessionRecords.map(\.appName), ["Chrome", "Safari"])

        let mobileToday = try repository.records(timeRange: .today, networkName: "Mobile", filterText: "saf", sessionStartedAt: sessionStart, now: now)
        XCTAssertEqual(mobileToday.count, 1)
        XCTAssertEqual(mobileToday[0].appName, "Safari")
        XCTAssertEqual(mobileToday[0].downloaded, 2_000)
        XCTAssertEqual(mobileToday[0].uploaded, 200)

        let allTimeMobile = try repository.records(timeRange: .allTime, networkName: "Mobile", filterText: "", sessionStartedAt: sessionStart, now: now)
        XCTAssertEqual(allTimeMobile[0].downloaded, 3_000)
        XCTAssertEqual(allTimeMobile[0].uploaded, 300)
    }

    func testRecordsWithSameStableIdentifierAreReturnedAsOneVisibleApp() throws {
        let repository = try SQLiteUsageRepository(url: temporaryDatabaseURL())
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        try repository.record([
            UsageDelta(appIdentifier: "com.apple.Safari", appName: "Safari", networkName: "Wi‑Fi", timestamp: now, downloaded: 1_000, uploaded: 100),
            UsageDelta(appIdentifier: "com.apple.Safari", appName: "Safari Networking", networkName: "Wi‑Fi", timestamp: now, downloaded: 2_000, uploaded: 200)
        ])

        let records = try repository.records(timeRange: .allTime, networkName: nil, filterText: "", sessionStartedAt: now, now: now)

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].id, "com.apple.Safari")
        XCTAssertEqual(records[0].downloaded, 3_000)
        XCTAssertEqual(records[0].uploaded, 300)
    }

    func testNetworkSessionsCanBeStartedAndFinished() throws {
        let repository = try SQLiteUsageRepository(url: temporaryDatabaseURL())
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        let sessionID = try repository.startNetworkSession(networkName: "Mobile", startedAt: now)
        try repository.record([
            UsageDelta(appName: "Safari", networkName: "Mobile", networkSessionID: sessionID, timestamp: now, downloaded: 1_000, uploaded: 100)
        ])
        try repository.finishNetworkSession(id: sessionID, endedAt: now.addingTimeInterval(60))

        let openSessionID = try repository.startNetworkSession(networkName: "Office", startedAt: now)
        try repository.finishOpenNetworkSessions(endedAt: now.addingTimeInterval(120))
        XCTAssertGreaterThan(openSessionID, sessionID)

        let records = try repository.records(timeRange: .allTime, networkName: "Mobile", filterText: "", sessionStartedAt: now, now: now)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].total, 1_100)
    }

    func testMaintenanceRollsOlderDeltasIntoDailyRows() throws {
        let repository = try SQLiteUsageRepository(url: temporaryDatabaseURL())
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let old = now.addingTimeInterval(-40 * 24 * 60 * 60)
        let sessionStart = old.addingTimeInterval(-60)

        try repository.record([
            UsageDelta(appName: "Safari", networkName: "Office", timestamp: old, downloaded: 1_000, uploaded: 100),
            UsageDelta(appName: "Safari", networkName: "Office", timestamp: old.addingTimeInterval(60), downloaded: 2_000, uploaded: 200),
            UsageDelta(appName: "Chrome", networkName: "Mobile", timestamp: now, downloaded: 3_000, uploaded: 300)
        ])

        try repository.performMaintenance(now: now)

        let allRecords = try repository.records(timeRange: .allTime, networkName: nil, filterText: "", sessionStartedAt: sessionStart, now: now)
        XCTAssertEqual(allRecords.first { $0.appName == "Safari" }?.downloaded, 3_000)
        XCTAssertEqual(allRecords.first { $0.appName == "Safari" }?.uploaded, 300)
        XCTAssertEqual(allRecords.first { $0.appName == "Chrome" }?.downloaded, 3_000)

        let officeRecords = try repository.records(timeRange: .allTime, networkName: "Office", filterText: "", sessionStartedAt: sessionStart, now: now)
        XCTAssertEqual(officeRecords.count, 1)
        XCTAssertEqual(officeRecords[0].appName, "Safari")
        XCTAssertEqual(try repository.networks(), ["Mobile", "Office"])
    }

    func testOpeningOldPreReleaseRollupSchemaResetsDatabase() throws {
        let oldSchemaURL = temporaryDatabaseURL()
        try {
            let oldSchema = try GRDB.DatabaseQueue(path: oldSchemaURL.path)
            try oldSchema.write { db in
                try db.execute(sql: """
                    CREATE TABLE usage_daily_rollups (
                        day_start DOUBLE NOT NULL,
                        app_identifier TEXT NOT NULL,
                        app_name TEXT NOT NULL,
                        network_name TEXT NOT NULL,
                        downloaded_bytes INTEGER NOT NULL,
                        uploaded_bytes INTEGER NOT NULL,
                        PRIMARY KEY (day_start, app_identifier, app_name, network_name)
                    )
                    """)
            }
        }()

        let resetRepository = try SQLiteUsageRepository(url: oldSchemaURL)
        try resetRepository.record([
            UsageDelta(appIdentifier: "com.example.New", appName: "New", networkName: "Wi‑Fi", timestamp: Date(timeIntervalSince1970: 0), downloaded: 2, uploaded: 0)
        ])

        let records = try resetRepository.records(timeRange: .allTime, networkName: nil, filterText: "", sessionStartedAt: Date(timeIntervalSince1970: 0), now: Date())
        XCTAssertEqual(records.map(\.appIdentifier), ["com.example.New"])
    }

    func testResetDeletesOnlyMatchingScope() throws {
        let repository = try SQLiteUsageRepository(url: temporaryDatabaseURL())
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let sessionStart = now.addingTimeInterval(-60)

        try repository.record([
            UsageDelta(appName: "Safari", networkName: "Mobile", timestamp: now, downloaded: 1_000, uploaded: 0),
            UsageDelta(appName: "Chrome", networkName: "Office", timestamp: now, downloaded: 2_000, uploaded: 0)
        ])

        try repository.reset(networkName: "Mobile", since: nil)

        let records = try repository.records(timeRange: .allTime, networkName: nil, filterText: "", sessionStartedAt: sessionStart, now: now)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].appName, "Chrome")
    }

    private func temporaryDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
    }
}
