import ArgumentParser
import Foundation
import GitHubClient
import PRCoverageCore

@main
struct SwiftPRCoverage: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swift-pr-coverage",
        abstract: "Report the changed Swift lines that no test executed."
    )

    enum OutputFormat: String, ExpressibleByArgument, CaseIterable {
        case text
        case markdown
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

    @Flag(help: "Create or update the sticky PR comment. Needs GITHUB_TOKEN.")
    var postComment = false

    @Option(help: "GitHub repository (owner/name) for links and the comment. Defaults to $GITHUB_REPOSITORY.")
    var repo: String?

    @Option(help: "Pull request number. Defaults to the number in $GITHUB_EVENT_PATH.")
    var pr: Int?

    @Option(help: "Commit that line links point to. Defaults to the commit --head resolves to.")
    var headSha: String?

    @Option(help: ArgumentHelp("Above this many changed files, read the whole coverage archive instead of one file at a time.", visibility: .hidden))
    var fullDumpThreshold = 20

    private var environment: [String: String] { ProcessInfo.processInfo.environment }

    func run() async throws {
        let root = try repoRoot.map(absolute) ?? Git.topLevel(from: FileManager.default.currentDirectoryPath)
        let report = try await makeReport(repoRoot: root)
        let markdown = MarkdownRenderer(links: links(repoRoot: root))

        switch output {
        case .text:
            print(TextRenderer.render(report), terminator: "")
        case .markdown:
            print(markdown.render(report), terminator: "")
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            print(String(decoding: try encoder.encode(report), as: UTF8.self))
        }

        if postComment {
            try await post(markdown.render(report), report: report)
        }
    }

    private func makeReport(repoRoot: String) async throws -> CoverageReport {
        let diffText = try diff.map { try String(contentsOfFile: $0, encoding: .utf8) }
            ?? Git.swiftDiff(base: base, head: head, in: repoRoot)

        let excludes = (noDefaultExcludes ? [] : Glob.defaultExcludes) + exclude.map(Glob.init)
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
                maps.append(try await coverage(of: candidates, in: bundle, repoRoot: repoRoot))
            }
            report = Analyzer(excludes: excludes).analyze(changes: changes, coverage: CoverageParser.merge(maps))

            let failed = bundles.compactMap(XCResultTool.testSummary).filter(\.hasFailures)
            if !failed.isEmpty {
                let count = failed.reduce(0) { $0 + $1.failedTests }
                warnings.insert(TestSummary.failureWarning(failedTests: count), at: 0)
            }
        }
        report.warnings += warnings
        return report
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

    /// Links need a repository and a commit; without either, paths render as plain code.
    private func links(repoRoot: String) -> MarkdownRenderer.Links? {
        guard let repository = repo ?? environment["GITHUB_REPOSITORY"],
              let commit = headSha ?? (try? Git.resolveCommit(head, in: repoRoot))
        else { return nil }
        return MarkdownRenderer.Links(
            serverURL: environment["GITHUB_SERVER_URL"] ?? "https://github.com",
            repository: repository,
            commit: commit
        )
    }

    private func post(_ body: String, report: CoverageReport) async throws {
        guard let token = environment["GITHUB_TOKEN"], !token.isEmpty else {
            throw ToolError("--post-comment needs a token in GITHUB_TOKEN.")
        }
        guard let repository = repo ?? environment["GITHUB_REPOSITORY"] else {
            throw ToolError("--post-comment needs --repo or GITHUB_REPOSITORY.")
        }
        guard let number = pr ?? pullRequestFromEvent() else {
            throw ToolError("--post-comment needs --pr, or GITHUB_EVENT_PATH from a pull_request event.")
        }

        let apiURL = environment["GITHUB_API_URL"].flatMap(URL.init(string:)) ?? URL(string: "https://api.github.com")!
        let client = GitHubClient(token: token, apiURL: apiURL)
        // Don't open a new comment just to say nothing changed; do overwrite a stale one.
        let hasFindings = report.files.contains { $0.executableLines > 0 } || !report.filesWithoutCoverage.isEmpty

        do {
            switch try await client.upsertComment(
                repository: repository,
                pullRequest: number,
                marker: MarkdownRenderer.marker,
                body: body,
                createIfMissing: hasFindings
            ) {
            case .created(let comment): Log.info("Created comment \(comment.htmlURL)")
            case .updated(let comment): Log.info("Updated comment \(comment.htmlURL)")
            case .skipped: Log.info("No existing comment and nothing to report; not creating one.")
            }
        } catch let error as GitHubError where error.isPermissionDenied {
            // Fork PRs get a read-only token. The report is still in the output.
            Log.warning("Could not post the PR comment (\(error)). Pull requests from forks get a read-only token.")
        }
    }

    private func pullRequestFromEvent() -> Int? {
        struct Event: Decodable {
            struct PullRequest: Decodable { let number: Int }
            let pullRequest: PullRequest?

            enum CodingKeys: String, CodingKey {
                case pullRequest = "pull_request"
            }
        }
        guard let path = environment["GITHUB_EVENT_PATH"],
              let data = FileManager.default.contents(atPath: path),
              let event = try? JSONDecoder().decode(Event.self, from: data)
        else { return nil }
        return event.pullRequest?.number
    }

    private func absolute(_ path: String) -> String {
        guard !path.hasPrefix("/") else { return path }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(path)
            .standardizedFileURL
            .path
    }
}
