import Foundation
import Testing
@testable import PRCoverageCore

struct TextRendererTests {
    @Test func rendersAnalyzedReport() {
        let report = CoverageReport(
            status: .analyzed,
            files: [
                FileReport(path: "App/Cart.swift", coveredLines: 1, uncoveredLines: 3, uncoveredRanges: [LineRange(19, 21)]),
                FileReport(path: "Core/Calculator.swift", coveredLines: 6, uncoveredLines: 0, uncoveredRanges: []),
                FileReport(path: "Core/Comments.swift", coveredLines: 0, uncoveredLines: 0, uncoveredRanges: []),
                FileReport(
                    path: "Core/Price.swift", coveredLines: 0, uncoveredLines: 2,
                    uncoveredRanges: [LineRange(30, 30), LineRange(40, 40)]
                ),
            ],
            filesWithoutCoverage: ["Core/Tests/CoreTests.swift"],
            excludedFiles: ["Workspace.swift"]
        )

        #expect(TextRenderer.render(report) == """
        Diff coverage: 7 of 12 changed executable lines covered (58.3%).

        App/Cart.swift         1/4 covered
          uncovered: L19–L21
        Core/Calculator.swift  6/6 covered
        Core/Price.swift       0/2 covered
          uncovered: L30, L40

        No coverage data (cached, skipped or not instrumented):
          Core/Tests/CoreTests.swift

        """)
    }

    @Test func rendersNoTestsRan() {
        let report = CoverageReport(status: .noTestsRan, warnings: ["build/Tests.xcresult does not exist"])

        #expect(TextRenderer.render(report) == """
        No tests ran, so there is no coverage to report (no .xcresult found).

        warning: build/Tests.xcresult does not exist

        """)
    }

    @Test func rendersNoExecutableChanges() {
        let report = CoverageReport(status: .analyzed)

        #expect(TextRenderer.render(report) == "No executable Swift lines changed.\n")
    }

    @Test func jsonIncludesTotals() throws {
        let report = CoverageReport(status: .analyzed, files: [
            FileReport(path: "A.swift", coveredLines: 1, uncoveredLines: 1, uncoveredRanges: [LineRange(2, 2)]),
        ])

        let data = try JSONEncoder().encode(report)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["coveredLines"] as? Int == 1)
        #expect(object["executableLines"] as? Int == 2)
        #expect(object["coveragePercent"] as? Double == 50)
        #expect(try JSONDecoder().decode(CoverageReport.self, from: data) == report)
    }
}
