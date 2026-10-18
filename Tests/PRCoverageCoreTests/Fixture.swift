import Foundation

/// Files under `Fixtures/`. Paths inside them use the root `/Users/runner/work/repo/repo`.
enum Fixture {
    static let repoRoot = "/Users/runner/work/repo/repo"

    static func data(_ name: String) throws -> Data {
        let url = (Bundle.module.resourceURL ?? Bundle.module.bundleURL)
            .appendingPathComponent("Fixtures")
            .appendingPathComponent(name)
        return try Data(contentsOf: url)
    }

    static func string(_ name: String) throws -> String {
        String(decoding: try data(name), as: UTF8.self)
    }

    static func lines(_ name: String) throws -> [String] {
        try string(name).split(separator: "\n").map(String.init)
    }
}
