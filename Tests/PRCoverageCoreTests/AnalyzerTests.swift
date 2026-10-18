import Testing
@testable import PRCoverageCore

struct AnalyzerTests {
    /// The fixture pipeline: diff ∩ full archive, as documented in `Fixtures/README.md`.
    private func fixtureReport(excludes: [Glob] = Glob.defaultExcludes) throws -> CoverageReport {
        let changes = DiffParser.parse(try Fixture.string("git-diff-unified0.diff"))
        let archive = try CoverageParser.parse(Fixture.data("xccov-archive.json"))
        let normalizer = PathNormalizer(repoRoot: Fixture.repoRoot, recordedPaths: Array(archive.keys))
        let coverage = normalizer.coverage(archive, forRelative: changes.map(\.path))
        return Analyzer(excludes: excludes).analyze(changes: changes, coverage: coverage)
    }

    @Test func fixtureDiffAgainstArchive() throws {
        let report = try fixtureReport()

        #expect(report.status == .analyzed)
        #expect(report.files == [
            FileReport(
                path: "Example/App/Sources/CartModel.swift",
                coveredLines: 1, uncoveredLines: 3,
                uncoveredRanges: [LineRange(19, 21)]
            ),
            FileReport(
                path: "Example/Core/Sources/Calculator.swift",
                coveredLines: 6, uncoveredLines: 0,
                uncoveredRanges: []
            ),
            // Line 37 is blank, so 30–36 and 38–45 merge into one range.
            FileReport(
                path: "Example/Core/Sources/PriceFormatter.swift",
                coveredLines: 0, uncoveredLines: 15,
                uncoveredRanges: [LineRange(30, 45)]
            ),
        ])
        #expect(report.filesWithoutCoverage == ["Example/Core/Tests/CoreTests.swift"])
        #expect(report.excludedFiles == ["Example/Workspace.swift"])
        #expect(report.coveredLines == 7)
        #expect(report.executableLines == 25)
    }

    @Test func withoutDefaultExcludesManifestHasNoData() throws {
        let report = try fixtureReport(excludes: [])

        #expect(report.filesWithoutCoverage == ["Example/Core/Tests/CoreTests.swift", "Example/Workspace.swift"])
        #expect(report.excludedFiles.isEmpty)
    }

    @Test func customExcludeSkipsTests() throws {
        let report = try fixtureReport(excludes: Glob.defaultExcludes + [Glob("**/Tests/**")])

        #expect(report.filesWithoutCoverage.isEmpty)
        #expect(report.excludedFiles == ["Example/Core/Tests/CoreTests.swift", "Example/Workspace.swift"])
    }

    @Test func gapInChangedLinesSplitsRanges() {
        let change = FileChange(path: "A.swift", addedLines: [1...2, 4...5])
        let coverage: CoverageMap = ["A.swift": FileCoverage(counts: [1: 0, 2: 0, 3: 0, 4: 0, 5: 0])]

        let report = Analyzer().analyze(changes: [change], coverage: coverage)

        #expect(report.files.first?.uncoveredRanges == [LineRange(1, 2), LineRange(4, 5)])
    }

    @Test func coveredLineSplitsRanges() {
        let change = FileChange(path: "A.swift", addedLines: [1...5])
        let coverage: CoverageMap = ["A.swift": FileCoverage(counts: [1: 0, 2: 0, 3: 4, 5: 0])]

        let report = Analyzer().analyze(changes: [change], coverage: coverage)

        #expect(report.files.first?.uncoveredRanges == [LineRange(1, 2), LineRange(5, 5)])
        #expect(report.files.first?.coveredLines == 1)
        #expect(report.files.first?.uncoveredLines == 3)
    }

    @Test func trailingNonExecutableLinesDoNotExtendRange() {
        let change = FileChange(path: "A.swift", addedLines: [1...4])
        let coverage: CoverageMap = ["A.swift": FileCoverage(counts: [2: 0])]

        let report = Analyzer().analyze(changes: [change], coverage: coverage)

        #expect(report.files.first?.uncoveredRanges == [LineRange(2, 2)])
    }

    @Test func nonSwiftFilesAreIgnored() {
        let changes = [FileChange(path: "README.md", addedLines: [1...3])]

        let report = Analyzer().analyze(changes: changes, coverage: [:])

        #expect(report.files.isEmpty)
        #expect(report.filesWithoutCoverage.isEmpty)
        #expect(report.coveragePercent == nil)
    }

    @Test func percentOnlyCountsExecutableLines() {
        let report = CoverageReport(status: .analyzed, files: [
            FileReport(path: "A.swift", coveredLines: 3, uncoveredLines: 1, uncoveredRanges: [LineRange(4, 4)]),
            FileReport(path: "B.swift", coveredLines: 0, uncoveredLines: 0, uncoveredRanges: []),
        ])

        #expect(report.coveragePercent == 75)
    }
}
