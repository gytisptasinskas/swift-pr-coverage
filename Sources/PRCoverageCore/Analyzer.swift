/// An inclusive range of line numbers, e.g. `L42–L48`.
public struct LineRange: Sendable, Equatable, Codable {
    public var start: Int
    public var end: Int

    public init(_ start: Int, _ end: Int) {
        self.start = start
        self.end = end
    }
}

/// Coverage of the changed lines in one file that has coverage data.
public struct FileReport: Sendable, Equatable, Codable {
    public var path: String
    public var coveredLines: Int
    public var uncoveredLines: Int
    /// Uncovered changed lines, merged into ranges. Changed non-executable lines between
    /// two uncovered lines (blank lines, braces) do not split a range.
    public var uncoveredRanges: [LineRange]

    public var executableLines: Int { coveredLines + uncoveredLines }

    public init(path: String, coveredLines: Int, uncoveredLines: Int, uncoveredRanges: [LineRange]) {
        self.path = path
        self.coveredLines = coveredLines
        self.uncoveredLines = uncoveredLines
        self.uncoveredRanges = uncoveredRanges
    }
}

public struct CoverageReport: Sendable, Equatable, Codable {
    public enum Status: String, Sendable, Codable {
        /// Coverage was read and intersected with the diff.
        case analyzed
        /// No `.xcresult` existed, e.g. selective testing had nothing to run.
        case noTestsRan
    }

    public var status: Status
    /// Files with changed lines that have coverage data, sorted by path.
    public var files: [FileReport]
    /// Changed files missing from every `.xcresult` (cached, skipped or not instrumented).
    public var filesWithoutCoverage: [String]
    /// Changed files skipped by `--exclude` patterns.
    public var excludedFiles: [String]
    public var warnings: [String]

    public var coveredLines: Int { files.reduce(0) { $0 + $1.coveredLines } }
    public var executableLines: Int { files.reduce(0) { $0 + $1.executableLines } }

    /// Share of changed executable lines that ran, from 0 to 100, or nil when there are none.
    public var coveragePercent: Double? {
        executableLines == 0 ? nil : Double(coveredLines) * 100 / Double(executableLines)
    }

    public init(
        status: Status,
        files: [FileReport] = [],
        filesWithoutCoverage: [String] = [],
        excludedFiles: [String] = [],
        warnings: [String] = []
    ) {
        self.status = status
        self.files = files
        self.filesWithoutCoverage = filesWithoutCoverage
        self.excludedFiles = excludedFiles
        self.warnings = warnings
    }

    private enum CodingKeys: String, CodingKey {
        case status, files, filesWithoutCoverage, excludedFiles, warnings
        case coveredLines, executableLines, coveragePercent
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decode(Status.self, forKey: .status)
        files = try container.decode([FileReport].self, forKey: .files)
        filesWithoutCoverage = try container.decode([String].self, forKey: .filesWithoutCoverage)
        excludedFiles = try container.decode([String].self, forKey: .excludedFiles)
        warnings = try container.decode([String].self, forKey: .warnings)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(status, forKey: .status)
        try container.encode(coveredLines, forKey: .coveredLines)
        try container.encode(executableLines, forKey: .executableLines)
        try container.encodeIfPresent(coveragePercent, forKey: .coveragePercent)
        try container.encode(files, forKey: .files)
        try container.encode(filesWithoutCoverage, forKey: .filesWithoutCoverage)
        try container.encode(excludedFiles, forKey: .excludedFiles)
        try container.encode(warnings, forKey: .warnings)
    }
}

public struct Analyzer: Sendable {
    public var excludes: [Glob]

    public init(excludes: [Glob] = Glob.defaultExcludes) {
        self.excludes = excludes
    }

    /// Intersects changed lines with coverage keyed by repo-relative path.
    public func analyze(changes: [FileChange], coverage: CoverageMap) -> CoverageReport {
        var files: [FileReport] = []
        var withoutCoverage: [String] = []
        var excluded: [String] = []

        for change in changes.sorted(by: { $0.path < $1.path }) where change.path.hasSuffix(".swift") {
            if excludes.contains(where: { $0.matches(change.path) }) {
                excluded.append(change.path)
            } else if let file = coverage[change.path] {
                files.append(report(for: change, coverage: file))
            } else {
                withoutCoverage.append(change.path)
            }
        }

        return CoverageReport(
            status: .analyzed,
            files: files,
            filesWithoutCoverage: withoutCoverage,
            excludedFiles: excluded
        )
    }

    private func report(for change: FileChange, coverage: FileCoverage) -> FileReport {
        var covered = 0
        var uncovered = 0
        var ranges: [LineRange] = []
        var open: LineRange?
        var previousLine: Int?

        let lines = change.addedLines.flatMap { $0 }.sorted()
        for line in lines {
            // A gap in the changed lines always ends a range.
            if let previous = previousLine, line != previous + 1, let range = open {
                ranges.append(range)
                open = nil
            }
            previousLine = line

            switch coverage.counts[line] {
            case .none:
                // Not executable: keeps an open range open, so it can bridge two uncovered lines.
                continue
            case .some(0):
                uncovered += 1
                if open == nil {
                    open = LineRange(line, line)
                } else {
                    open?.end = line
                }
            case .some:
                covered += 1
                if let range = open {
                    ranges.append(range)
                    open = nil
                }
            }
        }
        if let range = open {
            ranges.append(range)
        }

        return FileReport(
            path: change.path,
            coveredLines: covered,
            uncoveredLines: uncovered,
            uncoveredRanges: ranges
        )
    }
}
