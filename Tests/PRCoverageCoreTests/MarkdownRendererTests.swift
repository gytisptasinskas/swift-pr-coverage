import Testing
@testable import PRCoverageCore

struct MarkdownRendererTests {
    private let links = MarkdownRenderer.Links(repository: "octo/app", commit: "abc123")

    private let report = CoverageReport(
        status: .analyzed,
        files: [
            FileReport(path: "App/Cart.swift", coveredLines: 1, uncoveredLines: 3, uncoveredRanges: [LineRange(19, 21)]),
            FileReport(path: "Core/Calculator.swift", coveredLines: 6, uncoveredLines: 0, uncoveredRanges: []),
            FileReport(path: "Core/Comments.swift", coveredLines: 0, uncoveredLines: 0, uncoveredRanges: []),
            FileReport(
                path: "Core/Price.swift", coveredLines: 0, uncoveredLines: 2,
                uncoveredRanges: [LineRange(30, 30), LineRange(40, 41)]
            ),
        ],
        filesWithoutCoverage: ["Core/Tests/CoreTests.swift"],
        excludedFiles: ["Workspace.swift"]
    )

    @Test func rendersWithLinks() {
        #expect(MarkdownRenderer(links: links).render(report) == """
        <!-- swift-pr-coverage -->
        ### Swift PR Code Coverage

        **58.3%** of changed executable lines are covered (7 of 12).

        | File | Covered | Uncovered lines |
        | :--- | ---: | :--- |
        | [`App/Cart.swift`](https://github.com/octo/app/blob/abc123/App/Cart.swift) | 1 / 4 | [L19–L21](https://github.com/octo/app/blob/abc123/App/Cart.swift#L19-L21) |
        | [`Core/Price.swift`](https://github.com/octo/app/blob/abc123/Core/Price.swift) | 0 / 2 | [L30](https://github.com/octo/app/blob/abc123/Core/Price.swift#L30), [L40–L41](https://github.com/octo/app/blob/abc123/Core/Price.swift#L40-L41) |

        <details>
        <summary>Fully covered (1 file)</summary>

        - [`Core/Calculator.swift`](https://github.com/octo/app/blob/abc123/Core/Calculator.swift)

        </details>

        <details>
        <summary>No coverage data (1 file)</summary>

        These files are missing from every .xcresult: cached by Tuist, skipped by selective testing, or not instrumented.

        - `Core/Tests/CoreTests.swift`

        </details>

        """)
    }

    @Test func rendersPlainPathsWithoutLinks() {
        let markdown = MarkdownRenderer().render(report)

        #expect(markdown.contains("| `App/Cart.swift` | 1 / 4 | L19–L21 |"))
        #expect(markdown.contains("| `Core/Price.swift` | 0 / 2 | L30, L40–L41 |"))
        #expect(!markdown.contains("https://"))
    }

    @Test func allCovered() {
        let report = CoverageReport(status: .analyzed, files: [
            FileReport(path: "A.swift", coveredLines: 4, uncoveredLines: 0, uncoveredRanges: []),
        ])

        let markdown = MarkdownRenderer().render(report)

        #expect(markdown.contains("All 4 changed executable lines are covered."))
        #expect(!markdown.contains("| File |"))
    }

    @Test func noExecutableChanges() {
        #expect(MarkdownRenderer().render(CoverageReport(status: .analyzed)) == """
        <!-- swift-pr-coverage -->
        ### Swift PR Code Coverage

        No executable Swift lines changed.

        """)
    }

    @Test func noTestsRanWithWarning() {
        let report = CoverageReport(status: .noTestsRan, warnings: ["build/Tests.xcresult does not exist."])

        #expect(MarkdownRenderer().render(report) == """
        <!-- swift-pr-coverage -->
        ### Swift PR Code Coverage

        > [!WARNING]
        > build/Tests.xcresult does not exist.

        No tests ran, so there is no coverage to report. Tuist selective testing may have skipped every test target.

        """)
    }

    @Test func escapesPathsForTablesAndURLs() {
        let report = CoverageReport(status: .analyzed, files: [
            FileReport(path: "My App/A|B (1).swift", coveredLines: 0, uncoveredLines: 1, uncoveredRanges: [LineRange(3, 3)]),
        ])

        let markdown = MarkdownRenderer(links: links).render(report)

        #expect(markdown.contains("[`My App/A\\|B (1).swift`](https://github.com/octo/app/blob/abc123/My%20App/A%7CB%20%281%29.swift)"))
    }

    @Test func truncatesTableToFitLimit() {
        let files = (1...500).map {
            FileReport(path: "Sources/File\($0).swift", coveredLines: 0, uncoveredLines: 1, uncoveredRanges: [LineRange(1, 1)])
        }
        let report = CoverageReport(status: .analyzed, files: files)

        let markdown = MarkdownRenderer(links: links, maxLength: 10_000).render(report)

        #expect(markdown.count <= 10_000)
        #expect(markdown.contains("File1.swift"))
        #expect(!markdown.contains("File500.swift"))
        #expect(markdown.contains(#/\| …and \d+ more files \| \| \|/#))
    }

    @Test func capsCollapsedLists() {
        let report = CoverageReport(status: .analyzed, filesWithoutCoverage: (1...5).map { "F\($0).swift" })

        let markdown = MarkdownRenderer(maxListItems: 2).render(report)

        #expect(markdown.contains("- `F2.swift`\n- …and 3 more"))
        #expect(!markdown.contains("F3.swift"))
    }
}

struct TestSummaryTests {
    @Test func passedRun() throws {
        let summary = try TestSummary.parse(Fixture.data("test-results-summary-passed.json"))

        #expect(summary == TestSummary(result: "Passed", failedTests: 0))
        #expect(!summary.hasFailures)
    }

    @Test func failedRun() throws {
        let summary = try TestSummary.parse(Fixture.data("test-results-summary-failed.json"))

        #expect(summary == TestSummary(result: "Failed", failedTests: 1))
        #expect(summary.hasFailures)
        #expect(TestSummary.failureWarning(failedTests: 1) == "1 test failed. Lines in targets whose tests did not run show as uncovered.")
    }
}
