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
        // Internal tool — `swift run IconExporter <out-dir>` writes the
        // app-icon PNGs (composite + each layer) for asset-catalog use.
        // Not exposed as a public product; macOS-only inside.
        .executableTarget(
            name: "IconExporter",
            dependencies: ["ZomeRendering"]
        ),
        .testTarget(name: "ZomeKitTests", dependencies: ["ZomeKit"]),
    ]
)
