import SwiftUI
import simd
import ZomeKit

/// Inline 3D-ish preview of a single timber for cut-list tables.
/// Axonometric projection of the actual 8-vertex prism — three faces visible
/// (top, front, right cap) — so the user sees miter cuts and depth without
/// firing up a per-row RealityView.
public struct TimberSketch: View {
    public let timber: ZomeTimber
    public let lengthHint: Double      // for the rainbow color (matches CutListEntry.length)
    public let maxLength: Double       // longest in the cut list — used to scale all rows uniformly

    /// Length of the longest swatch in pixels. Shorter timbers are scaled
    /// proportionally so relative sizes read at a glance.
    private let maxPixelWidth: CGFloat = 160

    public init(timber: ZomeTimber, lengthHint: Double, maxLength: Double) {
        self.timber = timber
        self.lengthHint = lengthHint
        self.maxLength = maxLength
    }

    public var body: some View {
        Canvas { context, size in
            // 1. Build a local coordinate frame for this timber:
            //    long axis (left-cap center -> right-cap center)
            //    width axis (perp to long, in the "thick" direction)
            //    thickness axis (perp to both)
            // We project onto an isometric-ish 2D space using these axes.
            let frame = TimberFrame(timber)

            // 2. Project all 8 corners into local (length, width, thickness) coords,
            //    centered on the prism centroid.
            let local = timber.points.map { frame.toLocal($0) }

            // 3. Scale so this timber's long axis ≤ the cell's max width budget,
            //    proportional to its share of the longest timber in the list.
            let lengthRatio = max(0.04, lengthHint / max(maxLength, 0.0001))
            let dim = frame.dimensions
            let pixelLength = maxPixelWidth * CGFloat(lengthRatio)
            let pxPerUnit: CGFloat = pixelLength / max(CGFloat(dim.length), 0.0001)

            // 4. Axonometric projection: x_screen = length, y_screen tilts
            //    width down and thickness up at fixed angles. Picks 3 visible
            //    faces and feels 3D without per-pixel work.
            let cos30: CGFloat = 0.866
            let sin30: CGFloat = 0.5
            let centerY = size.height / 2

            func project(_ p: SIMD3<Double>) -> CGPoint {
                let lx = CGFloat(p.x) * pxPerUnit
                let ly = CGFloat(p.y) * pxPerUnit
                let lz = CGFloat(p.z) * pxPerUnit
                // length on screen X; width tilts down-right; thickness up-right
                let sx = lx + ly * cos30 + lz * cos30
                let sy = -lz * sin30 + ly * sin30
                return CGPoint(x: sx, y: sy)
            }

            let projected = local.map(project)

            // Center the projected point cloud in the cell.
            let xs = projected.map(\.x)
            let ys = projected.map(\.y)
            let bbCx = ((xs.min() ?? 0) + (xs.max() ?? 0)) / 2
            let bbCy = ((ys.min() ?? 0) + (ys.max() ?? 0)) / 2
            let cellCx = size.width / 2
            let centered = projected.map { CGPoint(x: cellCx + ($0.x - bbCx), y: centerY + ($0.y - bbCy)) }

            // 5. Draw the 6 quad faces — sort by their world-Z (thickness) so
            //    far ones go first. Light/dark variants from the rainbow color.
            let baseColor = RainbowPalette.swiftUIColor(forLength: lengthHint)
            let stroke = baseColor.opacity(0.55)

            let faces: [(idx: [Int], shade: CGFloat)] = [
                ([1, 0, 2, 3],  0.95),  // top
                ([5, 4, 6, 7],  0.55),  // bottom
                ([0, 4, 6, 2],  0.85),  // front
                ([1, 5, 7, 3],  0.65),  // back
                ([3, 2, 6, 7],  1.00),  // right cap
                ([1, 0, 4, 5],  0.75),  // left cap
            ]

            // Compute average projected z for ordering (further first).
            let drawOrder = faces.sorted { a, b in
                let za = a.idx.reduce(0.0) { $0 + Double(local[$1].z) } / 4
                let zb = b.idx.reduce(0.0) { $0 + Double(local[$1].z) } / 4
                return za < zb
            }

            for face in drawOrder {
                var path = Path()
                let pts = face.idx.map { centered[$0] }
                path.move(to: pts[0])
                for p in pts.dropFirst() { path.addLine(to: p) }
                path.closeSubpath()
                let shaded = baseColor.opacity(face.shade)
                context.fill(path, with: .color(shaded))
                context.stroke(path, with: .color(stroke), lineWidth: 0.5)
            }
        }
        .frame(height: 28)
    }
}

/// Local coordinate frame of a single timber: long axis (cap-to-cap),
/// width axis, thickness axis. Used to project the 8 corners onto a
/// canonical (length, width, thickness) space for axonometric display.
private struct TimberFrame {
    let origin: SIMD3<Double>           // prism centroid
    let longAxis: SIMD3<Double>          // unit vector
    let widthAxis: SIMD3<Double>         // unit vector
    let thicknessAxis: SIMD3<Double>     // unit vector
    let dimensions: (length: Double, width: Double, thickness: Double)

    init(_ timber: ZomeTimber) {
        // Cap centers (left = ABFE, right = CDHG) — same as Schedule.measure.
        let leftCenter  = (timber.a + timber.b + timber.f + timber.e) * 0.25
        let rightCenter = (timber.c + timber.d + timber.h + timber.g) * 0.25
        let centroid = timber.points.reduce(SIMD3<Double>.zero, +) / Double(timber.points.count)

        let longRaw = rightCenter - leftCenter
        let length = longRaw.length
        let longUnit = length == 0 ? SIMD3<Double>(1, 0, 0) : longRaw / length

        // Top/bottom centers (top = ABDC, bottom = EFGH).
        let topCenter    = (timber.a + timber.b + timber.c + timber.d) * 0.25
        let bottomCenter = (timber.e + timber.f + timber.g + timber.h) * 0.25
        let thickRaw = topCenter - bottomCenter
        // Force perpendicular to long axis.
        let thickProj = thickRaw - longUnit * (thickRaw * longUnit).sum()
        let thickness = thickProj.length
        let thickUnit = thickness == 0 ? SIMD3<Double>(0, 1, 0) : thickProj / thickness

        let widthUnit = SIMD3<Double>.cross(thickUnit, longUnit).normalized

        // Width: distance from one side-pair midpoint to the opposite one.
        let leftSideCenter  = (timber.b + timber.a + timber.e + timber.f) * 0.25
        let rightSideCenter = (timber.d + timber.c + timber.g + timber.h) * 0.25
        let widthSpan = abs(((rightSideCenter - leftSideCenter) * widthUnit).sum())

        self.origin = centroid
        self.longAxis = longUnit
        self.widthAxis = widthUnit
        self.thicknessAxis = thickUnit
        self.dimensions = (length: length, width: widthSpan, thickness: thickness)
    }

    func toLocal(_ p: SIMD3<Double>) -> SIMD3<Double> {
        let r = p - origin
        return SIMD3<Double>(
            (r * longAxis).sum(),
            (r * widthAxis).sum(),
            (r * thicknessAxis).sum()
        )
    }
}
