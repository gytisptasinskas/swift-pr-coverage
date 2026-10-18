import Foundation

/// A path glob: `**` matches any number of path components, `*` and `?` stay within one.
public struct Glob: Sendable, Equatable, CustomStringConvertible {
    public let pattern: String
    private let regex: NSRegularExpression

    public init(_ pattern: String) {
        self.pattern = pattern
        self.regex = Self.compile(pattern)
    }

    public var description: String { pattern }

    public func matches(_ path: String) -> Bool {
        let range = NSRange(path.startIndex..., in: path)
        return regex.firstMatch(in: path, range: range) != nil
    }

    public static func == (lhs: Glob, rhs: Glob) -> Bool {
        lhs.pattern == rhs.pattern
    }

    private static func compile(_ pattern: String) -> NSRegularExpression {
        var regex = "^"
        let chars = Array(pattern)
        var index = 0
        while index < chars.count {
            let char = chars[index]
            if char == "*", index + 1 < chars.count, chars[index + 1] == "*" {
                index += 2
                if index < chars.count, chars[index] == "/" {
                    regex += "(?:.*/)?"
                    index += 1
                } else {
                    regex += ".*"
                }
                continue
            }
            switch char {
            case "*": regex += "[^/]*"
            case "?": regex += "[^/]"
            default: regex += NSRegularExpression.escapedPattern(for: String(char))
            }
            index += 1
        }
        regex += "$"
        // Patterns are escaped above, so compilation cannot fail.
        return try! NSRegularExpression(pattern: regex)
    }
}

extension Glob {
    /// Tuist-generated sources and manifests, which never carry useful coverage.
    public static let defaultExcludes: [Glob] = [
        "**/Derived/**",
        "**/Project.swift",
        "**/Workspace.swift",
        "**/Tuist.swift",
        "**/Tuist/**",
    ].map(Glob.init)
}
