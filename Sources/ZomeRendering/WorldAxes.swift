import Foundation
import RealityKit
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Builds a SketchUp-style ground grid + color-coded XYZ axes for the scene.
/// All values are in scene units (with ZomeBuilder's default `0.01` scene-unit
/// per inch, the default extent covers ~400″ on a side).
@MainActor
public enum WorldAxes {

    /// Returns an Entity tree containing:
    /// - a faint XZ-plane grid (lines every `gridSpacing` from `-extent`…`+extent`)
    /// - three brighter axis bars from the origin in +X (red), +Y (green), +Z (blue)
    public static func makeReference(
        extent: Float = 2.0,
        gridSpacing: Float = 0.1,
        gridLineWidth: Float = 0.0015,
        axisLength: Float = 1.4,
        axisLineWidth: Float = 0.004
    ) -> Entity {
        let root = Entity()
        root.name = "worldAxes"
        root.addChild(makeGrid(extent: extent, spacing: gridSpacing, lineWidth: gridLineWidth))
        root.addChild(makeAxes(length: axisLength, lineWidth: axisLineWidth))
        return root
    }

    private static func makeGrid(extent: Float, spacing: Float, lineWidth: Float) -> Entity {
        let grid = Entity()
        grid.name = "grid"

        // Lighter line at the major axes; faint everywhere else.
        let minorMaterial = unlitMaterial(white: 0.55, alpha: 0.30)
        let majorMaterial = unlitMaterial(white: 0.40, alpha: 0.55)

        let xLineMesh = MeshResource.generateBox(size: SIMD3<Float>(extent * 2, lineWidth, lineWidth))
        let zLineMesh = MeshResource.generateBox(size: SIMD3<Float>(lineWidth, lineWidth, extent * 2))

        let count = Int((extent / spacing).rounded())
        for i in -count...count {
            let pos = Float(i) * spacing
            let isMajor = (i % 5 == 0) && (i != 0)
            let mat = isMajor ? majorMaterial : minorMaterial

            // Line along +X at z = pos
            let xLine = ModelEntity(mesh: xLineMesh, materials: [mat])
            xLine.position = SIMD3<Float>(0, 0, pos)
            grid.addChild(xLine)

            // Line along +Z at x = pos
            let zLine = ModelEntity(mesh: zLineMesh, materials: [mat])
            zLine.position = SIMD3<Float>(pos, 0, 0)
            grid.addChild(zLine)
        }
        return grid
    }

    private static func makeAxes(length: Float, lineWidth: Float) -> Entity {
        let axes = Entity()
        axes.name = "axes"

        // Each axis bar is rendered slightly above Y=0 so it doesn't z-fight the grid.
        let lift: Float = 0.0008

        // X — red, +X
        let xMesh = MeshResource.generateBox(size: SIMD3<Float>(length, lineWidth, lineWidth))
        let xAxis = ModelEntity(mesh: xMesh, materials: [unlitMaterial(red: 0.85, green: 0.20, blue: 0.20)])
        xAxis.position = SIMD3<Float>(length / 2, lift, 0)
        axes.addChild(xAxis)

        // Y — green, +Y (up)
        let yMesh = MeshResource.generateBox(size: SIMD3<Float>(lineWidth, length, lineWidth))
        let yAxis = ModelEntity(mesh: yMesh, materials: [unlitMaterial(red: 0.20, green: 0.70, blue: 0.25)])
        yAxis.position = SIMD3<Float>(0, length / 2, 0)
        axes.addChild(yAxis)

        // Z — blue, +Z
        let zMesh = MeshResource.generateBox(size: SIMD3<Float>(lineWidth, lineWidth, length))
        let zAxis = ModelEntity(mesh: zMesh, materials: [unlitMaterial(red: 0.20, green: 0.40, blue: 0.95)])
        zAxis.position = SIMD3<Float>(0, lift, length / 2)
        axes.addChild(zAxis)

        return axes
    }

    private static func unlitMaterial(white: CGFloat, alpha: CGFloat) -> UnlitMaterial {
        var m = UnlitMaterial(color: PlatformColor(white: white, alpha: alpha))
        m.blending = .transparent(opacity: .init(floatLiteral: Float(alpha)))
        return m
    }

    private static func unlitMaterial(red: CGFloat, green: CGFloat, blue: CGFloat) -> UnlitMaterial {
        UnlitMaterial(color: PlatformColor(red: red, green: green, blue: blue, alpha: 1.0))
    }
}
