import Foundation
import RealityKit
import ZomeKit

/// Indices into a `ZomeTimber`'s 8 corners for its 6 faces, matching
/// builder.rb's PRISM_FACES. Winding is normalized at mesh-build time
/// (each face is flipped if its raw normal points toward the prism
/// centroid), so callers can rely on outward-facing normals regardless
/// of how SketchUp ordered the corners.
private let prismFaces: [(Int, Int, Int, Int)] = [
    (1, 0, 2, 3),   // top      (sits on the outer dome surface)
    (5, 4, 6, 7),   // bottom   (inner)
    (1, 5, 7, 3),   // back
    (0, 4, 6, 2),   // front
    (3, 2, 6, 7),   // right
    (1, 0, 4, 5),   // left
]

extension ZomeTimber {
    /// Flat-shaded `MeshResource` for this 8-vertex prism. Vertices are
    /// duplicated per face so each face gets its own normal — clean
    /// readable timber edges instead of smooth-blended ones.
    @MainActor
    public func meshResource(scale: Float = 1.0) throws -> MeshResource {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        positions.reserveCapacity(prismFaces.count * 4)
        normals.reserveCapacity(prismFaces.count * 4)
        indices.reserveCapacity(prismFaces.count * 6)

        // Pre-scale & convert to Float once.
        let scaled: [SIMD3<Float>] = points.map { SIMD3<Float>($0) * scale }
        let centroid = scaled.reduce(SIMD3<Float>.zero, +) / Float(scaled.count)

        for (i0, i1, i2, i3) in prismFaces {
            let p0 = scaled[i0]
            var p1 = scaled[i1]
            let p2 = scaled[i2]
            var p3 = scaled[i3]

            // Force outward winding: flip the quad if the raw normal points
            // toward the prism centroid. Plane intersections produce slightly
            // non-planar quads, so we take normal from the (p0,p1,p2) tri.
            let faceCenter = (p0 + p1 + p2 + p3) * 0.25
            let outward = faceCenter - centroid
            var n = simd_cross(p1 - p0, p2 - p0)
            if simd_dot(n, outward) < 0 {
                swap(&p1, &p3)              // [p0,p3,p2,p1] = reverse winding
                n = simd_cross(p1 - p0, p2 - p0)
            }
            n = simd_normalize(n)

            let base = UInt32(positions.count)
            positions.append(contentsOf: [p0, p1, p2, p3])
            normals.append(contentsOf: Array(repeating: n, count: 4))
            indices.append(contentsOf: [base, base + 1, base + 2, base, base + 2, base + 3])
        }

        var descriptor = MeshDescriptor(name: "timber")
        descriptor.positions = MeshBuffer(positions)
        descriptor.normals = MeshBuffer(normals)
        descriptor.primitives = .triangles(indices)
        return try MeshResource.generate(from: [descriptor])
    }
}
