import ProjectDescription

let project = Project(
    name: "HarvestBin",
    targets: [
        .target(
            name: "HarvestBin",
            destinations: .macOS,
            product: .app,
            bundleId: "io.tuist.HarvestBin",
            infoPlist: .default,
            sources: ["HarvestBin/Sources/**"],
            resources: ["HarvestBin/Resources/**"],
            dependencies: []
        ),
        .target(
            name: "HarvestBinTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "io.tuist.HarvestBinTests",
            infoPlist: .default,
            sources: ["HarvestBin/Tests/**"],
            resources: [],
            dependencies: [.target(name: "HarvestBin")]
        ),
    ]
)
