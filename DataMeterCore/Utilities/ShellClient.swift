import Foundation

public protocol ShellClient: Sendable {
    func run(_ executable: String, args: [String]) async throws -> String
    func runSync(_ executable: String, args: [String]) throws -> String
}

public struct LiveShellClient: ShellClient {
    public init() {}

    public func run(_ executable: String, args: [String]) async throws -> String {
        try await Task.detached {
            try runProcess(executable, args: args)
        }.value
    }

    public func runSync(_ executable: String, args: [String]) throws -> String {
        try runProcess(executable, args: args)
    }
}

private func runProcess(_ executable: String, args: [String]) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = args

    let output = Pipe()
    let error = Pipe()
    process.standardOutput = output
    process.standardError = error

    try process.run()
    process.waitUntilExit()

    let outputData = output.fileHandleForReading.readDataToEndOfFile()
    let errorData = error.fileHandleForReading.readDataToEndOfFile()

    if process.terminationStatus != 0 {
        let message = String(data: errorData, encoding: .utf8) ?? "Unknown shell error"
        throw NSError(domain: "Shell", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: message])
    }

    return String(data: outputData, encoding: .utf8) ?? ""
}
