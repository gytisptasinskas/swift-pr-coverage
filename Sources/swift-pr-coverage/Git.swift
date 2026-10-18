import Foundation

enum Git {
    static func topLevel(from directory: String) throws -> String {
        let result = try Shell.run("git", ["rev-parse", "--show-toplevel"], in: directory)
        guard result.succeeded else {
            throw ToolError(command: "git rev-parse --show-toplevel", result: result)
        }
        return String(decoding: result.stdout, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func resolveCommit(_ ref: String, in repoRoot: String) throws -> String {
        let result = try Shell.run("git", ["rev-parse", "--verify", "\(ref)^{commit}"], in: repoRoot)
        guard result.succeeded else {
            throw ToolError(command: "git rev-parse \(ref)", result: result)
        }
        return String(decoding: result.stdout, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Zero-context diff of Swift files between the merge base of `base` and `head`, and `head`.
    static func swiftDiff(base: String, head: String, in repoRoot: String) throws -> String {
        let arguments = [
            "-c", "core.quotePath=false",
            "diff", "-M", "--unified=0", "--no-color", "--no-ext-diff",
            "\(base)...\(head)", "--", "*.swift",
        ]
        let result = try Shell.run("git", arguments, in: repoRoot)
        guard result.succeeded else {
            throw ToolError(command: "git diff \(base)...\(head)", result: result)
        }
        return String(decoding: result.stdout, as: UTF8.self)
    }
}
