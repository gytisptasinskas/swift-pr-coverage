import Testing
@testable import PRCoverageCore

struct PathNormalizerTests {
    @Test func stripsRepoRoot() throws {
        let normalizer = PathNormalizer(repoRoot: Fixture.repoRoot, recordedPaths: try Fixture.lines("xccov-file-list.txt"))

        #expect(
            normalizer.recordedPath(forRelative: "Example/Core/Sources/Calculator.swift")
                == "/Users/runner/work/repo/repo/Example/Core/Sources/Calculator.swift"
        )
        #expect(normalizer.recordedPath(forRelative: "Example/Workspace.swift") == nil)
    }

    @Test func acceptsTrailingSlashOnRoot() {
        let normalizer = PathNormalizer(repoRoot: "/w/", recordedPaths: ["/w/A.swift"])

        #expect(normalizer.recordedPath(forRelative: "A.swift") == "/w/A.swift")
    }

    @Test func fallsBackToUniqueSuffixWhenRootDiffers() {
        // Built from /tmp/x, but git reports the resolved /private/tmp/x.
        let normalizer = PathNormalizer(
            repoRoot: "/private/tmp/x",
            recordedPaths: ["/tmp/x/App/Sources/A.swift", "/tmp/x/App/Sources/B.swift"]
        )

        #expect(normalizer.recordedPath(forRelative: "App/Sources/A.swift") == "/tmp/x/App/Sources/A.swift")
    }

    @Test func suffixMatchUsesWholeComponents() {
        let normalizer = PathNormalizer(repoRoot: "/elsewhere", recordedPaths: ["/w/MyA.swift"])

        #expect(normalizer.recordedPath(forRelative: "A.swift") == nil)
    }

    @Test func ambiguousSuffixHasNoMatch() {
        let normalizer = PathNormalizer(
            repoRoot: "/elsewhere",
            recordedPaths: ["/w1/Sources/A.swift", "/w2/Sources/A.swift"]
        )

        #expect(normalizer.recordedPath(forRelative: "Sources/A.swift") == nil)
    }

    @Test func rekeysCoverageByRelativePath() {
        let recorded = "/w/Sources/A.swift"
        let normalizer = PathNormalizer(repoRoot: "/w", recordedPaths: [recorded])
        let file = FileCoverage(counts: [1: 1])

        let rekeyed = normalizer.coverage([recorded: file], forRelative: ["Sources/A.swift", "Sources/B.swift"])

        #expect(rekeyed == ["Sources/A.swift": file])
    }
}
