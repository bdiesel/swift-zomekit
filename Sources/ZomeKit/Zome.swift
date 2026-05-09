import Foundation

/// Bounding extents of the generated wedge, doubled around the Y axis to give
/// the full dome's footprint (since the wedge rotates `N` times into a circle).
public struct ZomeEnvelope: Equatable, Sendable {
    public let height: Double
    public let diameter: Double
    public let timbersPerSpiral: Int
    public let facesPerSpiral: Int
}

/// Output of `Zome.build` — the first-spiral wedge and its timbers.
/// Replicate by rotating around Y by `2π i / N` for i in 1..<N.
public struct ZomeGeometry: Sendable {
    public let parameters: ZomeParameters
    public let faces: [ZomeFace]
    public let faceTimbers: [[ZomeTimber]]
    public let crownCount: Int
    public let totalHeight: Double
    public let envelope: ZomeEnvelope
    public let rotationAngles: [Double]
    public let vanishingPoint: Vec3

    /// All timbers in the wedge as a flat array.
    public var allTimbers: [ZomeTimber] { faceTimbers.flatMap { $0 } }
}

public enum Zome {
    /// Build the outer-shell wedge and per-edge timber prisms for `params`.
    public static func build(_ params: ZomeParameters) -> ZomeGeometry {
        var gen = Generator(params: params)
        gen.build()

        let totalHeight = params.totalHeight
        let vanishingY = params.vanishingY ?? (params.zomeHeight - totalHeight / 2.0)
        let vanishingPt = Vec3(0, vanishingY, 0)

        let faceTimbers = gen.faces.map { face in
            TimberBuilder.build(
                face: face.points,
                vanishingPoint: vanishingPt,
                timberThickness: params.timberThickness,
                timberWidth: params.timberWidth,
                assemblyMethod: params.assemblyMethod
            )
        }

        let env = computeEnvelope(faces: gen.faces, faceTimbers: faceTimbers)

        return ZomeGeometry(
            parameters: params,
            faces: gen.faces,
            faceTimbers: faceTimbers,
            crownCount: gen.crownCount,
            totalHeight: totalHeight,
            envelope: env,
            rotationAngles: gen.rotationAngles,
            vanishingPoint: vanishingPt
        )
    }

    private static func computeEnvelope(
        faces: [ZomeFace],
        faceTimbers: [[ZomeTimber]]
    ) -> ZomeEnvelope {
        var maxR = 0.0
        var maxY = -Double.infinity
        var minY = Double.infinity
        for face in faces {
            for p in face.points {
                let r = (p.x * p.x + p.z * p.z).squareRoot()
                if r > maxR { maxR = r }
                if p.y > maxY { maxY = p.y }
                if p.y < minY { minY = p.y }
            }
        }
        let timbersPerSpiral = faceTimbers.reduce(0) { $0 + $1.count }
        return ZomeEnvelope(
            height: maxY - minY,
            diameter: maxR * 2.0,
            timbersPerSpiral: timbersPerSpiral,
            facesPerSpiral: faces.count
        )
    }
}
