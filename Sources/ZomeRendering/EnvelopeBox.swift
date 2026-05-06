import Foundation
import RealityKit
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import ZomeKit

/// 3D wireframe of the dome's overall envelope (height × diameter × diameter).
/// Dome is axisymmetric around Y; we use the same `diameter` for both X and
/// Z extents — slight over-estimate vs. the true axis-aligned bounding box,
/// but matches the figure shown in cut-list / readout panels.
@MainActor
public enum EnvelopeBox {
    public static func makeEmpty() -> Entity {
        let e = Entity()
        e.name = "envelopeBox"
        e.isEnabled = false      // toggled on by the host when the user asks
        return e
    }

    /// Replace child line segments for the given envelope size.
    public static func populate(_ entity: Entity, envelope: ZomeEnvelope, scale: Float) {
        entity.children.removeAll()

        let width  = Float(envelope.diameter) * scale
        let height = Float(envelope.height)   * scale
        let half   = width / 2

        let lineWidth: Float = 0.003
        let material = lineMaterial()

        // 4 vertical edges.
        let vMesh = MeshResource.generateBox(size: SIMD3<Float>(lineWidth, height, lineWidth))
        for (sx, sz) in [(-half, -half), ( half, -half), (-half,  half), ( half,  half)] {
            let line = ModelEntity(mesh: vMesh, materials: [material])
            line.position = SIMD3<Float>(sx, height / 2, sz)
            entity.addChild(line)
        }

        // 4 horizontal edges along X (top + bottom × ±Z).
        let xMesh = MeshResource.generateBox(size: SIMD3<Float>(width, lineWidth, lineWidth))
        for (y, sz) in [(Float(0), -half), (Float(0), half), (height, -half), (height, half)] {
            let line = ModelEntity(mesh: xMesh, materials: [material])
            line.position = SIMD3<Float>(0, y, sz)
            entity.addChild(line)
        }

        // 4 horizontal edges along Z.
        let zMesh = MeshResource.generateBox(size: SIMD3<Float>(lineWidth, lineWidth, width))
        for (y, sx) in [(Float(0), -half), (Float(0), half), (height, -half), (height, half)] {
            let line = ModelEntity(mesh: zMesh, materials: [material])
            line.position = SIMD3<Float>(sx, y, 0)
            entity.addChild(line)
        }
    }

    private static func lineMaterial() -> UnlitMaterial {
        let color = PlatformColor(red: 0.20, green: 0.55, blue: 0.85, alpha: 1.0)
        var m = UnlitMaterial(color: color)
        m.blending = .transparent(opacity: .init(floatLiteral: 0.85))
        return m
    }
}
