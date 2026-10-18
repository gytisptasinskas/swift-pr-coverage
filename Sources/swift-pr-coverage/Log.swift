import Foundation

/// Diagnostics on stderr, so stdout stays the report. In GitHub Actions, warnings become annotations.
enum Log {
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
