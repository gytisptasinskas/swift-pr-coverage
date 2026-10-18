import Foundation

/// Diagnostics on stderr, so stdout stays the report. In GitHub Actions, warnings become annotations.
enum Log {
    /// Set by `--verbose`, before any work starts.
    nonisolated(unsafe) static var verbose = false

    static func debug(_ message: @autoclosure () -> String) {
        if verbose {
            write(message())
        }
    }

    static func info(_ message: String) {
        write(message)
    }

    static func warning(_ message: String) {
        let inActions = ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] == "true"
        write(inActions ? "::warning::\(message)" : "warning: \(message)")
    }

    private static func write(_ line: String) {
        FileHandle.standardError.write(Data((line + "\n").utf8))
    }
}
