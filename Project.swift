import ProjectDescription

#warning("specify team and minimum OS 13")
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
            infoPlist: .default,
            sources: ["HarvestBin/Sources/**"],
            resources: ["HarvestBin/Resources/**"],
            dependencies: []
        ),
        .target(
            name: "HarvestBinTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "com.brightdigit.HarvestBinTests",
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
