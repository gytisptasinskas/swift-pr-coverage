import Foundation

/// Markdown for the sticky PR comment and the job summary.
public struct MarkdownRenderer: Sendable {
    /// Identifies the tool's comment among a PR's comments.
    public static let marker = "<!-- swift-pr-coverage -->"

    /// Where file and line links point. Without it, paths render as plain code.
    public struct Links: Sendable, Equatable {
        public var serverURL: String
        public var repository: String
        public var commit: String

        public init(serverURL: String = "https://github.com", repository: String, commit: String) {
            self.serverURL = serverURL
            self.repository = repository
            self.commit = commit
        }
    }

    public var links: Links?
    /// GitHub rejects comments over 65,536 characters; stay well below.
    public var maxLength: Int
    /// Longest list shown inside a collapsed section.
    public var maxListItems: Int

    public init(links: Links? = nil, maxLength: Int = 60_000, maxListItems: Int = 50) {
        self.links = links
        self.maxLength = maxLength
        self.maxListItems = maxListItems
    }

    public func render(_ report: CoverageReport) -> String {
        let rows = report.files.filter { $0.uncoveredLines > 0 }.count
        let full = render(report, tableRows: rows)
        guard full.count > maxLength else { return full }

        // Too long: binary-search the most table rows that fit.
        var best = 0
        var low = 0
        var high = rows - 1
        while low <= high {
            let mid = (low + high) / 2
            if render(report, tableRows: mid).count <= maxLength {
                best = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return render(report, tableRows: best)
    }

    private func render(_ report: CoverageReport, tableRows: Int) -> String {
        var out = [Self.marker, "### Swift PR Code Coverage", ""]

        for warning in report.warnings {
            out += ["> [!WARNING]", "> \(warning)", ""]
        }

        guard report.status == .analyzed else {
            out += ["No tests ran, so there is no coverage to report. Tuist selective testing may have skipped every test target."]
            return out.joined(separator: "\n") + "\n"
        }

        let uncoveredFiles = report.files.filter { $0.uncoveredLines > 0 }
        let coveredFiles = report.files.filter { $0.uncoveredLines == 0 && $0.coveredLines > 0 }

        if let percent = report.coveragePercent {
            if uncoveredFiles.isEmpty {
                out.append("All \(report.executableLines) changed executable lines are covered.")
            } else {
                let rounded = (percent * 10).rounded() / 10
                out.append("**\(rounded)%** of changed executable lines are covered (\(report.coveredLines) of \(report.executableLines)).")
            }
        } else {
            out.append("No executable Swift lines changed.")
        }

        if !uncoveredFiles.isEmpty {
            out += ["", "| File | Covered | Uncovered lines |", "| :--- | ---: | :--- |"]
            for file in uncoveredFiles.prefix(tableRows) {
                let ranges = file.uncoveredRanges.map { rangeLink($0, path: file.path) }.joined(separator: ", ")
                out.append("| \(fileLink(file.path)) | \(file.coveredLines) / \(file.executableLines) | \(ranges) |")
            }
            let hidden = uncoveredFiles.count - tableRows
            if hidden > 0 {
                out.append("| …and \(hidden) more \(hidden == 1 ? "file" : "files") | | |")
            }
        }

        if !coveredFiles.isEmpty {
            out += details(
                summary: "Fully covered (\(count(coveredFiles.count)))",
                items: coveredFiles.map { fileLink($0.path) }
            )
        }

        if !report.filesWithoutCoverage.isEmpty {
            out += details(
                summary: "No coverage data (\(count(report.filesWithoutCoverage.count)))",
                note: "These files are missing from every .xcresult: cached by Tuist, skipped by selective testing, or not instrumented.",
                items: report.filesWithoutCoverage.map(code)
            )
        }

        return out.joined(separator: "\n") + "\n"
    }

    private func details(summary: String, note: String? = nil, items: [String]) -> [String] {
        var out = ["", "<details>", "<summary>\(summary)</summary>", ""]
        if let note {
            out += [note, ""]
        }
        out += items.prefix(maxListItems).map { "- \($0)" }
        if items.count > maxListItems {
            out.append("- …and \(items.count - maxListItems) more")
        }
        out += ["", "</details>"]
        return out
    }

    private func count(_ files: Int) -> String {
        files == 1 ? "1 file" : "\(files) files"
    }

    /// Inline code that is safe inside a table cell.
    private func code(_ path: String) -> String {
        "`" + path.replacingOccurrences(of: "|", with: "\\|") + "`"
    }

    private func fileLink(_ path: String) -> String {
        guard let url = url(for: path) else { return code(path) }
        return "[\(code(path))](\(url))"
    }

    private func rangeLink(_ range: LineRange, path: String) -> String {
        let text = range.start == range.end ? "L\(range.start)" : "L\(range.start)–L\(range.end)"
        guard let url = url(for: path) else { return text }
        let anchor = range.start == range.end ? "#L\(range.start)" : "#L\(range.start)-L\(range.end)"
        return "[\(text)](\(url)\(anchor))"
    }

    private func url(for path: String) -> String? {
        guard let links else { return nil }
        let encoded = path.addingPercentEncoding(withAllowedCharacters: Self.pathAllowed) ?? path
        return "\(links.serverURL)/\(links.repository)/blob/\(links.commit)/\(encoded)"
    }

    /// `urlPathAllowed` without the characters that would end a Markdown link target.
    private static let pathAllowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "()"))
}
