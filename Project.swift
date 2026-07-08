import ProjectDescription

let project = Project(
    name: "HarvestBin",
    organizationName: "BrightDigit",
    packages: [
      .package(path: "./Packages/HarvestBinKit")
    ],
    targets: [
        .target(
            name: "HarvestBin",
            destinations: .macOS,
            product: .app,
            bundleId: "com.brightdigit.HarvestBin",
            deploymentTargets: .macOS("14.0"),
            infoPlist: .default,
            sources: ["HarvestBin/Sources/**"],
            resources: ["HarvestBin/Resources/**"],
            dependencies: [
                .package(product: "HarvestBinKit")
            ]
        ),
        .target(
            name: "HarvestBinTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "com.brightdigit.HarvestBinTests",
            deploymentTargets: .macOS("14.0"),
            infoPlist: .default,
            sources: ["HarvestBin/Tests/**"],
            resources: [],
            dependencies: [.target(name: "HarvestBin")]
        ),
    ],
    additionalFiles: [
      .folderReference(path: "_archive")
    ]
)
