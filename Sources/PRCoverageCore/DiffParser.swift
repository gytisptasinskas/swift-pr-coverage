/// Lines added or changed in one file, using the file's path after the change.
public struct FileChange: Sendable, Equatable {
    public var path: String
    public var addedLines: [ClosedRange<Int>]

    public init(path: String, addedLines: [ClosedRange<Int>]) {
        self.path = path
        self.addedLines = addedLines
    }
}

public enum DiffParser {
    /// Parses `git diff --unified=0` output into added line ranges per file.
    ///
    /// Renamed files are reported under their new path. Deleted files and files with
    /// no added lines are left out.
    public static func parse(_ diff: String) -> [FileChange] {
        var changes: [FileChange] = []
        var current: FileChange?
        // True between `diff --git` and the first hunk, where `+++ ` is a header and not content.
        var inFileHeader = false

        func flush() {
            if let change = current, !change.addedLines.isEmpty {
                changes.append(change)
            }
            current = nil
        }

        for line in diff.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix("diff --git ") {
                flush()
                inFileHeader = true
            } else if inFileHeader, line.hasPrefix("+++ ") {
                current = newPath(from: line.dropFirst(4)).map { FileChange(path: $0, addedLines: []) }
            } else if line.hasPrefix("@@ ") {
                inFileHeader = false
                if current != nil, let range = addedRange(inHunkHeader: line) {
                    current?.addedLines.append(range)
                }
            }
        }
        flush()
        return changes
    }

    /// `b/path`, `"b/quoted\tpath"` or `/dev/null`.
    private static func newPath(from field: Substring) -> String? {
        var path = String(field)
        if path.hasPrefix("\"") {
            path = unquote(path)
        }
        if path == "/dev/null" {
            return nil
        }
        if path.hasPrefix("b/") {
            path.removeFirst(2)
        }
        return path
    }

    /// `@@ -a[,b] +c[,d] @@ context`: returns `c...c+d-1`, or nil when `d` is 0.
    private static func addedRange(inHunkHeader header: Substring) -> ClosedRange<Int>? {
        let fields = header.split(separator: " ")
        guard fields.count >= 3, fields[2].hasPrefix("+") else { return nil }
        let parts = fields[2].dropFirst().split(separator: ",")
        guard let start = parts.first.flatMap({ Int($0) }) else { return nil }
        let count = parts.count > 1 ? Int(parts[1]) ?? 0 : 1
        guard count > 0 else { return nil }
        return start...(start + count - 1)
    }

    /// Undoes git's C-style path quoting (`core.quotePath`).
    private static func unquote(_ quoted: String) -> String {
        var bytes: [UInt8] = []
        var iterator = Array(quoted.utf8.dropFirst().dropLast()).makeIterator()
        while let byte = iterator.next() {
            guard byte == UInt8(ascii: "\\"), let escaped = iterator.next() else {
                bytes.append(byte)
                continue
            }
            switch escaped {
            case UInt8(ascii: "n"): bytes.append(0x0A)
            case UInt8(ascii: "t"): bytes.append(0x09)
            case UInt8(ascii: "r"): bytes.append(0x0D)
            case UInt8(ascii: "a"): bytes.append(0x07)
            case UInt8(ascii: "b"): bytes.append(0x08)
            case UInt8(ascii: "f"): bytes.append(0x0C)
            case UInt8(ascii: "v"): bytes.append(0x0B)
            case UInt8(ascii: "0")...UInt8(ascii: "7"):
                var value = escaped - UInt8(ascii: "0")
                for _ in 0..<2 {
                    guard let digit = iterator.next() else { break }
                    value = value &* 8 &+ (digit - UInt8(ascii: "0"))
                }
                bytes.append(value)
            default:
                bytes.append(escaped)
            }
        }
        return String(decoding: bytes, as: UTF8.self)
    }
}
