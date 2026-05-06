import Foundation
import RealityKit
import ZomeKit

/// Indices into a `ZomeTimber`'s 8 corners for its 6 faces, matching
/// builder.rb's PRISM_FACES. Winding is normalized at build time (each
/// face is flipped if its raw normal points toward the prism centroid),
/// so callers can rely on outward-facing normals regardless of how
/// SketchUp ordered the corners.
private let prismFaces: [(Int, Int, Int, Int)] = [
    (1, 0, 2, 3),   // top      (sits on the outer dome surface)
    (5, 4, 6, 7),   // bottom   (inner)
    (1, 5, 7, 3),   // back
    (0, 4, 6, 2),   // front
    (3, 2, 6, 7),   // right
    (1, 0, 4, 5),   // left
]

extension ZomeTimber {
    /// Build a flat-shaded `MeshDescriptor` for this 8-vertex prism.
    ///
    /// **Pure data — safe to call from any actor.** Use this when you want
    /// to compute mesh geometry on a background task and only hop to the
    /// main actor for the RealityKit upload step.
    ///
    /// Vertices are duplicated per face so each face gets its own normal,
    /// giving clean readable timber edges instead of smooth-blended ones.
    public func meshDescriptor(scale: Float = 1.0) -> MeshDescriptor {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var uvs: [SIMD2<Float>] = []
        var indices: [UInt32] = []
        positions.reserveCapacity(prismFaces.count * 4)
        normals.reserveCapacity(prismFaces.count * 4)
        uvs.reserveCapacity(prismFaces.count * 4)
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
            var flipped = false
            if simd_dot(n, outward) < 0 {
                swap(&p1, &p3)              // [p0,p3,p2,p1] = reverse winding
                n = simd_cross(p1 - p0, p2 - p0)
                flipped = true
            }
            n = simd_normalize(n)

            // Per-face UVs spanning the quad — the longest face edge gets
            // mapped to the U axis so a horizontally-striped wood texture's
            // grain runs along the timber's long axis.
            let edge0 = simd_length(p1 - p0)
            let edge1 = simd_length(p2 - p1)
            let longerIsP0P1 = edge0 >= edge1
            // Two layouts: long edge along U or along V. Either way each
            // quad is mapped to (0,0)-(1,1), so the texture wraps once.
            let quadUVs: [SIMD2<Float>] = longerIsP0P1
                ? [.init(0, 0), .init(1, 0), .init(1, 1), .init(0, 1)]
                : [.init(0, 0), .init(0, 1), .init(1, 1), .init(1, 0)]
            // If we flipped the winding above, mirror UVs so the texture
            // doesn't appear mirrored on those faces.
            let finalUVs = flipped
                ? [quadUVs[0], quadUVs[3], quadUVs[2], quadUVs[1]]
                : quadUVs

            let base = UInt32(positions.count)
            positions.append(contentsOf: [p0, p1, p2, p3])
            normals.append(contentsOf: Array(repeating: n, count: 4))
            uvs.append(contentsOf: finalUVs)
            indices.append(contentsOf: [base, base + 1, base + 2, base, base + 2, base + 3])
        }

        var descriptor = MeshDescriptor(name: "timber")
        descriptor.positions = MeshBuffer(positions)
        descriptor.normals = MeshBuffer(normals)
        descriptor.textureCoordinates = MeshBuffer(uvs)
        descriptor.primitives = .triangles(indices)
        return descriptor
    }

    /// Convenience: build the descriptor and upload it to RealityKit in
    /// one call. Lives on `MainActor` because that's where
    /// `MeshResource.generate(from:)` is required to run — not because
    /// the descriptor work needs the main thread.
    @MainActor
    public func meshResource(scale: Float = 1.0) throws -> MeshResource {
        try MeshResource.generate(from: [meshDescriptor(scale: scale)])
    }
}
