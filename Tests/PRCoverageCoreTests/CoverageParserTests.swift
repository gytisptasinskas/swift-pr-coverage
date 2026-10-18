import Foundation
import Testing
@testable import PRCoverageCore

struct CoverageParserTests {
    private let calculatorPath = "\(Fixture.repoRoot)/Example/Core/Sources/Calculator.swift"
    private let formatterPath = "\(Fixture.repoRoot)/Example/Core/Sources/PriceFormatter.swift"

    @Test func parsesFullyCoveredFile() throws {
        let map = try CoverageParser.parse(Fixture.data("xccov-file-Calculator.json"))

        let file = try #require(map[calculatorPath])
        #expect(map.count == 1)
        #expect(file.counts.keys.sorted() == [5, 7, 8, 9, 11, 12, 13, 14, 15, 16])
        #expect(file.counts.values.allSatisfy { $0 > 0 })
    }

    @Test func nonExecutableAndTrailingLinesAreAbsent() throws {
        let file = try #require(CoverageParser.parse(Fixture.data("xccov-file-Calculator.json"))[calculatorPath])

        #expect(file.counts[1] == nil)  // import
        #expect(file.counts[10] == nil)  // blank line
        #expect(file.counts[17] == nil)  // closing brace, omitted by xccov
    }

    @Test func usesLineCountAndIgnoresSubranges() throws {
        let file = try #require(CoverageParser.parse(Fixture.data("xccov-file-PriceFormatter.json"))[formatterPath])

        // Line 16 has count 3 with a subrange of count 0 (untested ternary branch).
        #expect(file.counts[16] == 3)
        #expect(file.counts[30] == 0)
        #expect(file.counts[45] == 0)
        #expect(file.counts[29] == nil)
    }

    @Test func parsesFullArchive() throws {
        let map = try CoverageParser.parse(Fixture.data("xccov-archive.json"))
        let listed = try Fixture.lines("xccov-file-list.txt")

        #expect(Set(map.keys) == Set(listed))
        let single = try CoverageParser.parse(Fixture.data("xccov-file-PriceFormatter.json"))
        #expect(map[formatterPath] == single[formatterPath])
    }

    @Test func mergeKeepsHighestCountPerLine() {
        let unit: CoverageMap = [
            "a.swift": FileCoverage(counts: [1: 0, 2: 3, 3: 0]),
            "b.swift": FileCoverage(counts: [1: 1]),
        ]
        let ui: CoverageMap = [
            "a.swift": FileCoverage(counts: [1: 2, 2: 1, 4: 0]),
            "c.swift": FileCoverage(counts: [9: 0]),
        ]

        let merged = CoverageParser.merge([unit, ui])

        #expect(merged["a.swift"] == FileCoverage(counts: [1: 2, 2: 3, 3: 0, 4: 0]))
        #expect(merged["b.swift"] == FileCoverage(counts: [1: 1]))
        #expect(merged["c.swift"] == FileCoverage(counts: [9: 0]))
    }

    @Test func rejectsNonCoverageJSON() {
        #expect(throws: (any Error).self) {
            try CoverageParser.parse(Data("{\"coveredLines\":37}".utf8))
        }
    }
}
