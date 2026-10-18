import Testing
@testable import PRCoverageCore

struct GlobTests {
    @Test(arguments: [
        ("**/Derived/**", "Example/Derived/Sources/TuistBundle+Core.swift", true),
        ("**/Derived/**", "Derived/Sources/X.swift", true),
        ("**/Derived/**", "Example/NotDerived/X.swift", false),
        ("**/Project.swift", "Project.swift", true),
        ("**/Project.swift", "Example/Project.swift", true),
        ("**/Project.swift", "Example/MyProject.swift", false),
        ("Tests/**", "Tests/A/B.swift", true),
        ("Tests/**", "Example/Tests/B.swift", false),
        ("**/*Tests/**", "Example/Core/CoreTests/A.swift", true),
        ("Sources/*.swift", "Sources/A.swift", true),
        ("Sources/*.swift", "Sources/Sub/A.swift", false),
        ("Sources/?.swift", "Sources/A.swift", true),
        ("App+Extras.swift", "App+Extras.swift", true),
        ("App+Extras.swift", "AppppExtras.swift", false),
    ])
    func matches(pattern: String, path: String, expected: Bool) {
        #expect(Glob(pattern).matches(path) == expected)
    }

    @Test func defaultExcludesCoverTuistFiles() {
        let excluded = [
            "Example/Derived/Sources/TuistAssets+App.swift",
            "Example/Project.swift",
            "Example/Workspace.swift",
            "Tuist.swift",
            "Tuist/Package.swift",
            "Tuist/ProjectDescriptionHelpers/Helpers.swift",
            "Package.swift",
            "Modules/Networking/Package.swift",
        ]
        for path in excluded {
            #expect(Glob.defaultExcludes.contains { $0.matches(path) }, "\(path)")
        }
        #expect(!Glob.defaultExcludes.contains { $0.matches("Example/Core/Sources/Calculator.swift") })
    }
}
