// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ZomeKit",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .visionOS(.v1),
        .tvOS(.v16),
        // watchOS intentionally omitted — RealityKit isn't available there
        // and the ZomeRendering target needs it.
    ],
    products: [
        // Pure-Swift math library (no RealityKit / SwiftUI deps).
        .library(name: "ZomeKit", targets: ["ZomeKit"]),
        // RealityKit + SwiftUI rendering helpers built on ZomeKit.
        .library(name: "ZomeRendering", targets: ["ZomeRendering"]),
    ],
    targets: [
        .target(name: "ZomeKit"),
        .target(name: "ZomeRendering", dependencies: ["ZomeKit"]),
        .testTarget(name: "ZomeKitTests", dependencies: ["ZomeKit"]),
    ]
)
