import Foundation

/// The parts of `xcresulttool get test-results summary` output this tool needs.
public struct TestSummary: Sendable, Equatable, Decodable {
    /// `Passed`, `Failed`, `Skipped`, ...
    public var result: String
    public var failedTests: Int

    public init(result: String, failedTests: Int) {
        self.result = result
        self.failedTests = failedTests
    }

    public var hasFailures: Bool {
        result == "Failed" || failedTests > 0
    }

    public static func parse(_ data: Data) throws -> TestSummary {
        try JSONDecoder().decode(TestSummary.self, from: data)
    }

    /// Warning for reports built from a run with failures: targets whose tests never ran
    /// are still in the coverage report, with every line at count 0.
    public static func failureWarning(failedTests: Int) -> String {
        let tests = switch failedTests {
        case 0: "Some tests"
        case 1: "1 test"
        default: "\(failedTests) tests"
        }
        return "\(tests) failed. Lines in targets whose tests did not run show as uncovered."
    }
}
