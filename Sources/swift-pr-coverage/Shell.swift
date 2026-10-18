import Foundation

struct ProcessResult {
    var status: Int32
    var stdout: Data
    var stderr: String

    var succeeded: Bool { status == 0 }
}

enum Shell {
    /// Longest any single command may run before it is killed.
    static let timeout: TimeInterval = 300

    /// Runs `command` through `/usr/bin/env` and collects its output.
    ///
    /// Output goes to temporary files rather than pipes, and the exit is observed with
    /// `terminationHandler` rather than `waitUntilExit()`. A helper process that inherits
    /// stdout (and keeps a pipe open past the command's exit) or a thread without a
    /// running run loop therefore cannot stall the tool.
    static func run(_ command: String, _ arguments: [String], in directory: String? = nil) throws -> ProcessResult {
        let display = ([command] + arguments).joined(separator: " ")
        let started = Date()
        Log.debug("$ \(display)")

        let scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("swift-pr-coverage-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }
        let stdoutURL = scratch.appendingPathComponent("stdout")
        let stderrURL = scratch.appendingPathComponent("stderr")
        FileManager.default.createFile(atPath: stdoutURL.path, contents: nil)
        FileManager.default.createFile(atPath: stderrURL.path, contents: nil)
        let stdoutHandle = try FileHandle(forWritingTo: stdoutURL)
        let stderrHandle = try FileHandle(forWritingTo: stderrURL)
        defer {
            try? stdoutHandle.close()
            try? stderrHandle.close()
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [command] + arguments
        if let directory {
            process.currentDirectoryURL = URL(fileURLWithPath: directory)
        }
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = stdoutHandle
        process.standardError = stderrHandle

        let exited = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in exited.signal() }
        try process.run()

        if exited.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            throw ToolError("`\(display)` did not finish within \(Int(timeout)) s and was stopped.")
        }

        let result = ProcessResult(
            status: process.terminationStatus,
            stdout: (try? Data(contentsOf: stdoutURL)) ?? Data(),
            stderr: (try? String(contentsOf: stderrURL, encoding: .utf8)) ?? ""
        )
        Log.debug(String(format: "  exit %d in %.1f s", result.status, Date().timeIntervalSince(started)))
        return result
    }
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
