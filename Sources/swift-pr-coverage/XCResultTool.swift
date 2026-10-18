import PRCoverageCore

/// Wraps `xcrun xcresulttool`.
enum XCResultTool {
    /// The bundle's test outcome, or nil when it can't be read (older Xcode, no test action).
    static func testSummary(_ xcresult: String) -> TestSummary? {
        let arguments = ["xcresulttool", "get", "test-results", "summary", "--path", xcresult, "--compact"]
        guard let result = try? Shell.run("xcrun", arguments), result.succeeded else { return nil }
        return try? TestSummary.parse(result.stdout)
    }
}
