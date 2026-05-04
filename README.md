# ZomeKit

A pure-Swift library for generating parametric **zome** geometry — the polyhedral, Steve-Baer-style timber-framed domes built from rotational rings of kite-shaped faces.

ZomeKit is **math only** — no UI, no rendering, no platform-specific frameworks. It produces the outer-shell vertices, per-edge timber prisms, and a grouped cut list. Render the result with RealityKit, SceneKit, Metal, three.js via WASM, or anything else that takes triangles.

> Note: this is *architectural* zomes (Drop City / Steve Baer, 1968 — parametric N-fold rotational domes). It is **not** Zometool, the icosahedral-symmetry construction toy. The two share underlying zonohedral math but are distinct domains.

## Requirements

- Swift 6.0 toolchain (Xcode 16+)
- Apple platforms: macOS 13, iOS 16, visionOS 1, tvOS 16, watchOS 9
- Also builds on Linux (no Apple-only frameworks)

## Install

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/bdiesel/swift-zomekit.git", from: "0.1.0"),
],
targets: [
    .target(
        name: "MyApp",
        dependencies: [
            .product(name: "ZomeKit", package: "swift-zomekit"),
        ]
    ),
]
```

```swift
import ZomeKit
```

## Quick start

```swift
import ZomeKit

let params = ZomeParameters.goodKarmaDefault
//   numSpirals: 10, thetaDegrees: 53.25, kiteRatio: 1,
//   heightRatio: 0.7, zomeHeight: 122,
//   timberWidth: 3.5, timberThickness: 1.5

let geom = Zome.build(params)

print(geom.envelope.height)         // 122.0
print(geom.envelope.diameter)       // 151.0625
print(geom.faces.count)             // first-spiral wedge faces
print(geom.allTimbers.count)        // timbers per spiral

let cutList = CutList.build(geometry: geom, params: params)
// 16 unique sizes, 270 total pieces (10 spirals × 27 timbers/spiral)
print(CutList.csv(cutList))
```

### Building the full dome

`Zome.build(_:)` returns a single `1/N` wedge — one spiral. Replicate it `N` times around the Y axis to assemble the full dome:

```swift
for angle in geom.rotationAngles {
    // rotate `geom.allTimbers` (or the faces) around Y by `angle` and add to your scene
}
```

This keeps the heavy work out of ZomeKit: the wedge is one shared instance and your renderer can use mesh instancing for the rotational copies.

## Public API

| Type | Purpose |
| --- | --- |
| `ZomeParameters` | Inputs (N, θ, kite ratio, height ratio, zome height, timber dims, optional bindu ratios). Unit-agnostic — pass inches or millimetres. |
| `Vec3` | `SIMD3<Double>` typealias plus `cross`, `length`, `normalized`, `midpoint`, `point(from:towards:distance:)`. |
| `Plane` | `ax + by + cz + d = 0`. Build from three points. |
| `intersection(point:direction:plane:)` | Line/plane hit test. |
| `Zome.build(_:)` | Top-level entry — returns `ZomeGeometry`. |
| `ZomeGeometry` | The first-spiral wedge: `faces`, `faceTimbers`, `envelope`, `crownCount`, `rotationAngles`, `vanishingPoint`. |
| `ZomeFace` | One outer kite/triangle/pentagon face: `points`, `crownIndex`, `label`. |
| `ZomeTimber` | One 8-vertex prism (`a…h` accessors). |
| `ZomeEnvelope` | Bounding `height`, `diameter`, `timbersPerSpiral`, `facesPerSpiral`. |
| `CutList.build(geometry:params:)` | Group identical timbers, multiply by N spirals, sort longest first. |
| `CutListEntry` | One row: label `T1…Tn`, quantity, length, two miter angles, dimensions, contributing face labels. |
| `CutList.formatInches(_:)` | Inch-to-`12'-7 1/16"` formatter. |
| `CutList.csv(_:)` | Render rows as a CSV string (no I/O). |
| `CutList.totals(_:)` | Sum of pieces and linear units. |

## Coordinate conventions

- **Y is up.** The apex sits at `(0, zomeHeight, 0)`; the ground plane is `Y = 0`.
- Z+ is "front" (the first spiral's first crown vertex lies on the Z axis).
- Right-handed: `cross(X, Y) = Z`.
- ZomeKit math runs in `Double` precision. Convert to `SIMD3<Float>` at the rendering boundary if your engine wants Float.
- ZomeKit is unit-agnostic. Pass whatever units you like — they propagate unchanged. `CutList.formatInches` is the one helper that assumes inches.

## What "GoodKarma" means

GoodKarma is the timber-assembly method where each timber's faces are framed with planes through the **vanishing point** (a chosen Y-axis point inside the dome) and the face's edge midpoints. The result is timbers that miter cleanly along their length without bevels — the simplest and most-built zome framing style. This is the only assembly method ZomeKit currently implements (clockwise rotation, inward expansion). Beveled and Xpansion methods are planned.

## Status

| Feature | v1 |
| --- | --- |
| Outer-shell geometry | ✅ |
| GoodKarma + clockwise + inward | ✅ |
| Cut list with 1/16″ + 0.5° bucketing | ✅ |
| CSV export | ✅ |
| Roof overflow | ⏳ |
| Footing prisms + floor face | ⏳ |
| Beveled / Xpansion assembly | ⏳ |
| Inner skin | ⏳ |

### Reference golden values

`ZomeParameters.goodKarmaDefault` (N=10, θ=53.25°, K=1, hRatio=0.7, height=122″, timber 3.5×1.5″) produces:

- 270 timbers (27 per spiral × 10 spirals)
- 16 unique cut-list sizes
- Envelope 10′-2″ × 12′-7 1/16″ (122″ × 151.0625″)

These are pinned as Swift Testing assertions in `Tests/ZomeKitTests/ZomeKitTests.swift`.

## Acknowledgements

The geometry is a Swift port of [z5omes](https://github.com/eddymens/z5omes) (`make_zome()` + `Polygon3D.compute_framework`) by Eddy Mens.

Background reading on zonohedral domes:

- Steve Baer, *Zome Primer* (Lama Foundation, 1969).
- Joe Clinton, *Advanced Structural Geometry Studies, Part I & II* (NASA, 1971).
- Wikipedia: [Zonohedron](https://en.wikipedia.org/wiki/Zonohedron), [Rhombic dodecahedron](https://en.wikipedia.org/wiki/Rhombic_dodecahedron).

For the related Zometool construction-toy math (5-fold / 3-fold / 2-fold strut systems):

- Berkeley Math Circle, [*An Introduction to Zometool*](https://mathcircle.berkeley.edu/sites/default/files/archivedocs/2008_2009/lectures/0809lecturespdf/ZomeIntro.pdf).
- Tom Davis, [*The Mathematics of Zome*](http://geometer.org/mathcircles/zome.pdf).

## License

MIT — see [LICENSE](LICENSE).
