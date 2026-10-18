import ProjectDescription

let project = Project(
    name: "Example",
    options: .options(
        automaticSchemesOptions: .enabled(codeCoverageEnabled: true)
    ),
    targets: [
        .target(
            name: "App",
            destinations: .iOS,
            product: .app,
            bundleId: "dev.swiftprcoverage.example.App",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .extendingDefault(
                with: [
                    "UILaunchScreen": [
                        "UIColorName": "",
                        "UIImageName": "",
                    ],
                ]
            ),
            sources: ["App/Sources/**"],
            resources: ["App/Resources/**"],
            dependencies: [.target(name: "Core")]
        ),
        .target(
            name: "AppTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "dev.swiftprcoverage.example.AppTests",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .default,
            sources: ["App/Tests/**"],
            dependencies: [.target(name: "App")]
        ),
        .target(
            name: "Core",
            destinations: .iOS,
            product: .framework,
            bundleId: "dev.swiftprcoverage.example.Core",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .default,
            sources: ["Core/Sources/**"],
            // A resource makes Tuist generate Derived/Sources/TuistBundle+Core.swift.
            resources: ["Core/Resources/**"]
        ),
        .target(
            name: "CoreTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "dev.swiftprcoverage.example.CoreTests",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .default,
            sources: ["Core/Tests/**"],
            dependencies: [.target(name: "Core")]
        ),
    ]
)
