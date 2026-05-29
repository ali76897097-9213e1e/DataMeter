import Foundation

public enum NetTopParser {
    public static func parse(_ output: String) -> [ProcessSnapshot] {
        let rows = output.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        guard let headerRow = rows.first else { return [] }
        let headers = splitCommaSeparated(headerRow).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard let processIndex = processColumnIndex(in: headers),
              let downloadedIndex = headers.firstIndex(of: "bytes_in"),
              let uploadedIndex = headers.firstIndex(of: "bytes_out") else {
            return []
        }

        return rows.dropFirst().compactMap { row in
            parseRow(row, processIndex: processIndex, downloadedIndex: downloadedIndex, uploadedIndex: uploadedIndex)
        }
    }

    private static func parseRow(_ row: String, processIndex: Int, downloadedIndex: Int, uploadedIndex: Int) -> ProcessSnapshot? {
        let columns = splitCommaSeparated(row)
        guard columns.indices.contains(processIndex),
              columns.indices.contains(downloadedIndex),
              columns.indices.contains(uploadedIndex) else { return nil }

        let process = columns[processIndex]
        guard !process.isEmpty else { return nil }
        let identity = parseProcessIdentity(process)
        return ProcessSnapshot(
            key: process,
            processName: identity.name,
            appName: normalize(processName: identity.name),
            pid: identity.pid,
            downloaded: UInt64(columns[downloadedIndex]) ?? 0,
            uploaded: UInt64(columns[uploadedIndex]) ?? 0
        )
    }

    private static func processColumnIndex(in headers: [String]) -> Int? {
        if let index = headers.firstIndex(of: "process") { return index }
        // macOS nettop -x commonly leaves the process column unlabeled between
        // time and interface. Keep this fallback, but resolve byte columns by
        // header so extra/reordered fields don't corrupt totals.
        if headers.count > 1, headers[1].isEmpty { return 1 }
        return nil
    }

    static func splitCommaSeparated(_ row: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var iterator = row.makeIterator()

        while let character = iterator.next() {
            if character == "\"" {
                if inQuotes, let next = iterator.next() {
                    if next == "\"" {
                        current.append("\"")
                    } else {
                        inQuotes = false
                        if next == "," {
                            fields.append(current)
                            current = ""
                        } else {
                            current.append(next)
                        }
                    }
                } else {
                    inQuotes.toggle()
                }
            } else if character == ",", !inQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }

        fields.append(current)
        return fields
    }

    public static func parseProcessIdentity(_ processKey: String) -> (name: String, pid: Int32?) {
        guard let lastDot = processKey.lastIndex(of: ".") else { return (processKey, nil) }
        let pidText = processKey[processKey.index(after: lastDot)...]
        guard pidText.allSatisfy({ $0.isNumber }), let pid = Int32(pidText) else { return (processKey, nil) }
        return (String(processKey[..<lastDot]), pid)
    }

    public static func normalize(processName: String) -> String {
        var name = parseProcessIdentity(processName).name
        name = name.replacingOccurrences(of: " com.apple.WebKit", with: "")

        let helperSuffixes = [
            " Helper (Renderer)",
            " Helper (GPU)",
            " Helper (Plugin)",
            " Helper",
            " Web Content",
            " Networking",
            " Renderer",
            " GPU",
            " H"
        ]
        for suffix in helperSuffixes where name.hasSuffix(suffix) {
            name.removeLast(suffix.count)
        }

        if name.hasPrefix("com.apple.WebKit") { return "WebKit" }
        return name.isEmpty ? processName : name
    }
}
