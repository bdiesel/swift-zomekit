import Foundation
import RealityKit
import ZomeKit

/// Triangulates the floor polygon returned by `Zome.floorPolygon` into a
/// flat horizontal mesh suitable for rendering as a single ModelEntity
/// below the dome's footings.
@MainActor
public enum FloorMesh {
    /// Build a triangle-fan mesh from a polygon's perimeter vertices,
    /// fanning from the centroid. Returns `nil` if fewer than 3 points.
    public static func generate(polygon: [Vec3], scale: Float = 1.0) throws -> MeshResource? {
        guard polygon.count >= 3 else { return nil }

        // Centroid (works as the fan apex because the polygon is convex
        // for our axisymmetric domes; not safe for arbitrary concave shapes).
        let centroid = polygon.reduce(Vec3.zero, +) / Double(polygon.count)

        var positions: [SIMD3<Float>] = [SIMD3<Float>(centroid) * scale]
        positions.reserveCapacity(polygon.count + 1)
        for p in polygon {
            positions.append(SIMD3<Float>(p) * scale)
        }

        var indices: [UInt32] = []
        indices.reserveCapacity(polygon.count * 3)
        for i in 0..<polygon.count {
            indices.append(0)                                   // centroid
            indices.append(UInt32(1 + i))                       // current
            indices.append(UInt32(1 + ((i + 1) % polygon.count))) // next
        }

        // Up-facing normals — the floor lies in a horizontal plane.
        let normals = Array(repeating: SIMD3<Float>(0, 1, 0), count: positions.count)

        var descriptor = MeshDescriptor(name: "floor")
        descriptor.positions = MeshBuffer(positions)
        descriptor.normals = MeshBuffer(normals)
        descriptor.primitives = .triangles(indices)
        return try MeshResource.generate(from: [descriptor])
    }
}
