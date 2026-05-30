import Foundation
import GRDB

public final class SQLiteUsageRepository: UsageHistoryRepository, @unchecked Sendable {
    private let dbQueue: DatabaseQueue

    public init(url: URL? = nil) throws {
        let databaseURL: URL
        if let url {
            databaseURL = url
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let directory = base.appendingPathComponent("DataMeter", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            databaseURL = directory.appendingPathComponent("usage.sqlite")
        }

        try Self.resetIncompatiblePreReleaseDatabaseIfNeeded(at: databaseURL)

        var configuration = Configuration()
        configuration.prepareDatabase { db in
            try db.execute(sql: "PRAGMA journal_mode = WAL")
            try db.execute(sql: "PRAGMA synchronous = NORMAL")
        }
        dbQueue = try DatabaseQueue(path: databaseURL.path, configuration: configuration)
        try Self.migrator.migrate(dbQueue)
        DataMeterLog.storage.debug("opened usage database at \(databaseURL.path, privacy: .private)")
    }

    private static func resetIncompatiblePreReleaseDatabaseIfNeeded(at databaseURL: URL) throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: databaseURL.path) else { return }

        let needsReset: Bool = try {
            let existingQueue = try DatabaseQueue(path: databaseURL.path)
            return try existingQueue.read { db in
                guard try db.tableExists("usage_daily_rollups") else { return false }
                let rows = try Row.fetchAll(db, sql: "PRAGMA table_info(usage_daily_rollups)")
                let primaryKeyColumns = rows.compactMap { row -> (name: String, position: Int)? in
                    let position: Int = row["pk"]
                    guard position > 0 else { return nil }
                    let name: String = row["name"]
                    return (name, position)
                }
                .sorted { $0.position < $1.position }
                .map(\.name)

                return primaryKeyColumns != ["day_start", "app_identifier", "network_name"]
            }
        }()

        guard needsReset else { return }
        DataMeterLog.storage.debug("resetting incompatible pre-release usage database")
        for suffix in ["", "-wal", "-shm"] {
            let url = URL(fileURLWithPath: databaseURL.path + suffix)
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
        }
    }

    public func startNetworkSession(networkName: String, startedAt: Date) throws -> Int64 {
        try dbQueue.write { db in
            try db.execute(
                sql: "INSERT INTO network_sessions (network_name, started_at, ended_at) VALUES (?, ?, NULL)",
                arguments: [networkName, startedAt.timeIntervalSince1970]
            )
            return db.lastInsertedRowID
        }
    }

    public func finishNetworkSession(id: Int64, endedAt: Date) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "UPDATE network_sessions SET ended_at = ? WHERE id = ? AND ended_at IS NULL",
                arguments: [endedAt.timeIntervalSince1970, id]
            )
        }
    }

    public func finishOpenNetworkSessions(endedAt: Date) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "UPDATE network_sessions SET ended_at = ? WHERE ended_at IS NULL",
                arguments: [endedAt.timeIntervalSince1970]
            )
        }
    }

    public func record(_ deltas: [UsageDelta]) throws {
        guard !deltas.isEmpty else { return }
        try dbQueue.write { db in
            for delta in deltas {
                try db.execute(
                    sql: """
                    INSERT INTO usage_deltas (app_identifier, app_name, network_name, network_session_id, timestamp, downloaded_bytes, uploaded_bytes)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    """,
                    arguments: [delta.appIdentifier, delta.appName, delta.networkName, delta.networkSessionID, delta.timestamp.timeIntervalSince1970, Int64(delta.downloaded), Int64(delta.uploaded)]
                )
            }
        }
    }

    public func records(
        timeRange: UsageTimeRange,
        networkName: String?,
        filterText: String,
        sessionStartedAt: Date,
        now: Date = Date()
    ) throws -> [UsageRecord] {
        let startDate = timeRange.startDate(sessionStartedAt: sessionStartedAt, now: now)
        let trimmedFilter = filterText.trimmingCharacters(in: .whitespacesAndNewlines)

        var conditions: [String] = []
        var arguments = StatementArguments()

        if let startDate {
            conditions.append("timestamp >= ?")
            arguments += [startDate.timeIntervalSince1970]
        }

        if let networkName, !networkName.isEmpty {
            conditions.append("network_name = ?")
            arguments += [networkName]
        }

        if !trimmedFilter.isEmpty {
            conditions.append("app_name LIKE ? ESCAPE '\\'")
            arguments += ["%\(escapeLike(trimmedFilter))%"]
        }

        let whereClause = conditions.isEmpty ? "" : "WHERE \(conditions.joined(separator: " AND "))"
        let sql = """
            WITH usage AS (
                SELECT app_identifier, app_name, network_name, timestamp, downloaded_bytes, uploaded_bytes FROM usage_deltas
                UNION ALL
                SELECT app_identifier, app_name, network_name, day_start AS timestamp, downloaded_bytes, uploaded_bytes FROM usage_daily_rollups
            )
            SELECT app_identifier, MAX(app_name) AS app_name, SUM(downloaded_bytes) AS downloaded, SUM(uploaded_bytes) AS uploaded
            FROM usage
            \(whereClause)
            GROUP BY app_identifier
            HAVING downloaded > 0 OR uploaded > 0
            ORDER BY downloaded + uploaded DESC, app_name ASC
            """

        return try dbQueue.read { db in
            try Row.fetchAll(db, sql: sql, arguments: arguments).map { row in
                let appIdentifier: String = row["app_identifier"]
                let appName: String = row["app_name"]
                let downloaded: Int64 = row["downloaded"]
                let uploaded: Int64 = row["uploaded"]
                return UsageRecord(
                    appIdentifier: appIdentifier,
                    appName: appName,
                    downloaded: UInt64(downloaded),
                    uploaded: UInt64(uploaded)
                )
            }
        }
    }

    public func networks() throws -> [String] {
        try dbQueue.read { db in
            try String.fetchAll(db, sql: """
                SELECT network_name FROM usage_deltas
                UNION
                SELECT network_name FROM usage_daily_rollups
                ORDER BY network_name ASC
                """)
        }
    }

    public func reset(networkName: String?, since startDate: Date?) throws {
        var conditions: [String] = []
        var arguments = StatementArguments()

        if let networkName, !networkName.isEmpty {
            conditions.append("network_name = ?")
            arguments += [networkName]
        }

        if let startDate {
            conditions.append("timestamp >= ?")
            arguments += [startDate.timeIntervalSince1970]
        }

        let whereClause = conditions.isEmpty ? "" : "WHERE \(conditions.joined(separator: " AND "))"
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM usage_deltas \(whereClause)", arguments: arguments)
            try db.execute(sql: "DELETE FROM usage_daily_rollups \(whereClause.replacingOccurrences(of: "timestamp", with: "day_start"))", arguments: arguments)
        }
    }

    public func performMaintenance(now: Date) throws {
        let cutoff = Calendar.current.startOfDay(for: now.addingTimeInterval(-30 * 24 * 60 * 60))
        let cutoffTimestamp = cutoff.timeIntervalSince1970
        try dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO usage_daily_rollups (day_start, app_identifier, app_name, network_name, downloaded_bytes, uploaded_bytes)
                SELECT CAST(timestamp / 86400 AS INTEGER) * 86400 AS day_start,
                       app_identifier,
                       MAX(app_name) AS app_name,
                       network_name,
                       SUM(downloaded_bytes),
                       SUM(uploaded_bytes)
                FROM usage_deltas
                WHERE timestamp < ?
                GROUP BY day_start, app_identifier, network_name
                ON CONFLICT(day_start, app_identifier, network_name) DO UPDATE SET
                    downloaded_bytes = downloaded_bytes + excluded.downloaded_bytes,
                    uploaded_bytes = uploaded_bytes + excluded.uploaded_bytes
                """,
                arguments: [cutoffTimestamp]
            )
            try db.execute(sql: "DELETE FROM usage_deltas WHERE timestamp < ?", arguments: [cutoffTimestamp])
        }
        DataMeterLog.storage.debug("completed usage maintenance cutoff=\(cutoffTimestamp, privacy: .public)")
    }

    private static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createSchema") { db in
            try db.create(table: "network_sessions") { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("network_name", .text).notNull()
                table.column("started_at", .double).notNull()
                table.column("ended_at", .double)
            }
            try db.create(index: "idx_network_sessions_network", on: "network_sessions", columns: ["network_name"])
            try db.create(index: "idx_network_sessions_started", on: "network_sessions", columns: ["started_at"])

            try db.create(table: "usage_deltas") { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("app_identifier", .text).notNull()
                table.column("app_name", .text).notNull()
                table.column("network_name", .text).notNull()
                table.column("network_session_id", .integer)
                table.column("timestamp", .double).notNull()
                table.column("downloaded_bytes", .integer).notNull()
                table.column("uploaded_bytes", .integer).notNull()
            }
            try db.create(index: "idx_usage_deltas_timestamp", on: "usage_deltas", columns: ["timestamp"])
            try db.create(index: "idx_usage_deltas_network", on: "usage_deltas", columns: ["network_name"])
            try db.create(index: "idx_usage_deltas_app", on: "usage_deltas", columns: ["app_identifier"])
            try db.create(index: "idx_usage_deltas_network_session", on: "usage_deltas", columns: ["network_session_id"])
            try db.create(index: "idx_usage_deltas_time_network_app", on: "usage_deltas", columns: ["timestamp", "network_name", "app_identifier"])
            try db.create(index: "idx_usage_deltas_network_time_app", on: "usage_deltas", columns: ["network_name", "timestamp", "app_identifier"])

            try db.create(table: "usage_daily_rollups") { table in
                table.column("day_start", .double).notNull()
                table.column("app_identifier", .text).notNull()
                table.column("app_name", .text).notNull()
                table.column("network_name", .text).notNull()
                table.column("downloaded_bytes", .integer).notNull()
                table.column("uploaded_bytes", .integer).notNull()
                table.primaryKey(["day_start", "app_identifier", "network_name"], onConflict: .replace)
            }
            try db.create(index: "idx_usage_daily_rollups_day_network_app", on: "usage_daily_rollups", columns: ["day_start", "network_name", "app_identifier"])
            try db.create(index: "idx_usage_daily_rollups_network_day_app", on: "usage_daily_rollups", columns: ["network_name", "day_start", "app_identifier"])
        }
        return migrator
    }
}

private func escapeLike(_ value: String) -> String {
    value
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "%", with: "\\%")
        .replacingOccurrences(of: "_", with: "\\_")
}
