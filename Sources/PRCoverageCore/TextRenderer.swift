/// Plain-text report for local runs.
public enum TextRenderer {
    public static func render(_ report: CoverageReport) -> String {
        var out: [String] = []

        switch report.status {
        case .noTestsRan:
            out.append("No tests ran, so there is no coverage to report (no .xcresult found).")
        case .analyzed:
            out.append(summary(report))
            let tested = report.files.filter { $0.executableLines > 0 }
            if !tested.isEmpty {
                out.append("")
                let width = tested.map(\.path.count).max() ?? 0
                for file in tested {
                    let padding = String(repeating: " ", count: width - file.path.count)
                    out.append("\(file.path)\(padding)  \(file.coveredLines)/\(file.executableLines) covered")
                    if !file.uncoveredRanges.isEmpty {
                        out.append("  uncovered: " + file.uncoveredRanges.map(format).joined(separator: ", "))
                    }
                }
            }
            if !report.filesWithoutCoverage.isEmpty {
                out.append("")
                out.append("No coverage data (cached, skipped or not instrumented):")
                out.append(contentsOf: report.filesWithoutCoverage.map { "  \($0)" })
            }
        }

        if !report.warnings.isEmpty {
            out.append("")
            out.append(contentsOf: report.warnings.map { "warning: \($0)" })
        }
        return out.joined(separator: "\n") + "\n"
    }

    public static func format(_ range: LineRange) -> String {
        range.start == range.end ? "L\(range.start)" : "L\(range.start)–L\(range.end)"
    }

    private static func summary(_ report: CoverageReport) -> String {
        guard let percent = report.coveragePercent else {
            return "No executable Swift lines changed."
        }
        let rounded = (percent * 10).rounded() / 10
        return "Diff coverage: \(report.coveredLines) of \(report.executableLines) changed executable lines covered (\(rounded)%)."
    }
}
