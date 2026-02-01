// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "HarvestBinKit",
    platforms: [
      SupportedPlatform.macOS(.v12),
    SupportedPlatform.iOS(.v18),
    SupportedPlatform.watchOS(.v11),
    SupportedPlatform.tvOS(.v18),
    SupportedPlatform.visionOS(.v2),
    SupportedPlatform.macCatalyst(.v18)
    ],
    dependencies: [
      .package(path: "../../../BushelKit")
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
        ),
        .testTarget(
            name: "HarvestBinKitTests",
            dependencies: [
              "HarvestBinKit"
            ]
        )
    ]
)
