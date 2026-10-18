import ArgumentParser
import Foundation
import PRCoverageCore

@main
struct SwiftPRCoverage: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swift-pr-coverage",
        abstract: "Report the changed Swift lines that no test executed."
    )

    enum OutputFormat: String, ExpressibleByArgument, CaseIterable {
        case text
        case json
    }

    @Option(name: .customLong("xcresult"), help: "Path to an .xcresult bundle. Repeat to merge several (max count per line).")
    var xcresults: [String]

    @Option(help: "Base ref; the diff starts at its merge base with --head.")
    var base = "origin/main"

    @Option(help: "Head ref.")
    var head = "HEAD"

    @Option(help: ArgumentHelp("Read the diff from this file instead of running git diff.", valueName: "file"))
    var diff: String?

    @Option(help: "Repository root that diff paths are relative to. Defaults to the git top level of the current directory.")
    var repoRoot: String?

    @Option(help: "Glob of repo-relative paths to skip, e.g. '**/Tests/**'. Repeatable.")
    var exclude: [String] = []

    @Flag(help: "Don't skip Tuist-generated sources and manifests (**/Derived/**, Project.swift, Workspace.swift, Tuist.swift, Tuist/**).")
    var noDefaultExcludes = false

    @Option(help: "Output format.")
    var output: OutputFormat = .text

    @Option(help: ArgumentHelp("Above this many changed files, read the whole coverage archive instead of one file at a time.", visibility: .hidden))
    var fullDumpThreshold = 20

    func run() async throws {
        let workingDirectory = FileManager.default.currentDirectoryPath
        let root = try repoRoot.map(absolute) ?? Git.topLevel(from: workingDirectory)
        let diffText = try diff.map { try String(contentsOfFile: $0, encoding: .utf8) }
            ?? Git.swiftDiff(base: base, head: head, in: root)

        let excludes = (noDefaultExcludes ? [] : Glob.defaultExcludes) + exclude.map(Glob.init)
        let analyzer = Analyzer(excludes: excludes)
        let changes = DiffParser.parse(diffText)
        let candidates = changes
            .map(\.path)
            .filter { path in path.hasSuffix(".swift") && !excludes.contains { $0.matches(path) } }

        var warnings: [String] = []
        let bundles = xcresults.map(absolute).filter { path in
            guard FileManager.default.fileExists(atPath: path) else {
                warnings.append("\(path) does not exist.")
                return false
            }
            return true
        }

        var report: CoverageReport
        if bundles.isEmpty {
            report = CoverageReport(status: .noTestsRan)
        } else {
            var maps: [CoverageMap] = []
            for bundle in bundles {
                maps.append(try await coverage(of: candidates, in: bundle, repoRoot: root))
            }
            report = analyzer.analyze(changes: changes, coverage: CoverageParser.merge(maps))
        }
        report.warnings += warnings

        switch output {
        case .text:
            print(TextRenderer.render(report), terminator: "")
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            print(String(decoding: try encoder.encode(report), as: UTF8.self))
        }
    }

    /// Coverage of the given repo-relative files, keyed by repo-relative path.
    private func coverage(of relativePaths: [String], in bundle: String, repoRoot: String) async throws -> CoverageMap {
        let normalizer = PathNormalizer(repoRoot: repoRoot, recordedPaths: try XCCov.fileList(bundle))
        let recorded = relativePaths.compactMap(normalizer.recordedPath(forRelative:))
        guard !recorded.isEmpty else { return [:] }

        let raw: CoverageMap
        if recorded.count > fullDumpThreshold {
            raw = try XCCov.coverage(of: bundle)
        } else {
            raw = try await withThrowingTaskGroup(of: CoverageMap.self) { group in
                for path in recorded {
                    group.addTask { try XCCov.coverage(ofFile: path, in: bundle) }
                }
                return try await group.reduce(into: CoverageMap()) { $0.merge($1) { $0.merging($1) } }
            }
        }
        return normalizer.coverage(raw, forRelative: relativePaths)
    }

    private func absolute(_ path: String) -> String {
        guard !path.hasPrefix("/") else { return path }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(path)
            .standardizedFileURL
            .path
    }
}
