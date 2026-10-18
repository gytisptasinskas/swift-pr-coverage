import Testing
@testable import PRCoverageCore

struct DiffParserTests {
    @Test func parsesFixtureDiff() throws {
        let changes = DiffParser.parse(try Fixture.string("git-diff-unified0.diff"))

        #expect(changes == [
            FileChange(path: "Example/App/Sources/CartModel.swift", addedLines: [19...22, 24...24]),
            FileChange(path: "Example/Core/Sources/Calculator.swift", addedLines: [10...16]),
            FileChange(path: "Example/Core/Sources/PriceFormatter.swift", addedLines: [3...3, 29...45]),
            FileChange(path: "Example/Core/Tests/CoreTests.swift", addedLines: [8...12]),
            FileChange(path: "Example/Workspace.swift", addedLines: [1...9]),
        ])
    }

    @Test func skipsDeletedFilesAndPureDeletions() {
        let diff = """
        diff --git a/Gone.swift b/Gone.swift
        deleted file mode 100644
        --- a/Gone.swift
        +++ /dev/null
        @@ -1,3 +0,0 @@
        -a
        -b
        -c
        diff --git a/Kept.swift b/Kept.swift
        --- a/Kept.swift
        +++ b/Kept.swift
        @@ -4,2 +3,0 @@ struct Kept {
        -x
        -y
        """

        #expect(DiffParser.parse(diff).isEmpty)
    }

    @Test func ignoresContentLinesThatLookLikeHeaders() {
        let diff = """
        diff --git a/A.swift b/A.swift
        --- a/A.swift
        +++ b/A.swift
        @@ -0,0 +1,2 @@
        +++ b/not-a-header
        +@@ -1 +99 @@
        """

        #expect(DiffParser.parse(diff) == [FileChange(path: "A.swift", addedLines: [1...2])])
    }

    @Test func unquotesSpecialPaths() {
        let diff = """
        diff --git "a/Sources/My\\tFile.swift" "b/Sources/My\\tFile.swift"
        --- "a/Sources/My\\tFile.swift"
        +++ "b/Sources/My\\tFile.swift"
        @@ -0,0 +1 @@
        +let x = 1
        diff --git a/Caf\\303\\251.swift b/Caf\\303\\251.swift
        --- "a/Caf\\303\\251.swift"
        +++ "b/Caf\\303\\251.swift"
        @@ -0,0 +1 @@
        +let y = 2
        """

        #expect(DiffParser.parse(diff).map(\.path) == ["Sources/My\tFile.swift", "Café.swift"])
    }

    @Test func emptyDiffHasNoChanges() {
        #expect(DiffParser.parse("").isEmpty)
    }
}
