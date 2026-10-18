import Foundation

/// Execution counts for the executable lines of one source file.
///
/// Lines absent from `counts` are not executable (blank lines, comments, declarations,
/// and trailing lines that xccov omits).
public struct FileCoverage: Sendable, Equatable, Codable {
    public var counts: [Int: Int]

    public init(counts: [Int: Int]) {
        self.counts = counts
    }

    /// Combines two runs of the same file, keeping the highest count per line.
    public func merging(_ other: FileCoverage) -> FileCoverage {
        FileCoverage(counts: counts.merging(other.counts, uniquingKeysWith: max))
    }
}

/// Coverage keyed by the absolute source path recorded in the `.xcresult`.
public typealias CoverageMap = [String: FileCoverage]

public enum CoverageParser {
    /// Parses the output of `xccov view --archive --json`, with or without `--file`.
    ///
    /// Shape: `{ "<abs path>": [{ "line", "isExecutable", "executionCount"?, "subranges"? }] }`.
    public static func parse(_ data: Data) throws -> CoverageMap {
        let decoded = try JSONDecoder().decode([String: [LineEntry]].self, from: data)
        return decoded.mapValues { entries in
            var counts: [Int: Int] = [:]
            for entry in entries where entry.isExecutable {
                counts[entry.line] = entry.executionCount ?? 0
            }
            return FileCoverage(counts: counts)
        }
    }

    /// Merges coverage from several result bundles, keeping the highest count per line.
    public static func merge(_ maps: [CoverageMap]) -> CoverageMap {
        maps.reduce(into: CoverageMap()) { result, map in
            result.merge(map) { $0.merging($1) }
        }
    }

    private struct LineEntry: Decodable {
        let line: Int
        let isExecutable: Bool
        let executionCount: Int?
    }
}
