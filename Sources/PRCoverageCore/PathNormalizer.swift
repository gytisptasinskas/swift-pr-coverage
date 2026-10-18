/// Maps repo-relative diff paths to the absolute paths recorded in an `.xcresult`.
///
/// xccov records the logical path the build ran from and never resolves symlinks, so
/// paths are compared as strings. The repo root prefix is tried first; if that fails
/// (for example the root came from `git rev-parse`, which resolves `/tmp` to
/// `/private/tmp`), a unique suffix match on whole path components is used.
public struct PathNormalizer: Sendable {
    private let recordedByRelative: [String: String]
    private let recordedPaths: [String]

    public init(repoRoot: String, recordedPaths: [String]) {
        let prefix = repoRoot.hasSuffix("/") ? repoRoot : repoRoot + "/"
        var byRelative: [String: String] = [:]
        for path in recordedPaths where path.hasPrefix(prefix) {
            byRelative[String(path.dropFirst(prefix.count))] = path
        }
        self.recordedByRelative = byRelative
        self.recordedPaths = recordedPaths
    }

    /// The recorded absolute path for a repo-relative path, or nil when the file has no coverage.
    public func recordedPath(forRelative relative: String) -> String? {
        if let path = recordedByRelative[relative] {
            return path
        }
        let suffix = "/" + relative
        let matches = recordedPaths.filter { $0.hasSuffix(suffix) }
        return matches.count == 1 ? matches[0] : nil
    }

    /// Re-keys coverage by repo-relative path for the given relative paths.
    public func coverage(_ coverage: CoverageMap, forRelative paths: [String]) -> CoverageMap {
        var result: CoverageMap = [:]
        for relative in paths {
            if let recorded = recordedPath(forRelative: relative), let file = coverage[recorded] {
                result[relative] = file
            }
        }
        return result
    }
}
