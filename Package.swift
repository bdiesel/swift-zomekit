// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ZomeKit",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .visionOS(.v1),
        .tvOS(.v16),
        .watchOS(.v9),
    ],
    products: [
        .library(name: "ZomeKit", targets: ["ZomeKit"]),
    ],
    targets: [
        .target(name: "ZomeKit"),
        .testTarget(name: "ZomeKitTests", dependencies: ["ZomeKit"]),
    ]
)
