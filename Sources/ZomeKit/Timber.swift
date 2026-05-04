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

/// Port of `Polygon3D.compute_framework` for assembly_method=0 (GoodKarma),
/// assembly_direction=0 (Clockwise Rotation), xpansion_direction=+1 (inward).
/// Other modes are intentionally unimplemented in v1.
enum TimberBuilder {
    static func build(
        face facePoints: [Vec3],
        vanishingPoint vanishingPt: Vec3,
        timberThickness: Double,
        timberWidth: Double
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

            // GoodKarma: thickness offset is perpendicular to the face plane;
            // vertical projection is in the face plane perpendicular to the edge.
            let hProj = Vec3.cross(cur2sec, mid2van)
            let thickPt = Vec3.point(from: mid, towards: hProj, distance: timberThickness)
            let vProj = Vec3.cross(hProj, cur2sec)              // xpansion = +1 (inward) -> no flip
            let widthPt = Vec3.point(from: thickPt, towards: vProj, distance: timberWidth)

            ccwVecs[i] = cur2sec
            cwVecs[i] = cur2prev
            horizontalProj[i] = hProj
            thicknessPts[i] = thickPt
            widthPts[i] = widthPt

            wallPlanes[i] = Plane(through: cur, mid, vanishingPt)
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

            let A = intersection(point: mid,      direction: sec2cur, plane: plane0)
            let B = intersection(point: thickPt,  direction: sec2cur, plane: plane1)
            let C = intersection(point: mid,      direction: cur2sec, plane: plane2)
            let D = intersection(point: thickPt,  direction: cur2sec, plane: plane3)

            let E = intersection(point: midWithV, direction: sec2cur, plane: plane0)
            let F = intersection(point: widthPt,  direction: sec2cur, plane: plane1)
            let G = intersection(point: midWithV, direction: cur2sec, plane: plane2)
            let H = intersection(point: widthPt,  direction: cur2sec, plane: plane3)

            timbers.append(ZomeTimber(points: [A, B, C, D, E, F, G, H]))
        }

        return timbers
    }
}
