import Foundation

/// One timber as an 8-vertex prism. Indexes match z5omes' `TrapezoidalPrism`:
///   `[0..3] = A B C D` (top trapezoid, sits on the outer face surface)
///   `[4..7] = E F G H` (bottom trapezoid, offset inward by `timberWidth`)
public struct ZomeTimber: Equatable, Sendable {
    public let points: [Vec3]      // exactly 8

    public init(points: [Vec3]) {
        precondition(points.count == 8, "ZomeTimber requires 8 vertices (A..H)")
        self.points = points
    }

    public var a: Vec3 { points[0] }
    public var b: Vec3 { points[1] }
    public var c: Vec3 { points[2] }
    public var d: Vec3 { points[3] }
    public var e: Vec3 { points[4] }
    public var f: Vec3 { points[5] }
    public var g: Vec3 { points[6] }
    public var h: Vec3 { points[7] }
}

/// Port of `Polygon3D.compute_framework` for `assembly_direction=0`
/// (Clockwise Rotation) and `xpansion_direction=+1` (inward). All three
/// `AssemblyMethod` cases are supported; per-method differences are isolated
/// in the per-vertex `offsets(for:...)` block, so the prism-construction
/// loop downstream stays the same.
enum TimberBuilder {
    static func build(
        face facePoints: [Vec3],
        vanishingPoint vanishingPt: Vec3,
        timberThickness: Double,
        timberWidth: Double,
        assemblyMethod: AssemblyMethod = .goodKarma
    ) -> [ZomeTimber] {
        let n = facePoints.count
        let nextIdx = (0..<n).map { ($0 + 1) % n }
        let prevIdx = (0..<n).map { (n + $0 - 1) % n }
        let midpoints = (0..<n).map { Vec3.midpoint(facePoints[$0], facePoints[nextIdx[$0]]) }

        var ccwVecs = [Vec3](repeating: .zero, count: n)   // cur -> next
        var cwVecs = [Vec3](repeating: .zero, count: n)    // cur -> prev
        var thicknessPts = [Vec3](repeating: .zero, count: n)
        var widthPts = [Vec3](repeating: .zero, count: n)
        var horizontalProj = [Vec3](repeating: .zero, count: n)
        var wallPlanes = [Plane](repeating: .init(a: 0, b: 0, c: 0, d: 0), count: n)
        var shiftedWallPlanes = [Plane](repeating: .init(a: 0, b: 0, c: 0, d: 0), count: n)

        for i in 0..<n {
            let cur = facePoints[i]
            let nxt = facePoints[nextIdx[i]]
            let prv = facePoints[prevIdx[i]]
            let mid = midpoints[i]

            let cur2sec = nxt - cur
            let cur2prev = prv - cur
            let mid2van = vanishingPt - mid

            var hProj: Vec3
            var thickPt: Vec3
            var vProj: Vec3

            switch assemblyMethod {
            case .goodKarma:
                // Thickness perpendicular to the face plane via cross-product
                // with the midpoint→vanishing direction; width drops in the
                // face plane perpendicular to the edge. xpansion=+1 (inward),
                // so vProj is left as-is.
                hProj   = Vec3.cross(cur2sec, mid2van)
                thickPt = Vec3.point(from: mid, towards: hProj, distance: timberThickness)
                vProj   = Vec3.cross(hProj, cur2sec)

            case .beveled, .xpansion:
                // θ-pivoted offset. Build a right triangle at the vertex with
                // hypotenuse `t/sin θ` along the prev edge; thickness offset
                // lands `t/tan θ` back along cur→next from the midpoint.
                let theta = Self.vertexAngle(prev: cur2prev, next: cur2sec)
                let hypotenuse = timberThickness / sin(theta)
                let adjacent   = timberThickness / tan(theta)
                let pivot = Vec3.point(from: mid, towards: cur2sec, distance: -adjacent)
                thickPt = Vec3.point(from: pivot, towards: cur2prev, distance: hypotenuse)
                hProj = thickPt - mid

                let halfPi = Double.pi / 2
                if abs(theta - halfPi) < 1e-6 {
                    // Cross-product hack for exact 90° vertices.
                    vProj = Vec3.cross(cur2sec, cur2prev)
                } else if theta > halfPi {
                    vProj = Vec3.cross(hProj, cur2prev)
                } else {
                    vProj = Vec3.cross(hProj, -cur2prev)
                }

                if assemblyMethod == .beveled {
                    // xpansion=+1 → multiply by -1 for beveled-inward.
                    vProj = -vProj

                    let wp = Plane(through: cur, mid, vanishingPt)
                    let candidateWidthPt = Vec3.point(from: thickPt, towards: vProj, distance: timberWidth)
                    let oppositeMid = intersection(point: candidateWidthPt, direction: hProj, plane: wp)
                    let oppositeThickness = (oppositeMid - candidateWidthPt).length

                    if oppositeThickness > timberThickness {
                        // Clamp so the inner face's effective thickness ≤ the
                        // requested thickness — otherwise the inset face would
                        // read as a wider beam than the outer.
                        let delta = oppositeThickness - timberThickness
                        thickPt = Vec3.point(from: mid, towards: hProj, distance: timberThickness - delta)
                    }
                }
            }

            // Compute width offset once, after any thickness-clamp, using
            // the current vProj (signs already applied in the switch).
            let widthPt = Vec3.point(from: thickPt, towards: vProj, distance: timberWidth)

            ccwVecs[i] = cur2sec
            cwVecs[i] = cur2prev
            horizontalProj[i] = hProj
            thicknessPts[i] = thickPt
            widthPts[i] = widthPt

            // Wall plane: GoodKarma + Beveled use the vanishing-point line;
            // Xpansion uses the vertical projection instead.
            switch assemblyMethod {
            case .goodKarma, .beveled:
                wallPlanes[i] = Plane(through: cur, mid, vanishingPt)
            case .xpansion:
                let projAnchor = Vec3.point(from: mid, towards: vProj, distance: 100.0)
                wallPlanes[i] = Plane(through: cur, mid, projAnchor)
            }

            // Shifted wall plane is offset by the thickness/width pair, matching
            // z5omes' `point_to(thickness_offset_pt, cur_2_sec_vec, 100)` triangle.
            shiftedWallPlanes[i] = Plane(
                through: Vec3.point(from: thickPt, towards: cur2sec, distance: 100.0),
                thickPt,
                widthPt
            )
        }

        var timbers: [ZomeTimber] = []
        timbers.reserveCapacity(n)

        for i in 0..<n {
            let nxt = nextIdx[i]
            let prv = prevIdx[i]

            let thickPt = thicknessPts[i]
            let widthPt = widthPts[i]
            let mid = midpoints[i]
            let cur2sec = ccwVecs[i]
            let sec2cur = cwVecs[nxt]
            let hProj = horizontalProj[i]

            // Clockwise: previous side uses shifted plane (the "inset" side);
            // next side uses the raw wall plane (the "leading" side).
            let plane0 = shiftedWallPlanes[prv]
            let plane1 = shiftedWallPlanes[prv]
            let plane2 = wallPlanes[nxt]
            let plane3 = wallPlanes[nxt]

            let alongPlane = wallPlanes[i]
            let midWithV = intersection(point: widthPt, direction: hProj, plane: alongPlane)

            var pA = intersection(point: mid,      direction: sec2cur, plane: plane0)
            var pB = intersection(point: thickPt,  direction: sec2cur, plane: plane1)
            var pC = intersection(point: mid,      direction: cur2sec, plane: plane2)
            var pD = intersection(point: thickPt,  direction: cur2sec, plane: plane3)

            var pE = intersection(point: midWithV, direction: sec2cur, plane: plane0)
            var pF = intersection(point: widthPt,  direction: sec2cur, plane: plane1)
            var pG = intersection(point: midWithV, direction: cur2sec, plane: plane2)
            var pH = intersection(point: widthPt,  direction: cur2sec, plane: plane3)

            // Xpansion mode is the "outward expansion" case: top and bottom
            // of the prism flip — A..D becomes the inner trapezoid, E..H the
            // outer one (the dome's outside surface).
            if assemblyMethod == .xpansion {
                swap(&pA, &pE); swap(&pB, &pF); swap(&pC, &pG); swap(&pD, &pH)
            }

            timbers.append(ZomeTimber(points: [pA, pB, pC, pD, pE, pF, pG, pH]))
        }

        return timbers
    }

    /// Interior angle at a polygon vertex, given the two edges leaving it
    /// (cur→prev and cur→next). Result in radians, clamped to `[0, π]`.
    private static func vertexAngle(prev: Vec3, next: Vec3) -> Double {
        let pn = prev.normalized
        let nn = next.normalized
        let dot = (pn * nn).sum()
        return acos(max(-1.0, min(1.0, dot)))
    }
}
