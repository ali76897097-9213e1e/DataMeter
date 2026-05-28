import Foundation

public struct NetTopSampler: UsageSampler {
    private let shell: ShellClient

    public init(shell: ShellClient = LiveShellClient()) {
        self.shell = shell
    }

    public func sample() async throws -> [ProcessSnapshot] {
        let output = try await shell.run("/usr/bin/nettop", args: ["-P", "-L", "1", "-x"])
        return NetTopParser.parse(output)
    }
}
