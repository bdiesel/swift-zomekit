import SwiftUI
import ZomeKit

/// App-icon artwork derived from the zome's actual top-down geometry.
///
/// Three layers, designed to feel right under macOS / visionOS Liquid Glass:
///
/// - `ZomeIconBackLayer`  — twilight-to-amber gradient (the "sky").
/// - `ZomeIconMiddleLayer` — the dome's timber framework projected down the
///   Y axis. Each kite, triangle, and pentagon face is a stroked polygon.
///   Drawn twice (halo underneath, crisp line on top) so the framework
///   reads at small sizes and glows under glass refraction.
/// - `ZomeIconFrontLayer`  — a luminous apex dot. On visionOS this is the
///   layer that lifts off the surface as the user moves their head.
///
/// `ZomeIcon` composes the three. Use it as a single view for previewing
/// or rendering a flat-PNG icon (macOS, iOS); render the layers separately
/// to populate a visionOS solid-image-stack asset.
public struct ZomeIcon: View {
    public let params: ZomeParameters

    public init(params: ZomeParameters = .goodKarmaDefault) {
        self.params = params
    }

    public var body: some View {
        ZStack {
            ZomeIconBackLayer()
            ZomeIconMiddleLayer(params: params)
            ZomeIconFrontLayer()
        }
    }
}

// MARK: - Back layer

public struct ZomeIconBackLayer: View {
    public init() {}

    public var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.04, green: 0.06, blue: 0.20),  // midnight indigo
                        Color(red: 0.16, green: 0.10, blue: 0.34),  // deep purple
                        Color(red: 0.74, green: 0.34, blue: 0.18),  // warm rust
                        Color(red: 0.98, green: 0.78, blue: 0.34),  // amber glow
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Soft vignette pulls the eye toward the centre and helps
                // the timber framework pop against the warmer base of the
                // gradient.
                let r = max(geo.size.width, geo.size.height)
                RadialGradient(
                    colors: [.clear, .black.opacity(0.40)],
                    center: .center,
                    startRadius: r * 0.30,
                    endRadius: r * 0.78
                )
                .blendMode(.multiply)
            }
        }
    }
}

// MARK: - Middle layer (the framework)

public struct ZomeIconMiddleLayer: View {
    public let params: ZomeParameters

    public init(params: ZomeParameters = .goodKarmaDefault) {
        self.params = params
    }

    public var body: some View {
        Canvas { context, size in
            let geom = Zome.build(params)

            // Find max radial extent in the XZ plane so we can scale the
            // projection to fill ~85% of the icon.
            var maxR: Double = 0
            for face in geom.faces {
                for p in face.points {
                    let r = (p.x * p.x + p.z * p.z).squareRoot()
                    if r > maxR { maxR = r }
                }
            }
            guard maxR > 0 else { return }

            let cx = size.width / 2
            let cy = size.height / 2
            let radius = min(size.width, size.height) * 0.42
            let scale = radius / CGFloat(maxR)
            let line = min(size.width, size.height) / 280   // crisp at any size

            // For each spiral angle, rotate the wedge faces around Y and
            // project to screen. Stroke twice — halo + crisp line — so the
            // framework reads at small sizes and glows under Liquid Glass.
            for spiralAngle in geom.rotationAngles {
                let cosA = cos(spiralAngle)
                let sinA = sin(spiralAngle)

                for face in geom.faces {
                    var path = Path()
                    for (i, p) in face.points.enumerated() {
                        let rx = p.x * cosA + p.z * sinA
                        let rz = -p.x * sinA + p.z * cosA
                        let sx = cx + CGFloat(rx) * scale
                        let sy = cy - CGFloat(rz) * scale
                        if i == 0 {
                            path.move(to: CGPoint(x: sx, y: sy))
                        } else {
                            path.addLine(to: CGPoint(x: sx, y: sy))
                        }
                    }
                    path.closeSubpath()

                    // Halo underneath
                    context.stroke(
                        path,
                        with: .color(.white.opacity(0.35)),
                        style: StrokeStyle(lineWidth: line * 3.5, lineJoin: .round)
                    )
                    // Crisp line on top
                    context.stroke(
                        path,
                        with: .color(.white.opacity(0.95)),
                        style: StrokeStyle(lineWidth: line, lineJoin: .round)
                    )
                }
            }
        }
    }
}

// MARK: - Front layer (apex highlight)

public struct ZomeIconFrontLayer: View {
    public init() {}

    public var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                // Soft halo
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.85),
                                Color.white.opacity(0.10),
                                Color.white.opacity(0)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: s * 0.18
                        )
                    )
                    .frame(width: s * 0.42, height: s * 0.42)
                    .blur(radius: s / 80)

                // Bright apex dot
                Circle()
                    .fill(Color.white)
                    .frame(width: s * 0.07, height: s * 0.07)
                    .shadow(color: .white, radius: s / 60)
            }
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }
}

// MARK: - Previews

#Preview("Composite") {
    ZomeIcon()
        .frame(width: 1024, height: 1024)
}

#Preview("Layers") {
    HStack(spacing: 20) {
        ZomeIconBackLayer()
            .frame(width: 220, height: 220)
        ZomeIconMiddleLayer()
            .frame(width: 220, height: 220)
        ZomeIconFrontLayer()
            .frame(width: 220, height: 220)
        ZomeIcon()
            .frame(width: 220, height: 220)
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}

#Preview("Sizes") {
    HStack(spacing: 12) {
        ZomeIcon().frame(width: 256, height: 256)
        ZomeIcon().frame(width: 128, height: 128)
        ZomeIcon().frame(width: 64,  height: 64)
        ZomeIcon().frame(width: 32,  height: 32)
    }
    .padding()
}
