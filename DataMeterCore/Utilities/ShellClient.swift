import Foundation

public protocol ShellClient: Sendable {
    func run(_ executable: String, args: [String]) async throws -> String
    func runSync(_ executable: String, args: [String]) throws -> String
}

public struct LiveShellClient: ShellClient {
    private let timeout: TimeInterval

    public init(timeout: TimeInterval = 15) {
        self.timeout = timeout
    }

    public func run(_ executable: String, args: [String]) async throws -> String {
        try await Task.detached(priority: .utility) {
            try runProcess(executable, args: args, timeout: timeout)
        }.value
    }

    public func runSync(_ executable: String, args: [String]) throws -> String {
        try runProcess(executable, args: args, timeout: timeout)
    }
}

private enum ShellError: LocalizedError {
    case nonZeroExit(status: Int32, stderr: String)
    case timedOut(executable: String, timeout: TimeInterval)

    var errorDescription: String? {
        switch self {
        case let .nonZeroExit(status, stderr):
            let message = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return message.isEmpty ? "Command failed with exit status \(status)" : message
        case let .timedOut(executable, timeout):
            return "\(executable) timed out after \(timeout.formatted()) seconds"
        }
    }
}

private func runProcess(_ executable: String, args: [String], timeout: TimeInterval) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = args

    let output = Pipe()
    let error = Pipe()
    process.standardOutput = output
    process.standardError = error

    let outputData = LockedData()
    let errorData = LockedData()
    let readQueue = DispatchQueue(label: "com.datameter.shell.read", attributes: .concurrent)
    let readGroup = DispatchGroup()

    readGroup.enter()
    readQueue.async {
        outputData.set(output.fileHandleForReading.readDataToEndOfFile())
        readGroup.leave()
    }

    readGroup.enter()
    readQueue.async {
        errorData.set(error.fileHandleForReading.readDataToEndOfFile())
        readGroup.leave()
    }

    let startedAt = ContinuousClock.now
    try process.run()

    let deadline = Date().addingTimeInterval(timeout)
    while process.isRunning, Date() < deadline {
        Thread.sleep(forTimeInterval: 0.02)
    }

    if process.isRunning {
        process.terminate()
        let terminationDeadline = Date().addingTimeInterval(1)
        while process.isRunning, Date() < terminationDeadline {
            Thread.sleep(forTimeInterval: 0.02)
        }
        if process.isRunning {
            process.interrupt()
        }
        _ = readGroup.wait(timeout: .now() + 1)
        DataMeterLog.shell.error("command timed out executable=\(executable, privacy: .public) timeout=\(timeout, privacy: .public)")
        throw ShellError.timedOut(executable: executable, timeout: timeout)
    }

    readGroup.wait()

    if process.terminationStatus != 0 {
        let message = String(data: errorData.value, encoding: .utf8) ?? ""
        DataMeterLog.shell.error("command failed executable=\(executable, privacy: .public) status=\(process.terminationStatus, privacy: .public)")
        throw ShellError.nonZeroExit(status: process.terminationStatus, stderr: message)
    }

    let duration = startedAt.duration(to: .now)
    DataMeterLog.shell.debug("command completed executable=\(executable, privacy: .public) duration=\(duration.description, privacy: .public)")
    return String(data: outputData.value, encoding: .utf8) ?? ""
}

private final class LockedData: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    var value: Data {
        lock.lock()
        defer { lock.unlock() }
        return data
    }

    func set(_ data: Data) {
        lock.lock()
        self.data = data
        lock.unlock()
    }
}
