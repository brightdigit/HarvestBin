// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "HarvestBinKit",
    platforms: [
      SupportedPlatform.macOS(.v12),
    SupportedPlatform.iOS(.v15),
    SupportedPlatform.watchOS(.v8),
    SupportedPlatform.tvOS(.v15),
    SupportedPlatform.visionOS(.v1),
    SupportedPlatform.macCatalyst(.v15)
    ],
    dependencies: [
      .package(url: "https://github.com/brightdigit/BushelKit", branch: "subrepo")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "harvestbin",
            dependencies: [
              "HarvestBinKit"
            ]
        ),
        .target(
            name: "HarvestBinKit",
            dependencies: [
              .product(name: "BushelFoundation", package: "BushelKit"),
              .product(name: "BushelGuestProfile", package: "BushelKit"),
              .product(name: "BushelHarvestCore", package: "BushelKit")
            ]
        )
    ]
)
