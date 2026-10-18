import Foundation

struct ProcessResult {
    var status: Int32
    var stdout: Data
    var stderr: String

    var succeeded: Bool { status == 0 }
}

enum Shell {
    /// Runs `command` through `/usr/bin/env` and collects its output.
    static func run(_ command: String, _ arguments: [String], in directory: String? = nil) throws -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [command] + arguments
        if let directory {
            process.currentDirectoryURL = URL(fileURLWithPath: directory)
        }
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        try process.run()

        // Drain stderr on another thread so a chatty process cannot block on a full pipe
        // while stdout (possibly megabytes of JSON) is being read here.
        let stderrHandle = stderrPipe.fileHandleForReading
        let stderrBox = DataBox()
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global().async {
            stderrBox.data = stderrHandle.readDataToEndOfFile()
            group.leave()
        }
        let stdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        group.wait()
        process.waitUntilExit()

        return ProcessResult(
            status: process.terminationStatus,
            stdout: stdout,
            stderr: String(decoding: stderrBox.data, as: UTF8.self)
        )
    }
}

private final class DataBox: @unchecked Sendable {
    var data = Data()
}

struct ToolError: Error, CustomStringConvertible {
    var description: String

    init(_ description: String) {
        self.description = description
    }

    init(command: String, result: ProcessResult) {
        let detail = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        self.description = "\(command) failed (exit \(result.status))" + (detail.isEmpty ? "" : ": \(detail)")
    }
}
