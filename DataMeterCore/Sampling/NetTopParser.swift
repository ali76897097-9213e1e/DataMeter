import Foundation

public enum NetTopParser {
    public static func parse(_ output: String) -> [ProcessSnapshot] {
        output.split(separator: "\n")
            .dropFirst()
            .compactMap(parseLine)
    }

    static func parseLine(_ line: Substring) -> ProcessSnapshot? {
        let columns = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        guard columns.count >= 6 else { return nil }
        let process = columns[1]
        guard !process.isEmpty else { return nil }
        let identity = parseProcessIdentity(process)
        return ProcessSnapshot(
            key: process,
            processName: identity.name,
            appName: normalize(processName: identity.name),
            pid: identity.pid,
            downloaded: UInt64(columns[4]) ?? 0,
            uploaded: UInt64(columns[5]) ?? 0
        )
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
